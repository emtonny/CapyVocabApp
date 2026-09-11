import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGenerationConfig,
  classifyGeminiQuotaError,
  fetchGeminiModelChain,
  GeminiCircuitOpenError,
  type GeminiCircuitPermit,
  type GeminiHealthStore,
  type GeminiModelHealth,
  type GeminiQuotaKind,
} from "./gemini_client.ts";
import type { GeminiModelPolicy } from "./model_policy.ts";

const FREE_MODEL = "gemini-3.5-flash-lite";
const PRO_PRIMARY_MODEL = "gemini-3.7-flash";
const PRO_FALLBACK_MODEL = "gemini-3.6-flash";
const FREE_POLICY: GeminiModelPolicy = {
  tier: "free",
  primaryModel: FREE_MODEL,
  fallbackModel: null,
};
const PRO_POLICY: GeminiModelPolicy = {
  tier: "pro",
  primaryModel: PRO_PRIMARY_MODEL,
  fallbackModel: PRO_FALLBACK_MODEL,
};

const silentLogger = {
  warn() {},
  error() {},
};

function successfulResponse() {
  return new Response(JSON.stringify({ candidates: [] }), { status: 200 });
}

test("P6 can redirect Gemini traffic to an explicit stub base URL", async () => {
  const calls: string[] = [];

  await fetchGeminiModelChain({
    apiKey: "stub-key",
    apiBaseUrl: "http://127.0.0.1:8787/v1beta/models/",
    scanId: "p6-stub-url",
    modelPolicy: FREE_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(successfulResponse());
    },
    logger: silentLogger,
  });

  assert.deepEqual(calls, [
    `http://127.0.0.1:8787/v1beta/models/${FREE_MODEL}:generateContent?key=stub-key`,
  ]);
});

class InMemoryHealthStore implements GeminiHealthStore {
  readonly state = new Map<
    string,
    { isHealthy: boolean; consecutiveFailures: number }
  >();
  readonly quotaErrors: Array<{ modelName: string; kind: GeminiQuotaKind }> =
    [];

  acquireAttempt(modelName: string): Promise<GeminiCircuitPermit> {
    const health = this.state.get(modelName);
    return Promise.resolve({
      allowed: health?.isHealthy ?? true,
      state: health?.isHealthy === false ? "open" : "healthy",
      probeToken: null,
      retryAfterSeconds: health?.isHealthy === false ? 60 : null,
    });
  }

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

  recordQuotaError(
    modelName: string,
    kind: GeminiQuotaKind,
  ): Promise<void> {
    this.quotaErrors.push({ modelName, kind });
    return Promise.resolve();
  }
}

test("Free uses only Flash-Lite and never falls back", async () => {
  for (const status of [429, 500, 502, 504]) {
    const calls: string[] = [];
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `free-${status}`,
      modelPolicy: FREE_POLICY,
      createRequestBody: (model) => ({ model }),
      fetcher: (input) => {
        calls.push(String(input));
        return Promise.resolve(new Response("failed", { status }));
      },
      logger: silentLogger,
    });

    assert.equal(calls.length, 1);
    assert.equal(calls[0].includes(FREE_MODEL), true);
    assert.equal(result.model, FREE_MODEL);
    assert.equal(result.modelsTried, 1);
    assert.equal(result.response.status, status);
  }
});

test("Free retries one 503 on Lite but still never enters Pro pool", async () => {
  const calls: string[] = [];
  const delays: number[] = [];
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "free-503",
    modelPolicy: FREE_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(new Response("unavailable", { status: 503 }));
    },
    sleep: (delay) => {
      delays.push(delay);
      return Promise.resolve();
    },
    random: () => 0,
    logger: silentLogger,
  });

  assert.equal(calls.length, 2);
  assert.equal(calls.every((url) => url.includes(FREE_MODEL)), true);
  assert.deepEqual(delays, [750]);
  assert.equal(result.response.status, 503);
  assert.equal(result.modelsTried, 1);
});

test("Pro uses fallback as its only retry after 503", async () => {
  const calls: string[] = [];
  const delays: number[] = [];
  const statuses = [503, 200];

  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "scan-503",
    modelPolicy: PRO_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(
        statuses.shift() === 200
          ? successfulResponse()
          : new Response("unavailable", { status: 503 }),
      );
    },
    sleep: (delay) => {
      delays.push(delay);
      return Promise.resolve();
    },
    logger: silentLogger,
  });

  assert.equal(calls[0].includes(PRO_PRIMARY_MODEL), true);
  assert.equal(calls[1].includes(PRO_FALLBACK_MODEL), true);
  assert.equal(calls.length, 2);
  assert.deepEqual(delays, []);
  assert.equal(result.model, PRO_FALLBACK_MODEL);
  assert.equal(result.modelsTried, 2);
  assert.equal(result.attemptsForModel, 1);
  assert.equal(result.upstreamAttempts, 2);
});

