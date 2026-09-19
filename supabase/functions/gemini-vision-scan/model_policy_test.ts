import assert from "node:assert/strict";
import test from "node:test";

import {
  resolveModelPolicy,
  shouldFallbackModelFailure,
  shouldRetryModelFailure,
} from "./model_policy.ts";

const noSecrets = () => undefined;

test("defaults Free and Pro to gemini-3.8-flash with no fallback", () => {
  assert.deepEqual(resolveModelPolicy("free", noSecrets), {
    tier: "free",
    primaryModel: "gemini-3.8-flash",
    fallbackModel: null,
  });
  assert.deepEqual(resolveModelPolicy("pro", noSecrets), {
    tier: "pro",
    primaryModel: "gemini-3.8-flash",
    fallbackModel: null,
  });
});

test("reads model names only from server environment", () => {
  const secrets = new Map([
    ["GEMINI_MODEL", "custom-vilao-model"],
  ]);

  assert.deepEqual(resolveModelPolicy("free", (name) => secrets.get(name)), {
    tier: "free",
    primaryModel: "custom-vilao-model",
    fallbackModel: null,
  });
  assert.deepEqual(resolveModelPolicy("pro", (name) => secrets.get(name)), {
    tier: "pro",
    primaryModel: "custom-vilao-model",
    fallbackModel: null,
  });
});

test("never falls back on errors for Free or Pro", () => {
  for (const tier of ["free", "pro"] as const) {
    const policy = resolveModelPolicy(tier, noSecrets);

    for (const status of [400, 401, 403, 404, 413, 422, 429, 500, 502, 503, 504]) {
      assert.equal(shouldFallbackModelFailure(policy, { status }), false);
    }
    assert.equal(
      shouldFallbackModelFailure(policy, { kind: "network" }),
      false,
    );
    assert.equal(
      shouldFallbackModelFailure(policy, { kind: "timeout" }),
      false,
    );
  }
});

test("only 503 and network failures get one same-model retry", () => {
  assert.equal(shouldRetryModelFailure({ status: 503 }), true);
  assert.equal(shouldRetryModelFailure({ kind: "network" }), true);
  assert.equal(shouldRetryModelFailure({ kind: "timeout" }), true);

  for (const status of [400, 401, 403, 422, 429, 500, 502, 504]) {
    assert.equal(shouldRetryModelFailure({ status }), false);
  }
});
