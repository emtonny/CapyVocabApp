import assert from "node:assert/strict";
import test from "node:test";

import {
  authenticateRequest,
  RequestAuthenticationError,
  resolveSupabasePublicApiKey,
} from "../_shared/auth.ts";

function request(authorization?: string): Request {
  return new Request("https://edge.example/scan", {
    method: "POST",
    headers: authorization ? { authorization } : undefined,
  });
}

test("requires a Bearer JWT", async () => {
  await assert.rejects(
    () =>
      authenticateRequest(request(), {
        supabaseUrl: "https://project.supabase.co",
        publicApiKey: "public-key",
        fetcher: () => {
          throw new Error("Auth endpoint must not be called");
        },
      }),
    (error: unknown) =>
      error instanceof RequestAuthenticationError && error.status === 401,
  );
});

test("uses the authenticated JWT response as the only user id source", async () => {
  let authorization = "";
  const user = await authenticateRequest(
    request("Bearer trusted-jwt"),
    {
      supabaseUrl: "https://project.supabase.co/",
      publicApiKey: "public-key",
      fetcher: (_input, init) => {
        authorization = new Headers(init?.headers).get("authorization") ?? "";
        return Promise.resolve(Response.json({ id: "server-user-id" }));
      },
    },
  );

  assert.deepEqual(user, { id: "server-user-id" });
  assert.equal(authorization, "Bearer trusted-jwt");
});

test("maps rejected JWTs to 401", async () => {
  await assert.rejects(
    () =>
      authenticateRequest(request("Bearer rejected"), {
        supabaseUrl: "https://project.supabase.co",
        publicApiKey: "public-key",
        fetcher: () => Promise.resolve(new Response(null, { status: 401 })),
      }),
    (error: unknown) =>
      error instanceof RequestAuthenticationError &&
      error.status === 401 && error.code === "authentication_required",
  );
});

test("fails closed with 503 when Auth is unavailable", async () => {
  await assert.rejects(
    () =>
      authenticateRequest(request("Bearer token"), {
        supabaseUrl: "https://project.supabase.co",
        publicApiKey: "public-key",
        fetcher: () => Promise.resolve(new Response(null, { status: 500 })),
      }),
    (error: unknown) =>
      error instanceof RequestAuthenticationError &&
      error.status === 503 && error.code === "auth_unavailable",
  );
});

test("resolves publishable key formats without exposing service role", () => {
  assert.equal(
    resolveSupabasePublicApiKey((name) =>
      name === "SUPABASE_ANON_KEY" ? "sb_publishable_legacy-name" : undefined
    ),
    "sb_publishable_legacy-name",
  );
  assert.equal(
    resolveSupabasePublicApiKey((name) =>
      name === "SUPABASE_PUBLISHABLE_KEYS"
        ? JSON.stringify({ default: "sb_publishable_default" })
        : undefined
    ),
    "sb_publishable_default",
  );
});
