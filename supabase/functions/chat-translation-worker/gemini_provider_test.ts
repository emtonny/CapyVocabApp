import assert from "node:assert/strict";
import test from "node:test";

import { createGeminiTranslationProvider } from "./gemini_provider.ts";
import { TranslationProviderFailure } from "./contracts.ts";

function providerRequest() {
  return {
    rawText: "Xin chào",
    sourceLanguageCode: "vi" as const,
    targetLanguageCode: "en" as const,
    model: "gemini-3.5-flash-lite",
    promptVersion: "chat-translate-p1",
    translatorVersion: "chat-translate-v1",
    signal: new AbortController().signal,
  };
}

test("sends the fixed policy to Gemini and returns one translation", async () => {
  let calledUrl = "";
  let calledHeaders = new Headers();
  let calledBody: Record<string, unknown> = {};
  const provider = createGeminiTranslationProvider({
    apiKey: "gemini-key",
    fetcher: (input, init) => {
      calledUrl = String(input);
      calledHeaders = new Headers(init?.headers);
      calledBody = JSON.parse(String(init?.body));
      return Promise.resolve(Response.json({
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: "Hello" }] },
        }],
      }));
    },
  });

  const result = await provider.translate(providerRequest());

  assert.equal(result.translatedText, "Hello");
  assert.match(calledUrl, /gemini-3[.]5-flash-lite:generateContent$/);
  assert.equal(calledHeaders.get("x-goog-api-key"), "gemini-key");
  assert.deepEqual(
    (calledBody.generationConfig as Record<string, unknown>).thinkingConfig,
    { thinkingLevel: "MINIMAL" },
  );
});

test("maps rate limits and caps Retry-After", async () => {
  const provider = createGeminiTranslationProvider({
    apiKey: "gemini-key",
    fetcher: () =>
      Promise.resolve(
        new Response(null, {
          status: 429,
          headers: { "retry-after": "999" },
        }),
      ),
  });

  await assert.rejects(
    () => provider.translate(providerRequest()),
    (error: unknown) =>
      error instanceof TranslationProviderFailure &&
      error.code === "PROVIDER_RATE_LIMITED" &&
      error.retryAfterSeconds === 300,
  );
});

test("rejects malformed provider output", async () => {
  const provider = createGeminiTranslationProvider({
    apiKey: "gemini-key",
    fetcher: () => Promise.resolve(Response.json({ candidates: [] })),
  });

  await assert.rejects(
    () => provider.translate(providerRequest()),
    (error: unknown) =>
      error instanceof TranslationProviderFailure &&
      error.code === "MALFORMED_RESPONSE",
  );
});
