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
    "gemini-3.7-flash",
    "gemini-3.5-flash",
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
  const flash36 = buildGenerationConfig("gemini-3.6-flash", schema);
  const flash35 = buildGenerationConfig("gemini-3.5-flash", schema);

  assert.deepEqual(flash36.thinkingConfig, { thinkingLevel: "low" });
  assert.deepEqual(flash35.thinkingConfig, { thinkingLevel: "low" });
  assert.equal(flash36.responseSchema, schema);
  assert.equal(flash35.responseSchema, schema);
  assert.equal(flash36.maxOutputTokens, 8192);
  assert.equal(flash35.maxOutputTokens, 8192);
  assert.equal("temperature" in flash36, false);
  assert.equal("temperature" in flash35, false);
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

import {
  createCachedGeminiHealthStore,
  HEALTH_CACHE_TTL_MS,
} from "./gemini_model_health.ts";

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

test("health cache: cache MISS calls DB once and populates cache", async () => {
  let dbCalls = 0;
  const mockDbStore: GeminiHealthStore = {
    getModelHealth: (models) => {
      dbCalls++;
      return Promise.resolve(
        models.map((m) => ({ modelName: m, isHealthy: true })),
      );
    },
    recordSuccess: () => Promise.resolve(),
    recordSystemFailure: () => Promise.resolve(),
  };

  let currentTime = 1000;
  const cachedStore = createCachedGeminiHealthStore(mockDbStore, {
    cacheTtlMs: HEALTH_CACHE_TTL_MS,
    now: () => currentTime,
  });

  const result = await cachedStore.getModelHealth([
    "gemini-3.6-flash",
    "gemini-3.5-flash",
  ]);
  assert.equal(dbCalls, 1);
  assert.equal(result.length, 2);
  assert.equal(result[0].isHealthy, true);
  assert.equal(result[1].isHealthy, true);
});

test("health cache: cache HIT does not call DB when within 30s TTL", async () => {
  let dbCalls = 0;
  const mockDbStore: GeminiHealthStore = {
    getModelHealth: (models) => {
      dbCalls++;
      return Promise.resolve(
        models.map((m) => ({ modelName: m, isHealthy: true })),
      );
    },
    recordSuccess: () => Promise.resolve(),
    recordSystemFailure: () => Promise.resolve(),
  };

  let currentTime = 1000;
  const cachedStore = createCachedGeminiHealthStore(mockDbStore, {
    cacheTtlMs: 30_000,
    now: () => currentTime,
  });

  // First call: MISS -> calls DB
  await cachedStore.getModelHealth([
    "gemini-3.6-flash",
    "gemini-3.5-flash",
  ]);
  assert.equal(dbCalls, 1);

  // Advance time by 15s (within 30s TTL)
  currentTime += 15_000;

  // Second call: HIT -> does NOT call DB
  const cachedResult = await cachedStore.getModelHealth([
    "gemini-3.6-flash",
    "gemini-3.5-flash",
  ]);
  assert.equal(dbCalls, 1);
  assert.equal(cachedResult.length, 2);
});

test("health cache: after 30s TTL expires, cache treats request as MISS and calls DB", async () => {
  let dbCalls = 0;
  const mockDbStore: GeminiHealthStore = {
    getModelHealth: (models) => {
      dbCalls++;
      return Promise.resolve(
        models.map((m) => ({ modelName: m, isHealthy: true })),
      );
    },
    recordSuccess: () => Promise.resolve(),
    recordSystemFailure: () => Promise.resolve(),
  };

  let currentTime = 1000;
  const cachedStore = createCachedGeminiHealthStore(mockDbStore, {
    cacheTtlMs: 30_000,
    now: () => currentTime,
  });

  // First call at t = 1000: MISS -> calls DB
  await cachedStore.getModelHealth(["gemini-3.5-flash"]);
  assert.equal(dbCalls, 1);

  // Advance time beyond 30s TTL (e.g. +30_001 ms -> t = 31_001)
  currentTime += 30_001;

  // Next call: MISS because TTL expired -> calls DB again
  await cachedStore.getModelHealth(["gemini-3.5-flash"]);
  assert.equal(dbCalls, 2);
});

test("health cache: successful request on previously unhealthy model invalidates cache immediately", async () => {
  let dbCalls = 0;
  let modelHealthState = false; // Initially unhealthy in DB

  const mockDbStore: GeminiHealthStore = {
    getModelHealth: (models) => {
      dbCalls++;
      return Promise.resolve(
        models.map((m) => ({ modelName: m, isHealthy: modelHealthState })),
      );
    },
    recordSuccess: (_model) => {
      modelHealthState = true; // DB marked healthy
      return Promise.resolve();
    },
    recordSystemFailure: () => Promise.resolve(),
  };

  let currentTime = 1000;
  const cachedStore = createCachedGeminiHealthStore(mockDbStore, {
    cacheTtlMs: 30_000,
    now: () => currentTime,
  });

  // 1. Initial read: MISS -> loads unhealthy state into cache
  const firstRead = await cachedStore.getModelHealth(["gemini-3.5-flash"]);
  assert.equal(dbCalls, 1);
  assert.equal(firstRead[0].isHealthy, false);

  // 2. Model recovers: recordSuccess is called
  await cachedStore.recordSuccess("gemini-3.5-flash");

  // 3. Next read within TTL: cache was invalidated immediately on recordSuccess, so it MUST call DB (dbCalls = 2) and get fresh healthy state
  const nextRead = await cachedStore.getModelHealth(["gemini-3.5-flash"]);
  assert.equal(dbCalls, 2);
  assert.equal(nextRead[0].isHealthy, true);
});

