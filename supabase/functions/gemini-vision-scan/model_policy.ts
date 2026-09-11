import type { EntitlementTier } from "../_shared/entitlements.ts";

export const DEFAULT_GEMINI_MODELS = {
  free: "gemini-3.5-flash-lite",
  pro: "gemini-3.7-flash",
  proFallback: "gemini-3.6-flash",
} as const;

export interface GeminiModelPolicy {
  readonly tier: EntitlementTier;
  readonly primaryModel: string;
  readonly fallbackModel: string | null;
}

export type GeminiModelFailure =
  | { readonly status: number }
  | { readonly kind: "network" | "timeout" };

type EnvironmentReader = (name: string) => string | undefined;

const PRO_FALLBACK_STATUSES = new Set([500, 502, 503, 504]);

function readModel(
  readEnv: EnvironmentReader,
  name: string,
  fallback: string,
): string {
  return readEnv(name)?.trim() || fallback;
}

export function resolveModelPolicy(
  tier: EntitlementTier,
  readEnv: EnvironmentReader = (name) => Deno.env.get(name),
): GeminiModelPolicy {
  if (tier === "free") {
    return {
      tier,
      primaryModel: readModel(
        readEnv,
        "GEMINI_FREE_MODEL",
        DEFAULT_GEMINI_MODELS.free,
      ),
      fallbackModel: null,
    };
  }

  return {
    tier,
    primaryModel: readModel(
      readEnv,
      "GEMINI_PRO_MODEL",
      DEFAULT_GEMINI_MODELS.pro,
    ),
    fallbackModel: readModel(
      readEnv,
      "GEMINI_PRO_FALLBACK_MODEL",
      DEFAULT_GEMINI_MODELS.proFallback,
    ),
  };
}

export function shouldFallbackModelFailure(
  policy: GeminiModelPolicy,
  failure: GeminiModelFailure,
): boolean {
  if (!policy.fallbackModel) return false;
  return "status" in failure
    ? PRO_FALLBACK_STATUSES.has(failure.status)
    : failure.kind === "network" || failure.kind === "timeout";
}

export function shouldRetryModelFailure(
  failure: GeminiModelFailure,
): boolean {
  return "status" in failure
    ? failure.status === 503
    : failure.kind === "network" || failure.kind === "timeout";
}
