import assert from "node:assert/strict";
import test from "node:test";

import {
  createSupabaseScanLedgerStore,
  ScanLedgerUnavailableError,
} from "./scan_ledger.ts";

const NOW = new Date("2026-08-28T10:00:00.000Z");
const USER_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const REQUEST_ID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

test("reserve uses the short database RPC and authenticated server identity", async () => {
  let requestedUrl = "";
  let requestedInit: RequestInit | undefined;
  const store = createSupabaseScanLedgerStore({
    supabaseUrl: "https://project.supabase.co/",
    serviceRoleKey: "service-role-test-key",
    fetcher: (input, init) => {
      requestedUrl = String(input);
      requestedInit = init;
      return Promise.resolve(Response.json([{
        decision: "reserved",
        attempt_count: 0,
        result_json: null,
        model_used: null,
        service_tier: "free",
        input_token_count: 0,
        output_token_count: 0,
        total_token_count: 0,
      }]));
    },
  });

  const reservation = await store.reserve({
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    serviceTier: "free",
  });

  assert.equal(
    new URL(requestedUrl).pathname,
    "/rest/v1/rpc/reserve_ai_scan_request",
  );
  assert.equal(requestedInit?.method, "POST");
  assert.equal(
    new Headers(requestedInit?.headers).get("authorization"),
    "Bearer service-role-test-key",
  );
  assert.deepEqual(JSON.parse(String(requestedInit?.body)), {
    p_user_id: USER_ID,
    p_client_request_id: REQUEST_ID,
    p_service_tier: "free",
  });
  assert.deepEqual(reservation, {
    decision: "reserved",
    attemptCount: 0,
    resultJson: null,
    modelUsed: null,
    serviceTier: "free",
    inputTokenCount: 0,
    outputTokenCount: 0,
    totalTokenCount: 0,
  });
});

test("reserve returns a completed result for idempotent replay", async () => {
  const cachedResult = { words: [{ word: "apple" }] };
  const store = createSupabaseScanLedgerStore({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "service-role-test-key",
    fetcher: () =>
      Promise.resolve(Response.json([{
        decision: "replay",
        attempt_count: 1,
        result_json: cachedResult,
        model_used: "gemini-3.5-flash-lite",
        service_tier: "free",
        input_token_count: 90,
        output_token_count: 10,
        total_token_count: 100,
      }])),
  });

  const reservation = await store.reserve({
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    serviceTier: "free",
  });

  assert.equal(reservation.decision, "replay");
  assert.deepEqual(reservation.resultJson, cachedResult);
  assert.equal(reservation.attemptCount, 1);
});

test("success completion records RPD and cost telemetry without image data", async () => {
  let requestedUrl = "";
  let requestedBody: Record<string, unknown> = {};
  const store = createSupabaseScanLedgerStore({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "service-role-test-key",
    now: () => NOW,
    fetcher: (input, init) => {
      requestedUrl = String(input);
      requestedBody = JSON.parse(String(init?.body));
      return Promise.resolve(Response.json([{ id: "ledger-row" }]));
    },
  });

  await store.completeSuccess({
    userId: USER_ID,
    clientRequestId: REQUEST_ID,
    baseAttemptCount: 1,
    baseInputTokenCount: 90,
    baseOutputTokenCount: 10,
    baseTotalTokenCount: 100,
    upstreamAttempts: 1,
    modelUsed: "gemini-3.7-flash",
    latencyMs: 1234,
    inputTokenCount: 100,
    outputTokenCount: 20,
    totalTokenCount: 120,
    wordCount: 8,
    resultJson: { words: [] },
  });

  const url = new URL(requestedUrl);
  assert.equal(url.pathname, "/rest/v1/ai_scan_requests");
  assert.equal(url.searchParams.get("user_id"), `eq.${USER_ID}`);
  assert.equal(
    url.searchParams.get("client_request_id"),
    `eq.${REQUEST_ID}`,
  );
  assert.equal(url.searchParams.get("status"), "eq.processing");
  assert.equal(requestedBody.status, "succeeded");
  assert.equal(requestedBody.attempt_count, 2);
  assert.equal(requestedBody.input_token_count, 190);
  assert.equal(requestedBody.output_token_count, 30);
  assert.equal(requestedBody.total_token_count, 220);
  assert.equal(requestedBody.result_expires_at, "2026-08-29T10:00:00.000Z");
  assert.equal("image_base64" in requestedBody, false);
  assert.equal("image_hash" in requestedBody, false);
});

test("database failures are distinguishable and fail before duplicate work", async () => {
  const store = createSupabaseScanLedgerStore({
    supabaseUrl: "https://project.supabase.co",
    serviceRoleKey: "service-role-test-key",
    fetcher: () =>
      Promise.resolve(
        new Response("database down", {
          status: 503,
        }),
      ),
  });

  await assert.rejects(
    () =>
      store.reserve({
        userId: USER_ID,
        clientRequestId: REQUEST_ID,
        serviceTier: "free",
      }),
    ScanLedgerUnavailableError,
  );
});
