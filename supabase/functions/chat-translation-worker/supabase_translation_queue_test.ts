import assert from "node:assert/strict";
import test from "node:test";

import { TranslationQueueUnavailableError } from "./contracts.ts";
import {
  createSupabaseTranslationQueue,
  parseTranslationClaim,
} from "./supabase_translation_queue.ts";

const CLAIM_ROW = {
  translation_id: "11111111-1111-4111-8111-111111111111",
  claim_token: "22222222-2222-4222-8222-222222222222",
  raw_text: "Synthetic raw text",
  source_language_code: "vi",
  target_language_code: "en",
  provider: "gemini",
  model: "gemini-3-flash-preview",
  prompt_version: "chat-translate-p3",
  translator_version: "chat-translate-v3",
  attempt_count: 1,
  lease_expires_at: "2026-09-18T12:01:00.000Z",
};

test("claim calls the service-only RPC and parses one typed row", async () => {
  let requestedUrl = "";
  let requestedInit: RequestInit | undefined;
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co/",
    serviceRoleKey: "synthetic-service-key",
    fetcher: (input, init) => {
      requestedUrl = String(input);
      requestedInit = init;
      return Promise.resolve(Response.json([CLAIM_ROW]));
    },
  });

  const claim = await queue.claim("chat-translate-v3");

  assert.equal(
    new URL(requestedUrl).pathname,
    "/rest/v1/rpc/claim_chat_translation",
  );
  assert.equal(requestedInit?.method, "POST");
  assert.equal(
    new Headers(requestedInit?.headers).get("authorization"),
    "Bearer synthetic-service-key",
  );
  assert.deepEqual(JSON.parse(String(requestedInit?.body)), {
    p_translator_version: "chat-translate-v3",
  });
  assert.deepEqual(claim, {
    translationId: CLAIM_ROW.translation_id,
    claimToken: CLAIM_ROW.claim_token,
    rawText: CLAIM_ROW.raw_text,
    sourceLanguageCode: "vi",
    targetLanguageCode: "en",
    provider: "gemini",
    model: "gemini-3-flash-preview",
    promptVersion: "chat-translate-p3",
    translatorVersion: "chat-translate-v3",
    attemptCount: 1,
    leaseExpiresAt: CLAIM_ROW.lease_expires_at,
  });
});

test("empty claim response is idle", async () => {
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: () => Promise.resolve(Response.json([])),
  });
  assert.equal(await queue.claim("chat-translate-v3"), null);
});

test("claim parser rejects multiple, malformed, and same-language rows", () => {
  assert.throws(
    () => parseTranslationClaim([CLAIM_ROW, CLAIM_ROW]),
    TranslationQueueUnavailableError,
  );
  assert.throws(
    () => parseTranslationClaim([{ ...CLAIM_ROW, attempt_count: 5 }]),
    TranslationQueueUnavailableError,
  );
  assert.throws(
    () =>
      parseTranslationClaim([{
        ...CLAIM_ROW,
        target_language_code: CLAIM_ROW.source_language_code,
      }]),
    TranslationQueueUnavailableError,
  );
});

test("complete sends only the token-bound output contract", async () => {
  let requestedUrl = "";
  let requestedBody: Record<string, unknown> = {};
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: (input, init) => {
      requestedUrl = String(input);
      requestedBody = JSON.parse(String(init?.body));
      return Promise.resolve(Response.json(true));
    },
  });

  await queue.complete({
    translationId: CLAIM_ROW.translation_id,
    claimToken: CLAIM_ROW.claim_token,
    translatedText: "Synthetic translated text",
  });

  assert.equal(
    new URL(requestedUrl).pathname,
    "/rest/v1/rpc/complete_chat_translation",
  );
  assert.deepEqual(requestedBody, {
    p_translation_id: CLAIM_ROW.translation_id,
    p_claim_token: CLAIM_ROW.claim_token,
    p_translated_text: "Synthetic translated text",
  });
});

test("fail sends stable code and nullable provider retry delay", async () => {
  const bodies: Array<Record<string, unknown>> = [];
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: (_input, init) => {
      bodies.push(JSON.parse(String(init?.body)));
      return Promise.resolve(Response.json(true));
    },
  });

  await queue.fail({
    translationId: CLAIM_ROW.translation_id,
    claimToken: CLAIM_ROW.claim_token,
    errorCode: "PROVIDER_RATE_LIMITED",
    providerRetryAfterSeconds: 45,
  });
  await queue.fail({
    translationId: CLAIM_ROW.translation_id,
    claimToken: CLAIM_ROW.claim_token,
    errorCode: "PROVIDER_NETWORK",
  });

  assert.deepEqual(bodies, [{
    p_translation_id: CLAIM_ROW.translation_id,
    p_claim_token: CLAIM_ROW.claim_token,
    p_error_code: "PROVIDER_RATE_LIMITED",
    p_provider_retry_after_seconds: 45,
  }, {
    p_translation_id: CLAIM_ROW.translation_id,
    p_claim_token: CLAIM_ROW.claim_token,
    p_error_code: "PROVIDER_NETWORK",
    p_provider_retry_after_seconds: null,
  }]);
});

test("non-success RPC response never exposes its body", async () => {
  const queue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: () =>
      Promise.resolve(
        new Response("sensitive database detail", { status: 500 }),
      ),
  });

  await assert.rejects(
    () => queue.claim("chat-translate-v3"),
    (error: unknown) => {
      assert.ok(error instanceof TranslationQueueUnavailableError);
      assert.equal(error.message.includes("sensitive database detail"), false);
      assert.equal(error.message.includes("status 500"), true);
      return true;
    },
  );
});

test("network and invalid scalar responses fail closed", async () => {
  const networkQueue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: () => Promise.reject(new Error("network detail")),
  });
  await assert.rejects(
    () => networkQueue.claim("chat-translate-v3"),
    TranslationQueueUnavailableError,
  );

  const invalidQueue = createSupabaseTranslationQueue({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "synthetic-service-key",
    fetcher: () => Promise.resolve(Response.json({ ok: true })),
  });
  await assert.rejects(
    () =>
      invalidQueue.complete({
        translationId: CLAIM_ROW.translation_id,
        claimToken: CLAIM_ROW.claim_token,
        translatedText: "text",
      }),
    TranslationQueueUnavailableError,
  );
});
