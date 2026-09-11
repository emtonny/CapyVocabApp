import assert from "node:assert/strict";
import test from "node:test";

import {
  APP_CAPABILITIES,
  CapabilityDeniedError,
  createSupabaseEntitlementStore,
  EntitlementResolutionError,
  type EntitlementStore,
  hasCapability,
  requireCapability,
  resolveEntitlements,
} from "../_shared/entitlements.ts";

const NOW = new Date("2026-08-27T12:00:00.000Z");

function storeReturning(
  subscription: Awaited<ReturnType<EntitlementStore["findActiveSubscription"]>>,
): EntitlementStore {
  return {
    findActiveSubscription: () => Promise.resolve(subscription),
  };
}

test("defaults users without a valid subscription to Free", async () => {
  const entitlements = await resolveEntitlements(
    "user-free",
    storeReturning(null),
    NOW,
  );

  assert.equal(entitlements.tier, "free");
  assert.deepEqual([...entitlements.capabilities], [
    APP_CAPABILITIES.aiScanBasic,
  ]);
});

test("grants Pro only for a supported, unexpired active plan", async () => {
  const entitlements = await resolveEntitlements(
    "user-pro",
    storeReturning({
      planType: "capy_pro_monthly",
      endDate: "2026-09-27T12:00:00.000Z",
    }),
    NOW,
  );

  assert.equal(entitlements.tier, "pro");
  assert.equal(
    entitlements.capabilities.has(APP_CAPABILITIES.aiScanAdvanced),
    true,
  );
});

test("unknown or expired plans fail closed to Free", async () => {
  const unknownPlan = await resolveEntitlements(
    "user-unknown",
    storeReturning({
      planType: "client_forged_pro",
      endDate: "2026-09-27T12:00:00.000Z",
    }),
    NOW,
  );
  const expiredPlan = await resolveEntitlements(
    "user-expired",
    storeReturning({
      planType: "capy_pro_monthly",
      endDate: "2026-08-27T11:59:59.000Z",
    }),
    NOW,
  );

  assert.equal(unknownPlan.tier, "free");
  assert.equal(expiredPlan.tier, "free");
});

test("hasCapability and requireCapability share centralized policy", async () => {
  const freeStore = storeReturning(null);

  assert.equal(
    await hasCapability(
      "user-free",
      APP_CAPABILITIES.aiScanBasic,
      freeStore,
      NOW,
    ),
    true,
  );
  await assert.rejects(
    () =>
      requireCapability(
        "user-free",
        APP_CAPABILITIES.aiScanAdvanced,
        freeStore,
        NOW,
      ),
    CapabilityDeniedError,
  );
});

test("database errors are distinguishable and never become Pro", async () => {
  const failingStore: EntitlementStore = {
    findActiveSubscription: () => Promise.reject(new Error("database down")),
  };

  await assert.rejects(
    () => resolveEntitlements("user", failingStore, NOW),
    EntitlementResolutionError,
  );
});

test("Supabase store queries only active, unexpired subscription for user", async () => {
  let requestedUrl = "";
  let authorization = "";
  const store = createSupabaseEntitlementStore({
    supabaseUrl: "https://project.supabase.co/",
    serviceRoleKey: "service-role-test-key",
    now: () => NOW,
    fetcher: (input, init) => {
      requestedUrl = String(input);
      authorization = new Headers(init?.headers).get("authorization") ?? "";
      return Promise.resolve(Response.json([{
        plan_type: "capy_pro_monthly",
        end_date: "2026-09-27T12:00:00.000Z",
      }]));
    },
  });

  assert.deepEqual(await store.findActiveSubscription("trusted-user-id"), {
    planType: "capy_pro_monthly",
    endDate: "2026-09-27T12:00:00.000Z",
  });
  const url = new URL(requestedUrl);
  assert.equal(url.pathname, "/rest/v1/subscriptions");
  assert.equal(url.searchParams.get("user_id"), "eq.trusted-user-id");
  assert.equal(url.searchParams.get("status"), "eq.active");
  assert.equal(url.searchParams.get("end_date"), `gt.${NOW.toISOString()}`);
  assert.equal(authorization, "Bearer service-role-test-key");
});
