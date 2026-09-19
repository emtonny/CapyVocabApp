import assert from "node:assert/strict";
import test from "node:test";

import {
  type TranslationClaim,
  type TranslationProvider,
  TranslationProviderFailure,
  type TranslationQueue,
} from "./contracts.ts";
import { runTranslationWorker } from "./worker.ts";

const CLAIM: TranslationClaim = {
  translationId: "translation-1",
  claimToken: "claim-1",
  rawText: "Xin chào",
  sourceLanguageCode: "vi",
  targetLanguageCode: "en",
  provider: "gemini",
  model: "gemini-3.5-flash-lite",
  promptVersion: "chat-translate-p1",
  translatorVersion: "chat-translate-v1",
  attemptCount: 1,
  leaseExpiresAt: "2099-01-01T00:00:00.000Z",
};

test("completes a valid translation with the claim token", async () => {
  const completed: unknown[] = [];
  const queue: TranslationQueue = {
    claim: () => Promise.resolve(CLAIM),
    complete: (request) => {
      completed.push(request);
      return Promise.resolve();
    },
    fail: () => Promise.reject(new Error("fail must not be called")),
  };
  const provider: TranslationProvider = {
    translate: (request) => {
      assert.equal(request.rawText, "Xin chào");
      assert.equal(request.sourceLanguageCode, "vi");
      assert.equal(request.targetLanguageCode, "en");
      return Promise.resolve({ translatedText: "Hello" });
    },
  };

  const result = await runTranslationWorker({ queue, provider });

  assert.deepEqual(result, {
    status: "succeeded",
    translationId: "translation-1",
    attemptCount: 1,
  });
  assert.deepEqual(completed, [{
    translationId: "translation-1",
    claimToken: "claim-1",
    translatedText: "Hello",
  }]);
});

test("records a classified provider failure without completing", async () => {
  const failed: unknown[] = [];
  const queue: TranslationQueue = {
    claim: () => Promise.resolve(CLAIM),
    complete: () => Promise.reject(new Error("complete must not be called")),
    fail: (request) => {
      failed.push(request);
      return Promise.resolve();
    },
  };
  const provider: TranslationProvider = {
    translate: () =>
      Promise.reject(
        new TranslationProviderFailure("PROVIDER_RATE_LIMITED", {
          retryAfterSeconds: 45,
        }),
      ),
  };

  const result = await runTranslationWorker({ queue, provider });

  assert.deepEqual(result, {
    status: "failed",
    translationId: "translation-1",
    attemptCount: 1,
    errorCode: "PROVIDER_RATE_LIMITED",
  });
  assert.deepEqual(failed, [{
    translationId: "translation-1",
    claimToken: "claim-1",
    errorCode: "PROVIDER_RATE_LIMITED",
    providerRetryAfterSeconds: 45,
  }]);
});

test("returns idle without calling the provider when no claim is available", async () => {
  const queue: TranslationQueue = {
    claim: () => Promise.resolve(null),
    complete: () => Promise.reject(new Error("complete must not be called")),
    fail: () => Promise.reject(new Error("fail must not be called")),
  };
  const provider: TranslationProvider = {
    translate: () => Promise.reject(new Error("provider must not be called")),
  };

  assert.deepEqual(await runTranslationWorker({ queue, provider }), {
    status: "idle",
  });
});
