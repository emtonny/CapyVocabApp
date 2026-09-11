import assert from "node:assert/strict";
import test from "node:test";

import {
  createSupabaseGeminiHealthStore,
  DEFAULT_GEMINI_CIRCUIT_CONFIG,
  resolveGeminiCircuitConfig,
} from "./gemini_model_health.ts";

test("reuses a warm-worker health read until the cache expires", async () => {
  let requestCount = 0;
  let now = 1_000;
  const store = createSupabaseGeminiHealthStore({
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-key",
    cacheTtlMs: 10_000,
    now: () => now,
    fetcher: () => {
      requestCount += 1;
      return Promise.resolve(
        Response.json([{ model_name: "model-a", is_healthy: true }]),
      );
    },
  });

  assert.deepEqual(await store.getModelHealth(["model-a"]), [
    { modelName: "model-a", isHealthy: true },
  ]);
  assert.deepEqual(await store.getModelHealth(["model-a"]), [
    { modelName: "model-a", isHealthy: true },
  ]);
  assert.equal(requestCount, 1);

  now += 10_001;
  await store.getModelHealth(["model-a"]);
  assert.equal(requestCount, 2);
});

test("reads circuit thresholds from config without embedding quota limits", () => {
  const values: Record<string, string> = {
    GEMINI_CIRCUIT_FAILURE_THRESHOLD: "5",
    GEMINI_CIRCUIT_COOLDOWN_SECONDS: "120",
    GEMINI_CIRCUIT_HALF_OPEN_LEASE_SECONDS: "50",
  };

  assert.deepEqual(resolveGeminiCircuitConfig((name) => values[name]), {
    failureThreshold: 5,
    cooldownSeconds: 120,
    halfOpenLeaseSeconds: 50,
  });
  assert.deepEqual(
    resolveGeminiCircuitConfig(() => undefined),
    DEFAULT_GEMINI_CIRCUIT_CONFIG,
  );
  assert.throws(
    () =>
      resolveGeminiCircuitConfig((name) =>
        name === "GEMINI_CIRCUIT_FAILURE_THRESHOLD" ? "0" : undefined
      ),
    /GEMINI_CIRCUIT_FAILURE_THRESHOLD/,
  );
});

test("acquires an atomic permit and writes typed quota telemetry", async () => {
  const requests: Array<{ path: string; body: unknown }> = [];
  const store = createSupabaseGeminiHealthStore({
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-key",
    circuitConfig: {
      failureThreshold: 4,
      cooldownSeconds: 90,
      halfOpenLeaseSeconds: 40,
    },
    fetcher: (input, init) => {
      const path = new URL(String(input)).pathname;
      requests.push({
        path,
        body: init?.body ? JSON.parse(String(init.body)) : null,
      });
      if (path.endsWith("/acquire_gemini_model_attempt")) {
        return Promise.resolve(
          Response.json([{
            allowed: true,
            circuit_state: "half_open",
            probe_token: "13b0d36f-56e0-44ea-b289-053f1ed01886",
            retry_after_seconds: null,
          }]),
        );
      }
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  });

  assert.deepEqual(await store.acquireAttempt?.("gemini-3.7-flash"), {
    allowed: true,
    state: "half_open",
    probeToken: "13b0d36f-56e0-44ea-b289-053f1ed01886",
    retryAfterSeconds: null,
  });
  await store.recordQuotaError?.(
    "gemini-3.7-flash",
    "tpm",
    "13b0d36f-56e0-44ea-b289-053f1ed01886",
  );

  assert.deepEqual(requests, [
    {
      path: "/rest/v1/rpc/acquire_gemini_model_attempt",
      body: {
        p_model_name: "gemini-3.7-flash",
        p_half_open_lease_seconds: 40,
      },
    },
    {
      path: "/rest/v1/rpc/record_gemini_model_outcome",
      body: {
        p_model_name: "gemini-3.7-flash",
        p_outcome: "quota_error",
        p_failure_threshold: 4,
        p_cooldown_seconds: 90,
        p_probe_token: "13b0d36f-56e0-44ea-b289-053f1ed01886",
        p_quota_kind: "tpm",
      },
    },
  ]);
});