test("Pro falls back only for 500, 502, and 504 responses", async () => {
  for (const firstFailure of [500, 502, 504] as const) {
    const calls: string[] = [];
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `scan-${firstFailure}`,
      modelPolicy: PRO_POLICY,
      createRequestBody: (model) => ({ model }),
      fetcher: (input) => {
        calls.push(String(input));
        if (calls.length === 1) {
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
    assert.equal(calls[0].includes(PRO_PRIMARY_MODEL), true);
    assert.equal(calls[1].includes(PRO_FALLBACK_MODEL), true);
    assert.equal(result.model, PRO_FALLBACK_MODEL);
    assert.equal(result.modelsTried, 2);
  }
});

test("Pro never falls back on 429", async () => {
  let callCount = 0;
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "pro-429",
    modelPolicy: PRO_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: () => {
      callCount += 1;
      return Promise.resolve(new Response("quota", { status: 429 }));
    },
    logger: silentLogger,
  });

  assert.equal(callCount, 1);
  assert.equal(result.model, PRO_PRIMARY_MODEL);
  assert.equal(result.response.status, 429);
  assert.equal(result.upstreamAttempts, 1);
});

test("429 with Retry-After retries the same model once and never falls back", async () => {
  let callCount = 0;
  const delays: number[] = [];
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "pro-rpm-429",
    modelPolicy: PRO_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: () => {
      callCount += 1;
      return Promise.resolve(
        callCount === 1
          ? new Response("rpm", {
            status: 429,
            headers: { "Retry-After": "1" },
          })
          : successfulResponse(),
      );
    },
    sleep: (delay) => {
      delays.push(delay);
      return Promise.resolve();
    },
    logger: silentLogger,
  });

  assert.equal(callCount, 2);
  assert.deepEqual(delays, [1000]);
  assert.equal(result.model, PRO_PRIMARY_MODEL);
  assert.equal(result.modelsTried, 1);
  assert.equal(result.upstreamAttempts, 2);
});

test("Pro uses fallback as its only retry after a network failure", async () => {
  let callCount = 0;
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "pro-network",
    modelPolicy: PRO_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: () => {
      callCount += 1;
      return callCount === 1
        ? Promise.reject(new TypeError("mock network error"))
        : Promise.resolve(successfulResponse());
    },
    sleep: () => Promise.resolve(),
    random: () => 0,
    logger: silentLogger,
  });

  assert.equal(callCount, 2);
  assert.equal(result.model, PRO_FALLBACK_MODEL);
  assert.equal(result.modelsTried, 2);
  assert.equal(result.upstreamAttempts, 2);
});

test("Pro uses fallback as its only retry after timeout", async () => {
  let callCount = 0;
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "scan-timeout",
    modelPolicy: PRO_POLICY,
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
    sleep: () => Promise.resolve(),
    random: () => 0,
    logger: silentLogger,
  });

  assert.equal(callCount, 2);
  assert.equal(result.model, PRO_FALLBACK_MODEL);
  assert.equal(result.modelsTried, 2);
  assert.equal(result.upstreamAttempts, 2);
});

test("does not switch model for request, auth, not-found, or payload errors", async () => {
  for (const status of [400, 401, 403, 404, 413, 422]) {
    let callCount = 0;
    const result = await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `scan-${status}`,
      modelPolicy: PRO_POLICY,
      createRequestBody: (model) => ({ model }),
      fetcher: () => {
        callCount += 1;
        return Promise.resolve(new Response("request rejected", { status }));
      },
      logger: silentLogger,
    });

    assert.equal(callCount, 1);
    assert.equal(result.response.status, status);
    assert.equal(result.model, PRO_PRIMARY_MODEL);
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

test("Pro skips an open primary circuit and uses only its Pro fallback", async () => {
  const healthStore = new InMemoryHealthStore();
  healthStore.state.set(PRO_PRIMARY_MODEL, {
    isHealthy: false,
    consecutiveFailures: 3,
  });
  const calls: string[] = [];
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "health-does-not-reorder",
    modelPolicy: PRO_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(successfulResponse());
    },
    healthStore,
    logger: silentLogger,
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].includes(PRO_FALLBACK_MODEL), true);
  assert.equal(result.model, PRO_FALLBACK_MODEL);
  assert.equal(result.upstreamAttempts, 1);
});

