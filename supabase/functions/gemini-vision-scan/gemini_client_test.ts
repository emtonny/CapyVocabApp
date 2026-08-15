import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGenerationConfig,
  fetchGeminiModelChain,
  type GeminiHealthStore,
  type GeminiModelHealth,
  MODEL_CHAIN,
} from "./gemini_client.ts";

const silentLogger = {
  warn() {},
  error() {},
};

function successfulResponse() {
  return new Response(JSON.stringify({ candidates: [] }), { status: 200 });
}

class InMemoryHealthStore implements GeminiHealthStore {
  readonly state = new Map<
    string,
    { isHealthy: boolean; consecutiveFailures: number }
  >();

  getModelHealth(
    modelNames: readonly string[],
  ): Promise<readonly GeminiModelHealth[]> {
    return Promise.resolve(modelNames.flatMap((modelName) => {
      const health = this.state.get(modelName);
      return health ? [{ modelName, isHealthy: health.isHealthy }] : [];
    }));
  }

  recordSuccess(modelName: string): Promise<void> {
    this.state.set(modelName, {
      isHealthy: true,
      consecutiveFailures: 0,
    });
    return Promise.resolve();
  }

  recordSystemFailure(modelName: string): Promise<void> {
    const previous = this.state.get(modelName);
    const consecutiveFailures = (previous?.consecutiveFailures ?? 0) + 1;
    this.state.set(modelName, {
      isHealthy: consecutiveFailures < 3,
      consecutiveFailures,
    });
    return Promise.resolve();
  }
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
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(
        statuses.shift() === 200
          ? successfulResponse()
          : new Response("unavailable", { status: 503 }),
      );
    },
    sleep: () => Promise.resolve(),
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
      fetcher: (input) => {
        calls.push(String(input));
        if (calls.length === 1) {
          if (firstFailure === "network") {
            return Promise.reject(new TypeError("mock network error"));
          }
          return Promise.resolve(
            new Response("model-specific or temporary error", {
              status: firstFailure,
            }),
          );
        }
        return Promise.resolve(successfulResponse());
      },
      sleep: () => Promise.resolve(),
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
      fetcher: () => {
        callCount += 1;
        return Promise.resolve(new Response("request rejected", { status }));
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

test("deprioritizes a model on the scan after three system failures", async () => {
  const healthStore = new InMemoryHealthStore();

  for (let scan = 1; scan <= 3; scan += 1) {
    const calls: string[] = [];
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `health-failure-${scan}`,
      createRequestBody: (model) => ({ model }),
      fetcher: (input) => {
        const url = String(input);
        calls.push(url);
        return Promise.resolve(
          url.includes(MODEL_CHAIN[0])
            ? new Response("temporary system failure", { status: 500 })
            : successfulResponse(),
        );
      },
      healthStore,
      logger: silentLogger,
    });

    assert.deepEqual(
      calls.map((url) => MODEL_CHAIN.find((model) => url.includes(model))),
      [MODEL_CHAIN[0], MODEL_CHAIN[1]],
    );
    assert.equal(result.model, MODEL_CHAIN[1]);
  }

  assert.deepEqual(healthStore.state.get(MODEL_CHAIN[0]), {
    isHealthy: false,
    consecutiveFailures: 3,
  });

  const nextScanCalls: string[] = [];
  const nextResult = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "health-reordered-scan",
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      nextScanCalls.push(String(input));
      return Promise.resolve(successfulResponse());
    },
    healthStore,
    logger: silentLogger,
  });

  assert.deepEqual(
    nextScanCalls.map((url) =>
      MODEL_CHAIN.find((model) => url.includes(model))
    ),
    [MODEL_CHAIN[1]],
  );
  assert.equal(nextResult.model, MODEL_CHAIN[1]);
  assert.equal(nextResult.modelsTried, 1);
});

test("does not count client or quota responses as health failures", async () => {
  for (const status of [400, 429]) {
    const healthStore = new InMemoryHealthStore();
    await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `health-ignored-${status}`,
      createRequestBody: (model) => ({ model }),
      fetcher: (input) =>
        Promise.resolve(
          String(input).includes(MODEL_CHAIN[0])
            ? new Response("ignored health response", { status })
            : successfulResponse(),
        ),
      healthStore,
      logger: silentLogger,
    });

    assert.equal(healthStore.state.has(MODEL_CHAIN[0]), false);
  }
});

test("falls back to the default chain when health storage fails", async () => {
  const calls: string[] = [];
  const unavailableHealthStore: GeminiHealthStore = {
    getModelHealth: () => Promise.reject(new Error("mock database error")),
    recordSuccess: () => Promise.reject(new Error("mock database error")),
    recordSystemFailure: () => Promise.reject(new Error("mock database error")),
  };

  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "health-store-unavailable",
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(successfulResponse());
    },
    healthStore: unavailableHealthStore,
    logger: silentLogger,
  });

  assert.equal(result.model, MODEL_CHAIN[0]);
  assert.deepEqual(
    calls.map((url) => MODEL_CHAIN.find((model) => url.includes(model))),
    [MODEL_CHAIN[0]],
  );
});
