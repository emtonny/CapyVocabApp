import assert from "node:assert/strict";
import test from "node:test";

import {
  type ProviderFailureCode,
  type TranslationClaim,
  type TranslationProvider,
  TranslationProviderFailure,
  type TranslationQueue,
  TranslationQueueUnavailableError,
  type WorkerLogger,
} from "./contracts.ts";
import { runTranslationWorker } from "./worker.ts";

const CLAIM: TranslationClaim = {
  translationId: "11111111-1111-4111-8111-111111111111",
  claimToken: "22222222-2222-4222-8222-222222222222",
  rawText: "Nội dung synthetic không được log",
  sourceLanguageCode: "vi",
  targetLanguageCode: "en",
  provider: "gemini",
  model: "gemini-3-flash-preview",
  promptVersion: "chat-translate-p3",
  translatorVersion: "chat-translate-v3",
  attemptCount: 1,
  leaseExpiresAt: "2099-01-01T00:00:00.000Z",
};

class FakeQueue implements TranslationQueue {
  claimValue: TranslationClaim | null = CLAIM;
  claimCalls = 0;
  completeCalls: Array<{
    translationId: string;
    claimToken: string;
    translatedText: string;
  }> = [];
  failCalls: Array<{
    translationId: string;
    claimToken: string;
    errorCode: ProviderFailureCode;
    providerRetryAfterSeconds?: number | null;
  }> = [];
  completeError: Error | null = null;
  failError: Error | null = null;

  claim(): Promise<TranslationClaim | null> {
    this.claimCalls += 1;
    return Promise.resolve(this.claimValue);
  }

  complete(request: (typeof this.completeCalls)[number]): Promise<void> {
    this.completeCalls.push(request);
    return this.completeError
      ? Promise.reject(this.completeError)
      : Promise.resolve();
  }

  fail(request: (typeof this.failCalls)[number]): Promise<void> {
    this.failCalls.push(request);
    return this.failError ? Promise.reject(this.failError) : Promise.resolve();
  }
}

class CapturingLogger implements WorkerLogger {
  readonly entries: Array<{
    level: "info" | "warn";
    event: string;
    fields: Readonly<Record<string, string | number | boolean | null>>;
  }> = [];

  info(
    event: string,
    fields: Readonly<Record<string, string | number | boolean | null>>,
  ) {
    this.entries.push({ level: "info", event, fields });
  }

  warn(
    event: string,
    fields: Readonly<Record<string, string | number | boolean | null>>,
  ) {
    this.entries.push({ level: "warn", event, fields });
  }
}

function provider(
  translate: TranslationProvider["translate"],
): TranslationProvider {
  return { translate };
}

test("idle queue never calls the provider", async () => {
  const queue = new FakeQueue();
  queue.claimValue = null;
  let providerCalls = 0;

  const result = await runTranslationWorker({
    queue,
    provider: provider(() => {
      providerCalls += 1;
      return Promise.resolve({ translatedText: "unused" });
    }),
  });

  assert.deepEqual(result, { status: "idle" });
  assert.equal(queue.claimCalls, 1);
  assert.equal(providerCalls, 0);
});

test("mismatched version or expired lease fails before provider", async () => {
  for (
    const claimValue of [
      { ...CLAIM, translatorVersion: "unexpected-version" },
      { ...CLAIM, leaseExpiresAt: "2000-01-01T00:00:00.000Z" },
    ]
  ) {
    const queue = new FakeQueue();
    queue.claimValue = claimValue;
    let providerCalls = 0;
    await assert.rejects(
      () =>
        runTranslationWorker({
          queue,
          provider: provider(() => {
            providerCalls += 1;
            return Promise.resolve({ translatedText: "unused" });
          }),
        }),
      TranslationQueueUnavailableError,
    );
    assert.equal(providerCalls, 0);
    assert.equal(queue.completeCalls.length, 0);
    assert.equal(queue.failCalls.length, 0);
  }
});

test("success calls one provider and completes with the same claim token", async () => {
  const queue = new FakeQueue();
  let providerCalls = 0;

  const result = await runTranslationWorker({
    queue,
    provider: provider((request) => {
      providerCalls += 1;
      assert.equal(request.rawText, CLAIM.rawText);
      assert.equal(request.sourceLanguageCode, "vi");
      assert.equal(request.targetLanguageCode, "en");
      assert.equal(request.signal.aborted, false);
      return Promise.resolve({ translatedText: "Synthetic translation" });
    }),
  });

  assert.deepEqual(result, {
    status: "succeeded",
    translationId: CLAIM.translationId,
    attemptCount: 1,
  });
  assert.equal(providerCalls, 1);
  assert.deepEqual(queue.completeCalls, [{
    translationId: CLAIM.translationId,
    claimToken: CLAIM.claimToken,
    translatedText: "Synthetic translation",
  }]);
  assert.equal(queue.failCalls.length, 0);
});