test("Free rejects an open Flash-Lite circuit without entering a Pro pool", async () => {
  const healthStore = new InMemoryHealthStore();
  healthStore.state.set(FREE_MODEL, {
    isHealthy: false,
    consecutiveFailures: 3,
  });
  let callCount = 0;

  await assert.rejects(
    () =>
      fetchGeminiModelChain({
        apiKey: "test-key",
        scanId: "free-circuit-open",
        modelPolicy: FREE_POLICY,
        createRequestBody: (model) => ({ model }),
        fetcher: () => {
          callCount += 1;
          return Promise.resolve(successfulResponse());
        },
        healthStore,
        logger: silentLogger,
      }),
    (error: unknown) => {
      assert.equal(error instanceof GeminiCircuitOpenError, true);
      if (error instanceof GeminiCircuitOpenError) {
        assert.equal(error.model, FREE_MODEL);
        assert.equal(error.upstreamAttempts, 0);
        assert.equal(error.retryAfterSeconds, 60);
      }
      return true;
    },
  );
  assert.equal(callCount, 0);
});

test("does not count client or quota responses as health failures", async () => {
  for (const status of [400, 429]) {
    const healthStore = new InMemoryHealthStore();
    await fetchGeminiModelChain({
      apiKey: "test-key",
      scanId: `health-ignored-${status}`,
      modelPolicy: PRO_POLICY,
      createRequestBody: (model) => ({ model }),
      fetcher: (input) =>
        Promise.resolve(
          String(input).includes(PRO_PRIMARY_MODEL)
            ? new Response("ignored health response", { status })
            : successfulResponse(),
        ),
      healthStore,
      logger: silentLogger,
    });

    assert.equal(healthStore.state.has(PRO_PRIMARY_MODEL), false);
  }
});

test("classifies only explicit Gemini quota dimensions", async () => {
  const quotaResponse = (quotaId: string) =>
    Response.json(
      {
        error: {
          code: 429,
          details: [{ violations: [{ quotaId }] }],
        },
      },
      { status: 429 },
    );

  assert.equal(
    await classifyGeminiQuotaError(
      quotaResponse("GenerateRequestsPerMinutePerProjectPerModel"),
    ),
    "rpm",
  );
  assert.equal(
    await classifyGeminiQuotaError(
      quotaResponse("GenerateContentInputTokensPerModelPerMinute"),
    ),
    "tpm",
  );
  assert.equal(
    await classifyGeminiQuotaError(
      quotaResponse("GenerateRequestsPerDayPerProjectPerModel-FreeTier"),
    ),
    "rpd",
  );
  assert.equal(
    await classifyGeminiQuotaError(new Response("quota", { status: 429 })),
    "unknown",
  );
});

test("429 records quota telemetry without marking the model failed", async () => {
  const healthStore = new InMemoryHealthStore();
  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "quota-rpd-telemetry",
    modelPolicy: FREE_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: () =>
      Promise.resolve(
        Response.json(
          {
            error: {
              code: 429,
              details: [{
                violations: [{
                  quotaId: "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
                }],
              }],
            },
          },
          { status: 429 },
        ),
      ),
    healthStore,
    logger: silentLogger,
  });

  assert.equal(result.quotaKind, "rpd");
  assert.deepEqual(healthStore.quotaErrors, [
    { modelName: FREE_MODEL, kind: "rpd" },
  ]);
  assert.equal(healthStore.state.has(FREE_MODEL), false);
});

import {
  createCachedGeminiHealthStore,
  HEALTH_CACHE_TTL_MS,
} from "./gemini_model_health.ts";

test("health storage failures do not change the configured model", async () => {
  const calls: string[] = [];
  const unavailableHealthStore: GeminiHealthStore = {
    getModelHealth: () => Promise.reject(new Error("mock database error")),
    recordSuccess: () => Promise.reject(new Error("mock database error")),
    recordSystemFailure: () => Promise.reject(new Error("mock database error")),
  };

  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "health-store-unavailable",
    modelPolicy: FREE_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: (input) => {
      calls.push(String(input));
      return Promise.resolve(successfulResponse());
    },
    healthStore: unavailableHealthStore,
    logger: silentLogger,
  });

  assert.equal(result.model, FREE_MODEL);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].includes(FREE_MODEL), true);
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

  const currentTime = 1000;
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

  const currentTime = 1000;
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

test("scheduled health telemetry does not block a successful response", async () => {
  let finishWrite!: () => void;
  const pendingWrite = new Promise<void>((resolve) => {
    finishWrite = resolve;
  });
  const scheduledTasks: Promise<void>[] = [];
  const healthStore: GeminiHealthStore = {
    getModelHealth: () => Promise.resolve([]),
    recordSuccess: () => pendingWrite,
    recordSystemFailure: () => Promise.resolve(),
  };

  const result = await fetchGeminiModelChain({
    apiKey: "test-key",
    scanId: "background-health-write",
    modelPolicy: FREE_POLICY,
    createRequestBody: (model) => ({ model }),
    fetcher: () => Promise.resolve(successfulResponse()),
    healthStore,
    scheduleBackgroundTask: (task) => scheduledTasks.push(task),
    logger: silentLogger,
  });

  assert.equal(result.response.status, 200);
  assert.equal(scheduledTasks.length, 1);
  finishWrite();
  await scheduledTasks[0];
});
