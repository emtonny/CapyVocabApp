import assert from "node:assert/strict";
import test from "node:test";

import type { TranslationProvider, TranslationQueue } from "./contracts.ts";
import { createChatTranslationHandler } from "./handler.ts";

const provider: TranslationProvider = {
  translate: () => Promise.resolve({ translatedText: "Hello" }),
};

function request(method = "POST", secret?: string): Request {
  return new Request(
    "https://project.supabase.co/functions/v1/chat-translation-worker",
    {
      method,
      headers: secret ? { "x-chat-translation-trigger": secret } : undefined,
    },
  );
}

test("rejects methods other than POST", async () => {
  const handler = createChatTranslationHandler({
    triggerSecret: "configured-secret",
    requestId: () => "request-1",
  });

  const response = await handler(request("GET"));

  assert.equal(response.status, 405);
  assert.deepEqual(await response.json(), {
    error: "method_not_allowed",
    requestId: "request-1",
  });
});

test("rejects an invalid trigger secret before claiming work", async () => {
  let claimCalls = 0;
  const queue: TranslationQueue = {
    claim: () => {
      claimCalls += 1;
      return Promise.resolve(null);
    },
    complete: () => Promise.resolve(),
    fail: () => Promise.resolve(),
  };
  const handler = createChatTranslationHandler({
    triggerSecret: "configured-secret",
    queue,
    provider,
    requestId: () => "request-2",
  });

  const response = await handler(request("POST", "wrong-secret"));

  assert.equal(response.status, 401);
  assert.equal(claimCalls, 0);
});

test("returns 503 before claim when runtime credentials are incomplete", async () => {
  const handler = createChatTranslationHandler({
    triggerSecret: "configured-secret",
    requestId: () => "request-3",
  });

  const response = await handler(request("POST", "configured-secret"));

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: "provider_not_configured",
    requestId: "request-3",
  });
});

test("returns 204 when the authenticated queue is idle", async () => {
  const queue: TranslationQueue = {
    claim: () => Promise.resolve(null),
    complete: () => Promise.resolve(),
    fail: () => Promise.resolve(),
  };
  const handler = createChatTranslationHandler({
    triggerSecret: "configured-secret",
    queue,
    provider,
  });

  const response = await handler(request("POST", "configured-secret"));

  assert.equal(response.status, 204);
  assert.equal(await response.text(), "");
});
