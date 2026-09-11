import assert from "node:assert/strict";
import test from "node:test";

import { createGeminiStubHandler } from "./gemini_stub.ts";
import {
  type LoadResult,
  summarizeLoadResults,
  tierForRequest,
  validateProfileSample,
} from "./load_test.ts";

test("mixed P6 profiles allocate the exact Pro share per 100 requests", () => {
  const countPro = (profile: "free99-pro1" | "free98-pro2") =>
    Array.from({ length: 100 }, (_, index) => tierForRequest(profile, index))
      .filter((tier) => tier === "pro").length;

  assert.equal(countPro("free99-pro1"), 1);
  assert.equal(countPro("free98-pro2"), 2);
});

test("mixed P6 profiles reject samples too small to contain Pro traffic", () => {
  assert.throws(
    () => validateProfileSample("free99-pro1", 99),
    /at least 100 requests/,
  );
  assert.throws(
    () => validateProfileSample("free98-pro2", 49),
    /at least 50 requests/,
  );
  assert.doesNotThrow(() => validateProfileSample("free99-pro1", 100));
});

test("P6 summary rejects cross-tier routing and accepts a clean run", () => {
  const clean: LoadResult[] = [
    {
      expectedTier: "free",
      status: 200,
      latencyMs: 10,
      serviceTier: "free",
      modelUsed: "lite",
    },
    {
      expectedTier: "pro",
      status: 200,
      latencyMs: 20,
      serviceTier: "pro",
      modelUsed: "flash",
    },
  ];
  assert.equal(
    summarizeLoadResults(clean, "lite", new Set(["flash", "fallback"]))
      .passed,
    true,
  );

  const crossed = [{ ...clean[0], modelUsed: "flash" }];
  const summary = summarizeLoadResults(
    crossed,
    "lite",
    new Set(["flash", "fallback"]),
  );
  assert.equal(summary.passed, false);
  assert.equal(summary.modelMismatches, 1);
});

test("Gemini stub returns the current JSON response envelope", async () => {
  const handler = createGeminiStubHandler();
  const response = await handler(
    new Request(
      "http://127.0.0.1:8787/v1beta/models/gemini-test:generateContent",
      { method: "POST" },
    ),
  );
  const body = await response.json();
  const rawText = body.candidates[0].content.parts[0].text;

  assert.equal(response.status, 200);
  assert.deepEqual(JSON.parse(rawText), { schema_version: 2, words: [] });
  assert.equal(response.headers.get("X-P6-Gemini-Stub"), "true");
});
