import assert from "node:assert/strict";
import test from "node:test";

import {
  resolveModelPolicy,
  shouldFallbackModelFailure,
  shouldRetryModelFailure,
} from "./model_policy.ts";

const noSecrets = () => undefined;

test("defaults Free to Flash-Lite with no fallback", () => {
  assert.deepEqual(resolveModelPolicy("free", noSecrets), {
    tier: "free",
    primaryModel: "gemini-3.5-flash-lite",
    fallbackModel: null,
  });
});

test("defaults Pro to 3.7 Flash then 3.6 Flash", () => {
  assert.deepEqual(resolveModelPolicy("pro", noSecrets), {
    tier: "pro",
    primaryModel: "gemini-3.7-flash",
    fallbackModel: "gemini-3.6-flash",
  });
});

test("reads model names only from server environment", () => {
  const secrets = new Map([
    ["GEMINI_FREE_MODEL", "free-from-secret"],
    ["GEMINI_PRO_MODEL", "pro-from-secret"],
    ["GEMINI_PRO_FALLBACK_MODEL", "pro-fallback-from-secret"],
  ]);

  assert.deepEqual(resolveModelPolicy("free", (name) => secrets.get(name)), {
    tier: "free",
    primaryModel: "free-from-secret",
    fallbackModel: null,
  });
  assert.deepEqual(resolveModelPolicy("pro", (name) => secrets.get(name)), {
    tier: "pro",
    primaryModel: "pro-from-secret",
    fallbackModel: "pro-fallback-from-secret",
  });
});

test("never falls back on 429 or client/payload errors", () => {
  const policy = resolveModelPolicy("pro", noSecrets);

  for (const status of [400, 401, 403, 404, 413, 422, 429]) {
    assert.equal(shouldFallbackModelFailure(policy, { status }), false);
  }
});

test("Pro fallback is limited to system statuses and network failures", () => {
  const policy = resolveModelPolicy("pro", noSecrets);

  for (const status of [500, 502, 503, 504]) {
    assert.equal(shouldFallbackModelFailure(policy, { status }), true);
  }
  assert.equal(
    shouldFallbackModelFailure(policy, { kind: "network" }),
    true,
  );
  assert.equal(
    shouldFallbackModelFailure(policy, { kind: "timeout" }),
    true,
  );
});

test("Free never falls back, including on system failures", () => {
  const policy = resolveModelPolicy("free", noSecrets);

  assert.equal(shouldFallbackModelFailure(policy, { status: 503 }), false);
  assert.equal(
    shouldFallbackModelFailure(policy, { kind: "timeout" }),
    false,
  );
});

test("only 503 and network failures get one same-model retry", () => {
  assert.equal(shouldRetryModelFailure({ status: 503 }), true);
  assert.equal(shouldRetryModelFailure({ kind: "network" }), true);
  assert.equal(shouldRetryModelFailure({ kind: "timeout" }), true);

  for (const status of [400, 401, 403, 422, 429, 500, 502, 504]) {
    assert.equal(shouldRetryModelFailure({ status }), false);
  }
});
