import assert from "node:assert/strict";
import test from "node:test";

import {
  createSupabaseTranslationQueue,
  parseTranslationClaim,
} from "./supabase_translation_queue.ts";
import { TranslationQueueUnavailableError } from "./contracts.ts";

const CLAIM_ROW = {
  translation_id: "translation-1",
  claim_token: "claim-1",
  raw_text: "Xin chào",
  source_language_code: "vi",
  target_language_code: "en",
  provider: "gemini",
  model: "gemini-3.5-flash-lite",
  prompt_version: "chat-translate-p1",
  translator_version: "chat-translate-v1",
  attempt_count: 1,
  lease_expires_at: "2099-01-01T00:00:00.000Z",
};

test("parses one valid claim and rejects invalid row counts", () => {
  assert.deepEqual(parseTranslationClaim([CLAIM_ROW]), {
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
  });
  assert.throws(
    () => parseTranslationClaim([CLAIM_ROW, CLAIM_ROW]),
    TranslationQueueUnavailableError,
  );
});

test("calls only the three service-role RPC contracts", async () => {
  const calls: Array<{
    path: string;
    body: Record<string, unknown>;
    authorization: string | null;
  }> = [];
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co/",
    serviceRoleKey: "service-key",
    fetcher: (input, init) => {
      const url = new URL(String(input));
      const body = JSON.parse(String(init?.body));
      calls.push({
        path: url.pathname,
        body,
        authorization: new Headers(init?.headers).get("authorization"),
      });
      return Promise.resolve(Response.json(
        url.pathname.endsWith("claim_chat_translation") ? [CLAIM_ROW] : true,
      ));
    },
  });

  await queue.claim("chat-translate-v1");
  await queue.complete({
    translationId: "translation-1",
    claimToken: "claim-1",
    translatedText: "Hello",
  });
  await queue.fail({
    translationId: "translation-1",
    claimToken: "claim-1",
    errorCode: "PROVIDER_TIMEOUT",
    providerRetryAfterSeconds: null,
  });

  assert.deepEqual(calls.map((call) => call.path), [
    "/rest/v1/rpc/claim_chat_translation",
    "/rest/v1/rpc/complete_chat_translation",
    "/rest/v1/rpc/fail_chat_translation",
  ]);
  assert.equal(
    calls.every((call) => call.authorization === "Bearer service-key"),
    true,
  );
  assert.deepEqual(calls[0].body, {
    p_translator_version: "chat-translate-v1",
  });
});
