import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGenerationConfig,
  fetchGeminiModelChain,
  MODEL_CHAIN,
} from "./gemini_client.ts";

const silentLogger = {
  warn() {},
  error() {},
};

function successfulResponse() {
  return new Response(JSON.stringify({ candidates: [] }), { status: 200 });
}

test("uses the production Free Tier model order", () => {
  assert.deepEqual(MODEL_CHAIN, [
    "gemini-3.5-flash-lite",
    "gemini-3.6-flash",
  ]);
});

test("retries one 503 on the same model before moving through the chain", async () => {
  const calls: string[] = [];
  const statuses = [503, 503, 200];

  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "scan-503",
    createRequestBody: (model) => ({ model }),
    fetcher: async (input) => {
      calls.push(String(input));
      return statuses.shift() === 200
        ? successfulResponse()
        : new Response("unavailable", { status: 503 });
    },
    sleep: async () => {},
    logger: silentLogger,
  });

  assert.deepEqual(
    calls.map((url) => MODEL_CHAIN.find((model) => url.includes(model))),
    [MODEL_CHAIN[0], MODEL_CHAIN[0], MODEL_CHAIN[1]],
  );
  assert.equal(result.model, MODEL_CHAIN[1]);
  assert.equal(result.modelsTried, 2);
  assert.equal(result.attemptsForModel, 1);
});

test("moves immediately for retryable statuses and network errors", async () => {
  for (const firstFailure of [404, 429, 500, 502, 504, "network"] as const) {
    const calls: string[] = [];
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `scan-${firstFailure}`,
      createRequestBody: (model) => ({ model }),
      fetcher: async (input) => {
        calls.push(String(input));
        if (calls.length === 1) {
          if (firstFailure === "network") {
            throw new TypeError("mock network error");
          }
          return new Response("model-specific or temporary error", {
            status: firstFailure,
          });
        }
        return successfulResponse();
      },
      sleep: async () => {},
      logger: silentLogger,
    });

    assert.equal(calls.length, 2);
    assert.equal(result.model, MODEL_CHAIN[1]);
    assert.equal(result.modelsTried, 2);
  }
});

test("moves to the next model after a per-model timeout", async () => {
  let callCount = 0;
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "scan-timeout",
    createRequestBody: (model) => ({ model }),
    fetcher: async (_input, init) => {
      callCount += 1;
      if (callCount === 1) {
        return await new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("mock timeout", "AbortError"));
          });
        });
      }
      return successfulResponse();
    },
    attemptTimeoutMs: 5,
    logger: silentLogger,
  });

  assert.equal(callCount, 2);
  assert.equal(result.model, MODEL_CHAIN[1]);
  assert.equal(result.modelsTried, 2);
});

test("does not switch model for request, auth, or payload errors", async () => {
  for (const status of [400, 401, 403, 413]) {
    let callCount = 0;
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `scan-${status}`,
      createRequestBody: (model) => ({ model }),
      fetcher: async () => {
        callCount += 1;
        return new Response("request rejected", { status });
      },
      logger: silentLogger,
    });

    assert.equal(callCount, 1);
    assert.equal(result.response.status, status);
    assert.equal(result.model, MODEL_CHAIN[0]);
    assert.equal(result.modelsTried, 1);
  }
});

test("uses model-compatible thinking config with shared schema and token limit", () => {
  const schema = { type: "OBJECT" };
  const flashLite35 = buildGenerationConfig("gemini-3.5-flash-lite", schema);
  const flash36 = buildGenerationConfig("gemini-3.6-flash", schema);

  assert.deepEqual(flashLite35.thinkingConfig, { thinkingLevel: "low" });
  assert.deepEqual(flash36.thinkingConfig, { thinkingLevel: "low" });
  assert.equal(flashLite35.responseSchema, schema);
  assert.equal(flash36.responseSchema, schema);
  assert.equal(flashLite35.maxOutputTokens, 8192);
  assert.equal(flash36.maxOutputTokens, 8192);
  assert.equal("temperature" in flashLite35, false);
  assert.equal("temperature" in flash36, false);
});
