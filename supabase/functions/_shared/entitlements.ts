export const APP_CAPABILITIES = {
  aiScanBasic: "ai_scan_basic",
  aiScanAdvanced: "ai_scan_advanced",
  unlimitedScan: "unlimited_scan",
  advancedStatistics: "advanced_statistics",
  premiumGames: "premium_games",
  cloudBackup: "cloud_backup",
  priorityProcessing: "priority_processing",
} as const;

export type Capability =
  (typeof APP_CAPABILITIES)[keyof typeof APP_CAPABILITIES];
export type EntitlementTier = "free" | "pro";

export interface Entitlements {
  readonly userId: string;
  readonly tier: EntitlementTier;
  readonly capabilities: ReadonlySet<Capability>;
  readonly subscriptionEndDate: string | null;
}

export interface ActiveSubscription {
  readonly planType: string;
  readonly endDate: string;
}

export interface EntitlementStore {
  findActiveSubscription(userId: string): Promise<ActiveSubscription | null>;
}

export interface SupabaseEntitlementStoreOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
  fetcher?: typeof fetch;
  requestTimeoutMs?: number;
  now?: () => Date;
}

export class EntitlementResolutionError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "EntitlementResolutionError";
  }
}

export class CapabilityDeniedError extends Error {
  readonly capability: Capability;

  constructor(capability: Capability) {
    super(`Capability is required: ${capability}`);
    this.name = "CapabilityDeniedError";
    this.capability = capability;
  }
}

const ENTITLEMENT_REQUEST_TIMEOUT_MS = 1_500;
const SUPPORTED_PRO_PLAN_TYPES = new Set(["capy_pro_monthly"]);
const CAPABILITIES_BY_TIER: Readonly<
  Record<EntitlementTier, ReadonlySet<Capability>>
> = {
  free: new Set([APP_CAPABILITIES.aiScanBasic]),
  pro: new Set([
    APP_CAPABILITIES.aiScanBasic,
    APP_CAPABILITIES.aiScanAdvanced,
  ]),
};

function validateUserId(userId: string): void {
  if (!userId.trim()) {
    throw new EntitlementResolutionError("Authenticated user id is empty");
  }
}

function isSupportedProSubscription(
  subscription: ActiveSubscription,
  now: Date,
): boolean {
  const endTime = Date.parse(subscription.endDate);
  return SUPPORTED_PRO_PLAN_TYPES.has(subscription.planType) &&
    Number.isFinite(endTime) && endTime > now.getTime();
}

export async function resolveEntitlements(
  userId: string,
  store: EntitlementStore,
  now: Date = new Date(),
): Promise<Entitlements> {
  validateUserId(userId);

  let subscription: ActiveSubscription | null;
  try {
    subscription = await store.findActiveSubscription(userId);
  } catch (error) {
    throw new EntitlementResolutionError(
      "Unable to resolve subscription entitlement",
      { cause: error },
    );
  }

  const tier: EntitlementTier = subscription &&
      isSupportedProSubscription(subscription, now)
    ? "pro"
    : "free";

  return {
    userId,
    tier,
    capabilities: CAPABILITIES_BY_TIER[tier],
    subscriptionEndDate: tier === "pro" ? subscription!.endDate : null,
  };
}

export async function hasCapability(
  userId: string,
  capability: Capability,
  store: EntitlementStore,
  now: Date = new Date(),
): Promise<boolean> {
  const entitlements = await resolveEntitlements(userId, store, now);
  return entitlements.capabilities.has(capability);
}

export async function requireCapability(
  userId: string,
  capability: Capability,
  store: EntitlementStore,
  now: Date = new Date(),
): Promise<Entitlements> {
  const entitlements = await resolveEntitlements(userId, store, now);
  if (!entitlements.capabilities.has(capability)) {
    throw new CapabilityDeniedError(capability);
  }
  return entitlements;
}

export function createSupabaseEntitlementStore(
  options: SupabaseEntitlementStoreOptions,
): EntitlementStore {
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.requestTimeoutMs ??
    ENTITLEMENT_REQUEST_TIMEOUT_MS;
  const now = options.now ?? (() => new Date());

  return {
    async findActiveSubscription(
      userId: string,
    ): Promise<ActiveSubscription | null> {
      validateUserId(userId);
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      const query = new URLSearchParams({
        select: "plan_type,end_date",
        user_id: `eq.${userId}`,
        status: "eq.active",
        end_date: `gt.${now().toISOString()}`,
        order: "end_date.desc",
        limit: "1",
      });

      try {
        const response = await fetcher(
          `${baseUrl}/rest/v1/subscriptions?${query}`,
          {
            headers: {
              apikey: options.serviceRoleKey,
              Authorization: `Bearer ${options.serviceRoleKey}`,
              Accept: "application/json",
            },
            signal: controller.signal,
          },
        );
        if (!response.ok) {
          const body = await response.text();
          throw new Error(
            `Subscription query failed (${response.status}): ${
              body.slice(0, 200)
            }`,
          );
        }

        const rows: unknown = await response.json();
        if (!Array.isArray(rows)) {
          throw new Error("Subscription query returned a non-array response");
        }
        if (rows.length === 0) return null;

        const row = rows[0] as Record<string, unknown>;
        if (
          typeof row.plan_type !== "string" ||
          typeof row.end_date !== "string"
        ) {
          throw new Error("Subscription query returned an invalid row");
        }
        return { planType: row.plan_type, endDate: row.end_date };
      } catch (error) {
        throw new EntitlementResolutionError(
          "Subscription database is unavailable",
          { cause: error },
        );
      } finally {
        clearTimeout(timeout);
      }
    },
  };
}
