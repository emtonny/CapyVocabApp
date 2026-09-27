import assert from "node:assert/strict";
import test from "node:test";

import {
  type TranslationClaim,
  type TranslationProvider,
  type TranslationQueue,
  TranslationQueueUnavailableError,
  type WorkerLogger,
} from "./contracts.ts";
import { createChatTranslationHandler } from "./handler.ts";

const CLAIM: TranslationClaim = {
  translationId: "11111111-1111-4111-8111-111111111111",
  claimToken: "22222222-2222-4222-8222-222222222222",
  rawText: "Synthetic raw",
  sourceLanguageCode: "vi",
  targetLanguageCode: "en",
  provider: "vilao",
  model: "gemini-3.8-flash",
  promptVersion: "chat-translate-p2",
  translatorVersion: "chat-translate-v2",
  attemptCount: 1,
  leaseExpiresAt: "2099-01-01T00:00:00.000Z",
};

function createQueue(claimValue: TranslationClaim | null = CLAIM): {
  queue: TranslationQueue;
  calls: { claim: number; complete: number; fail: number };
} {
  const calls = { claim: 0, complete: 0, fail: 0 };
  return {
    calls,
    queue: {
      claim: () => {
        calls.claim += 1;
        return Promise.resolve(claimValue);
      },
      complete: () => {
        calls.complete += 1;
        return Promise.resolve();
      },
      fail: () => {
        calls.fail += 1;
        return Promise.resolve();
      },
    },
  };
}

const PROVIDER: TranslationProvider = {
  translate: () => Promise.resolve({ translatedText: "Synthetic translation" }),
};

function request(secret = "trigger-secret"): Request {
  return new Request(
    "https://project.supabase.co/functions/v1/chat-translation-worker",
    {
      method: "POST",
      headers: { "X-Chat-Translation-Trigger": secret },
    },
  );
}

test("only POST is accepted", async () => {
  const handler = createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    requestId: () => "request-1",
  });
  const response = await handler(
    new Request(
      "https://project.supabase.co/functions/v1/chat-translation-worker",
    ),
  );
  assert.equal(response.status, 405);
  assert.deepEqual(await response.json(), {
    error: "method_not_allowed",
    requestId: "request-1",
  });
});

test("missing runtime trigger configuration fails closed", async () => {
  const response = await createChatTranslationHandler({
    requestId: () => "request-2",
  })(request());
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, "trigger_not_configured");
});

test("wrong trigger secret never reaches queue or provider", async () => {
  const { queue, calls } = createQueue();
  let providerCalls = 0;
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: {
      translate: () => {
        providerCalls += 1;
        return Promise.resolve({ translatedText: "unused" });
      },
    },
  })(request("wrong-secret"));

  assert.equal(response.status, 401);
  assert.equal(calls.claim, 0);
  assert.equal(providerCalls, 0);
});

test("runtime without provider credentials fails before claim", async () => {
  const { queue, calls } = createQueue();
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: undefined,
  })(request());

  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, "provider_not_configured");
  assert.equal(calls.claim, 0);
});

test("successful internal wake-up returns metadata only", async () => {
  const { queue, calls } = createQueue();
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: PROVIDER,
    requestId: () => "request-success",
  })(request());

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "succeeded",
    translationId: CLAIM.translationId,
    attemptCount: 1,
    requestId: "request-success",
  });
  assert.deepEqual(calls, { claim: 1, complete: 1, fail: 0 });
});

test("idle wake-up returns 204", async () => {
  const { queue, calls } = createQueue(null);
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: PROVIDER,
  })(request());

  assert.equal(response.status, 204);
  assert.equal(await response.text(), "");
  assert.deepEqual(calls, { claim: 1, complete: 0, fail: 0 });
});

test("handled provider failure returns stable metadata without content", async () => {
  const { queue, calls } = createQueue();
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: { translate: () => Promise.reject(new Error("provider body")) },
    requestId: () => "request-failure",
  })(request());

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body, {
    status: "failed",
    translationId: CLAIM.translationId,
    attemptCount: 1,
    errorCode: "PROVIDER_NETWORK",
    requestId: "request-failure",
  });
  assert.equal(JSON.stringify(body).includes(CLAIM.rawText), false);
  assert.deepEqual(calls, { claim: 1, complete: 0, fail: 1 });
});

test("queue outage returns a generic 503 and safe log fields", async () => {
  const logs: Array<Record<string, unknown>> = [];
  const logger: WorkerLogger = {
    info: () => {},
    warn: (event, fields) => logs.push({ event, ...fields }),
  };
  const queue: TranslationQueue = {
    claim: () =>
      Promise.reject(
        new TranslationQueueUnavailableError("sensitive database response"),
      ),
    complete: () => Promise.resolve(),
    fail: () => Promise.resolve(),
  };
  const response = await createChatTranslationHandler({
    triggerSecret: "trigger-secret",
    queue,
    provider: PROVIDER,
    logger,
    requestId: () => "request-outage",
  })(request());

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "worker_unavailable",
    requestId: "request-outage",
  });
  const serialized = JSON.stringify(logs);
  assert.equal(serialized.includes("sensitive database response"), false);
  assert.equal(serialized.includes("queue_unavailable"), true);
});