test("provider failure preserves the stable code and retry-after", async () => {
  const queue = new FakeQueue();
  const result = await runTranslationWorker({
    queue,
    provider: provider(() =>
      Promise.reject(
        new TranslationProviderFailure("PROVIDER_RATE_LIMITED", {
          retryAfterSeconds: 37,
        }),
      )
    ),
  });

  assert.equal(result.status, "failed");
  assert.equal(
    result.status === "failed" && result.errorCode,
    "PROVIDER_RATE_LIMITED",
  );
  assert.deepEqual(queue.failCalls, [{
    translationId: CLAIM.translationId,
    claimToken: CLAIM.claimToken,
    errorCode: "PROVIDER_RATE_LIMITED",
    providerRetryAfterSeconds: 37,
  }]);
  assert.equal(queue.completeCalls.length, 0);
});

test("malformed provider response maps through the retryable taxonomy", async () => {
  const queue = new FakeQueue();
  const result = await runTranslationWorker({
    queue,
    provider: provider(() =>
      Promise.reject(new TranslationProviderFailure("MALFORMED_RESPONSE"))
    ),
  });

  assert.equal(
    result.status === "failed" && result.errorCode,
    "MALFORMED_RESPONSE",
  );
  assert.equal(queue.failCalls[0]?.errorCode, "MALFORMED_RESPONSE");
});

test("unknown provider exception maps to a safe network failure", async () => {
  const queue = new FakeQueue();
  const result = await runTranslationWorker({
    queue,
    provider: provider(() =>
      Promise.reject(new Error("sensitive upstream body"))
    ),
  });

  assert.equal(
    result.status === "failed" && result.errorCode,
    "PROVIDER_NETWORK",
  );
  assert.equal(queue.failCalls[0]?.errorCode, "PROVIDER_NETWORK");
});

test("provider timeout aborts the request and schedules one timeout failure", async () => {
  const queue = new FakeQueue();
  let observedAbort = false;
  const result = await runTranslationWorker({
    queue,
    providerTimeoutMs: 5,
    provider: provider((request) =>
      new Promise((_resolve, reject) => {
        request.signal.addEventListener("abort", () => {
          observedAbort = true;
          reject(request.signal.reason);
        }, { once: true });
      })
    ),
  });

  assert.equal(observedAbort, true);
  assert.equal(
    result.status === "failed" && result.errorCode,
    "PROVIDER_TIMEOUT",
  );
  assert.equal(queue.failCalls.length, 1);
  assert.equal(queue.failCalls[0]?.errorCode, "PROVIDER_TIMEOUT");
});

for (const invalidOutput of ["   ", "x".repeat(16_001)]) {
  test("invalid provider text becomes a terminal output failure", async () => {
    const queue = new FakeQueue();
    const result = await runTranslationWorker({
      queue,
      provider: provider(() =>
        Promise.resolve({ translatedText: invalidOutput })
      ),
    });

    assert.equal(
      result.status === "failed" && result.errorCode,
      "OUTPUT_INVALID",
    );
    assert.equal(queue.completeCalls.length, 0);
    assert.equal(queue.failCalls[0]?.errorCode, "OUTPUT_INVALID");
  });
}

test("output length follows Unicode code points like PostgreSQL char_length", async () => {
  const queue = new FakeQueue();
  const translatedText = "😀".repeat(10_000);
  const result = await runTranslationWorker({
    queue,
    provider: provider(() => Promise.resolve({ translatedText })),
  });

  assert.equal(result.status, "succeeded");
  assert.equal(queue.completeCalls[0]?.translatedText, translatedText);
  assert.equal(queue.failCalls.length, 0);
});

test("ambiguous success persistence never writes a contradictory failure", async () => {
  const queue = new FakeQueue();
  queue.completeError = new TranslationQueueUnavailableError(
    "synthetic lost completion response",
  );

  await assert.rejects(
    () =>
      runTranslationWorker({
        queue,
        provider: provider(() =>
          Promise.resolve({ translatedText: "May already be committed" })
        ),
      }),
    TranslationQueueUnavailableError,
  );
  assert.equal(queue.completeCalls.length, 1);
  assert.equal(queue.failCalls.length, 0);
});

test("failure persistence error remains recoverable by lease expiry", async () => {
  const queue = new FakeQueue();
  queue.failError = new TranslationQueueUnavailableError(
    "synthetic database outage",
  );

  await assert.rejects(
    () =>
      runTranslationWorker({
        queue,
        provider: provider(() =>
          Promise.reject(new TranslationProviderFailure("PROVIDER_UNAVAILABLE"))
        ),
      }),
    TranslationQueueUnavailableError,
  );
  assert.equal(queue.failCalls.length, 1);
});

test("structured logs contain metadata but no content, token, or exception body", async () => {
  const queue = new FakeQueue();
  const logger = new CapturingLogger();
  await runTranslationWorker({
    queue,
    logger,
    now: (() => {
      let value = 100;
      return () => value += 5;
    })(),
    provider: provider(() =>
      Promise.reject(new Error("sensitive provider response"))
    ),
  });

  const serialized = JSON.stringify(logger.entries);
  assert.equal(serialized.includes(CLAIM.rawText), false);
  assert.equal(serialized.includes(CLAIM.claimToken), false);
  assert.equal(serialized.includes("sensitive provider response"), false);
  assert.equal(serialized.includes(CLAIM.translationId), true);
  assert.equal(serialized.includes("PROVIDER_NETWORK"), true);
});
