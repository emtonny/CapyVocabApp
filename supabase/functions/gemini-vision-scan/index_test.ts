import assert from "node:assert/strict";
import test, { mock } from "node:test";

test("scan handler preserves Vilao, auth, ledger replay and token accounting", async () => {
  const env = new Map([
    ["SUPABASE_URL", "https://scan-test.invalid"],
    ["SUPABASE_ANON_KEY", "fixture-public-key"],
    ["SUPABASE_PUBLISHABLE_KEY", "fixture-public-key"],
    ["SUPABASE_SERVICE_ROLE_KEY", "fixture-service-key"],
    ["GEMINI_API_KEY", "fixture-vilao-key"],
    ["GEMINI_BASE_URL", ""],
    ["GEMINI_API_BASE_URL", ""],
    ["GEMINI_MODEL", ""],
    ["GEMINI_HIERARCHY_RANKING_ENABLED", "false"],
    ["GEMINI_CIRCUIT_FAILURE_THRESHOLD", "3"],
    ["GEMINI_CIRCUIT_COOLDOWN_SECONDS", "60"],
    ["GEMINI_CIRCUIT_HALF_OPEN_LEASE_SECONDS", "45"],
  ]);
  const savedEnv = new Map(
    [...env.keys()].map((key) => [key, Deno.env.get(key)]),
  );
  const previousRuntime = Object.getOwnPropertyDescriptor(
    globalThis,
    "EdgeRuntime",
  );
  const tasks: Promise<unknown>[] = [];
  const calls: string[] = [];
  const unexpectedCalls: string[] = [];
  let handler: ((request: Request) => Promise<Response>) | undefined;
  let tier: "free" | "pro" = "free";
  let cachedResult: unknown = null;
  const completions: Record<string, unknown>[] = [];
  const previousServe = Object.getOwnPropertyDescriptor(Deno, "serve");
  Object.defineProperty(Deno, "serve", {
    configurable: true,
    value: (callback: (request: Request) => Promise<Response>) => {
      handler = callback;
    },
  });
  const fetchMock = mock.method(
    globalThis,
    "fetch",
    (input: string | URL | Request, init?: RequestInit) => {
      const url = new URL(String(input));
      calls.push(url.hostname + url.pathname);
      if (url.hostname === "api.vilao.ai") {
        assert.equal(url.pathname, "/v1/chat/completions");
        assert.equal(
          new Headers(init?.headers).get("authorization"),
          "Bearer fixture-vilao-key",
        );
        const body = JSON.parse(String(init?.body));
        assert.equal(body.model, "gemini-3.8-flash");
        assert.match(body.messages[0].content[0].text, /schema_version/);
        return Promise.resolve(Response.json({
          choices: [{
            finish_reason: "stop",
            message: {
              content: "```json\n" + JSON.stringify({
                schema_version: 2,
                words: [{
                  number: 1,
                  id: "d1",
                  kind: "object",
                  parent_id: null,
                  english: "cup",
                  ipa: "/kʌp/",
                  vietnamese: "cái cốc",
                  box_2d: [100, 100, 700, 700],
                }],
              }) + "\n```",
            },
          }],
          usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 },
        }));
      }
      assert.equal(url.hostname, "scan-test.invalid");
      if (url.pathname === "/auth/v1/user") {
        return Promise.resolve(
          Response.json({ id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }),
        );
      }
      if (url.pathname === "/rest/v1/subscriptions") {
        return Promise.resolve(Response.json(
          tier === "free" ? [] : [{
            plan_type: "capy_pro_monthly",
            end_date: "2099-01-01T00:00:00Z",
          }],
        ));
      }
      if (url.pathname.endsWith("/reserve_ai_scan_request")) {
        return Promise.resolve(Response.json([{
          decision: cachedResult ? "replay" : "reserved",
          attempt_count: 0,
          result_json: cachedResult,
          model_used: null,
          service_tier: tier,
          input_token_count: 0,
          output_token_count: 0,
          total_token_count: 0,
        }]));
      }
      if (url.pathname.endsWith("/acquire_gemini_model_attempt")) {
        return Promise.resolve(Response.json([{
          allowed: true,
          circuit_state: "healthy",
          probe_token: null,
          retry_after_seconds: null,
        }]));
      }
      if (url.pathname.endsWith("/record_gemini_model_outcome")) {
        return Promise
          .resolve(Response.json(null));
      }
      if (
        url.pathname === "/rest/v1/ai_scan_requests" && init?.method === "PATCH"
      ) {
        completions.push(JSON.parse(String(init.body)));
        return Promise.resolve(Response.json([{ id: "fixture-ledger" }]));
      }
      unexpectedCalls.push(url.pathname);
      return Promise.resolve(
        new Response("unexpected fixture request", { status: 500 }),
      );
    },
  );

  try {
    for (const [key, value] of env) Deno.env.set(key, value);
    Object.defineProperty(globalThis, "EdgeRuntime", {
      configurable: true,
      value: { waitUntil: (task: Promise<unknown>) => tasks.push(task) },
    });
    await import("./index.ts");
    assert.ok(handler);
    const request = (requestId: string) =>
      new Request("https://scan-test.invalid/functions/v1/gemini-vision-scan", {
        method: "POST",
        headers: {
          authorization: "Bearer fixture-user-jwt",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          image_base64: "/9j/",
          request_id: requestId,
        }),
      });
    for (tier of ["free", "pro"] as const) {
      const requestId = crypto.randomUUID();
      const response = await handler(request(requestId));
      assert.equal(response.status, 200);
      const body = await response.json();
      assert.equal(body.model_used, "gemini-3.8-flash");
      assert.equal(body.service_tier, tier);
      assert.equal(body.request_id, requestId);
      assert.equal(body.schema_version, 2);
      assert.equal(body.words[0].word, "cup");
      assert.equal(body.words[0].meaning_vi, "cái cốc");
      assert.equal(body.words[0].english, undefined);
      assert.ok(body.words[0].box.w > 0);
      const completion = completions.at(-1);
      assert.equal(completion?.status, "succeeded");
      assert.equal(completion?.input_token_count, 12);
      assert.equal(completion?.output_token_count, 8);
      assert.equal(completion?.total_token_count, 20);
      assert.equal(completion?.attempt_count, 1);
      cachedResult = body;
      const beforeReplay = calls.filter((url) =>
        url.startsWith("api.vilao.ai")
      ).length;
      const replay = await handler(request(requestId));
      assert.equal(replay.headers.get("X-Idempotency-Replayed"), "true");
      assert.deepEqual(await replay.json(), body);
      assert.equal(
        calls.filter((url) => url.startsWith("api.vilao.ai")).length,
        beforeReplay,
      );
      cachedResult = null;
    }
    const beforeUnauthorized = calls.length;
    const unauthorized = await handler(
      new Request("https://scan-test.invalid/", { method: "POST" }),
    );
    assert.equal(unauthorized.status, 401);
    assert.equal(calls.length, beforeUnauthorized);
    assert.deepEqual(unexpectedCalls, []);
    await Promise.all(tasks);
  } finally {
    fetchMock.mock.restore();
    if (previousServe) Object.defineProperty(Deno, "serve", previousServe);
    if (previousRuntime) {
      Object.defineProperty(globalThis, "EdgeRuntime", previousRuntime);
    } else Reflect.deleteProperty(globalThis, "EdgeRuntime");
    for (const [key, value] of savedEnv) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
