import type {
  GeminiCircuitPermit,
  GeminiCircuitState,
  GeminiHealthStore,
  GeminiModelHealth,
  GeminiQuotaKind,
} from "./gemini_client.ts";

export const HEALTH_REQUEST_TIMEOUT_MS = 1_500;
export const HEALTH_CACHE_TTL_MS = 30_000;

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

interface GeminiModelHealthRow {
  model_name?: unknown;
  is_healthy?: unknown;
}

interface GeminiCircuitPermitRow {
  allowed?: unknown;
  circuit_state?: unknown;
  probe_token?: unknown;
  retry_after_seconds?: unknown;
}

export interface GeminiCircuitConfig {
  failureThreshold: number;
  cooldownSeconds: number;
  halfOpenLeaseSeconds: number;
}

type EnvironmentReader = (name: string) => string | undefined;

export const DEFAULT_GEMINI_CIRCUIT_CONFIG: Readonly<GeminiCircuitConfig> = {
  failureThreshold: 3,
  cooldownSeconds: 60,
  halfOpenLeaseSeconds: 45,
};

function readBoundedInteger(
  readEnv: EnvironmentReader,
  name: string,
  fallback: number,
  maximum: number,
): number {
  const raw = readEnv(name)?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new Error(`${name} must be an integer between 1 and ${maximum}`);
  }
  return value;
}

export function resolveGeminiCircuitConfig(
  readEnv: EnvironmentReader = (name) => Deno.env.get(name),
): GeminiCircuitConfig {
  return {
    failureThreshold: readBoundedInteger(
      readEnv,
      "GEMINI_CIRCUIT_FAILURE_THRESHOLD",
      DEFAULT_GEMINI_CIRCUIT_CONFIG.failureThreshold,
      100,
    ),
    cooldownSeconds: readBoundedInteger(
      readEnv,
      "GEMINI_CIRCUIT_COOLDOWN_SECONDS",
      DEFAULT_GEMINI_CIRCUIT_CONFIG.cooldownSeconds,
      86_400,
    ),
    halfOpenLeaseSeconds: readBoundedInteger(
      readEnv,
      "GEMINI_CIRCUIT_HALF_OPEN_LEASE_SECONDS",
      DEFAULT_GEMINI_CIRCUIT_CONFIG.halfOpenLeaseSeconds,
      3_600,
    ),
  };
}

export interface CachedHealthStoreOptions {
  cacheTtlMs?: number;
  now?: () => number;
}

export interface SupabaseGeminiHealthStoreOptions
  extends CachedHealthStoreOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
  fetcher?: Fetcher;
  requestTimeoutMs?: number;
  cacheTtlMs?: number;
  now?: () => number;
  circuitConfig?: GeminiCircuitConfig;
}

export function createCachedGeminiHealthStore(
  innerStore: GeminiHealthStore,
  options?: CachedHealthStoreOptions,
): GeminiHealthStore {
  const ttlMs = options?.cacheTtlMs ?? HEALTH_CACHE_TTL_MS;
  const now = options?.now ?? (() => Date.now());
  const cache = new Map<string, { isHealthy: boolean; expiresAt: number }>();

  return {
    acquireAttempt(modelName: string): Promise<GeminiCircuitPermit> {
      if (!innerStore.acquireAttempt) {
        return Promise.resolve({
          allowed: true,
          state: "healthy",
          probeToken: null,
          retryAfterSeconds: null,
        });
      }
      return innerStore.acquireAttempt(modelName);
    },

    async getModelHealth(
      modelNames: readonly string[],
    ): Promise<readonly GeminiModelHealth[]> {
      const currentTime = now();
      const allCached = modelNames.length > 0 &&
        modelNames.every((name) => {
          const entry = cache.get(name);
          return entry !== undefined && entry.expiresAt > currentTime;
        });

      if (allCached) {
        return modelNames.flatMap((name) => {
          const entry = cache.get(name);
          return entry !== undefined
            ? [{ modelName: name, isHealthy: entry.isHealthy }]
            : [];
        });
      }

      const freshHealth = await innerStore.getModelHealth(modelNames);
      for (const item of freshHealth) {
        cache.set(item.modelName, {
          isHealthy: item.isHealthy,
          expiresAt: currentTime + ttlMs,
        });
      }
      return freshHealth;
    },

    async recordSuccess(
      modelName: string,
      probeToken?: string | null,
    ): Promise<void> {
      const cached = cache.get(modelName);
      if (cached && !cached.isHealthy) {
        cache.delete(modelName);
      }
      await innerStore.recordSuccess(modelName, probeToken);
    },

    async recordSystemFailure(
      modelName: string,
      probeToken?: string | null,
    ): Promise<void> {
      cache.delete(modelName);
      await innerStore.recordSystemFailure(modelName, probeToken);
    },

    async recordQuotaError(
      modelName: string,
      quotaKind: GeminiQuotaKind,
      probeToken?: string | null,
    ): Promise<void> {
      await innerStore.recordQuotaError?.(
        modelName,
        quotaKind,
        probeToken,
      );
    },
  };
}

export function createRawSupabaseGeminiHealthStore(
  options: SupabaseGeminiHealthStoreOptions,
): GeminiHealthStore {
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.requestTimeoutMs ?? HEALTH_REQUEST_TIMEOUT_MS;
  const cacheTtlMs = options.cacheTtlMs ?? HEALTH_CACHE_TTL_MS;
  const now = options.now ?? Date.now;
  const circuitConfig = options.circuitConfig ?? resolveGeminiCircuitConfig();
  const headers = {
    apikey: options.serviceRoleKey,
    Authorization: `Bearer ${options.serviceRoleKey}`,
    "Content-Type": "application/json",
  };
  let cachedHealth:
    | { expiresAt: number; rows: readonly GeminiModelHealth[] }
    | undefined;
  let healthRequest: Promise<readonly GeminiModelHealth[]> | undefined;

  async function request(path: string, init?: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetcher(`${baseUrl}${path}`, {
        ...init,
        headers: { ...headers, ...init?.headers },
        signal: controller.signal,
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(
          `Supabase health request failed (${response.status}): ${
            body.slice(0, 300)
          }`,
        );
      }
      return response;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function recordOutcome(
    modelName: string,
    outcome: "success" | "system_failure" | "quota_error",
    probeToken: string | null,
    quotaKind: GeminiQuotaKind | null,
  ): Promise<void> {
    await request("/rest/v1/rpc/record_gemini_model_outcome", {
      method: "POST",
      body: JSON.stringify({
        p_model_name: modelName,
        p_outcome: outcome,
        p_failure_threshold: circuitConfig.failureThreshold,
        p_cooldown_seconds: circuitConfig.cooldownSeconds,
        p_probe_token: probeToken,
        p_quota_kind: quotaKind,
      }),
    });
    if (outcome === "system_failure") {
      cachedHealth = undefined;
      return;
    }
    if (outcome === "quota_error") return;
    const current = cachedHealth;
    if (!current) return;
    cachedHealth = {
      expiresAt: now() + cacheTtlMs,
      rows: [
        ...current.rows.filter((row) => row.modelName !== modelName),
        { modelName, isHealthy: true },
      ],
    };
  }

  async function acquireAttempt(
    modelName: string,
  ): Promise<GeminiCircuitPermit> {
    const response = await request(
      "/rest/v1/rpc/acquire_gemini_model_attempt",
      {
        method: "POST",
        body: JSON.stringify({
          p_model_name: modelName,
          p_half_open_lease_seconds: circuitConfig.halfOpenLeaseSeconds,
        }),
      },
    );
    const rows: unknown = await response.json();
    const candidate = Array.isArray(rows)
      ? rows[0] as GeminiCircuitPermitRow | undefined
      : undefined;
    const state = candidate?.circuit_state;
    const validState = state === "healthy" || state === "degraded" ||
      state === "open" || state === "half_open";
    const probeToken = candidate?.probe_token;
    const retryAfterSeconds = candidate?.retry_after_seconds;
    if (
      typeof candidate?.allowed !== "boolean" || !validState ||
      !(probeToken === null || typeof probeToken === "string") ||
      !(retryAfterSeconds === null ||
        (typeof retryAfterSeconds === "number" &&
          Number.isInteger(retryAfterSeconds) && retryAfterSeconds >= 0))
    ) {
      throw new Error("Supabase circuit permit response is invalid");
    }
    return {
      allowed: candidate.allowed,
      state: state as GeminiCircuitState,
      probeToken,
      retryAfterSeconds,
    };
  }

  function selectRequestedModels(
    rows: readonly GeminiModelHealth[],
    modelNames: readonly string[],
  ): readonly GeminiModelHealth[] {
    const requestedModels = new Set(modelNames);
    return rows.filter((row) => requestedModels.has(row.modelName));
  }

  async function loadHealth(): Promise<readonly GeminiModelHealth[]> {
    const response = await request(
      "/rest/v1/gemini_model_health?select=model_name,is_healthy",
    );
    const rows: unknown = await response.json();
    if (!Array.isArray(rows)) {
      throw new Error("Supabase health response is not an array");
    }
    return rows.flatMap((row) => {
      const candidate = row as GeminiModelHealthRow;
      if (
        typeof candidate.model_name !== "string" ||
        typeof candidate.is_healthy !== "boolean"
      ) {
        return [];
      }
      return [{
        modelName: candidate.model_name,
        isHealthy: candidate.is_healthy,
      }];
    });
  }

  return {
    acquireAttempt,

    async getModelHealth(
      modelNames: readonly string[],
    ): Promise<readonly GeminiModelHealth[]> {
      const current = cachedHealth;
      if (current && current.expiresAt > now()) {
        return selectRequestedModels(current.rows, modelNames);
      }

      healthRequest ??= loadHealth();
      try {
        const rows = await healthRequest;
        cachedHealth = { expiresAt: now() + cacheTtlMs, rows };
        return selectRequestedModels(rows, modelNames);
      } finally {
        healthRequest = undefined;
      }
    },

    recordSuccess(
      modelName: string,
      probeToken?: string | null,
    ): Promise<void> {
      return recordOutcome(modelName, "success", probeToken ?? null, null);
    },

    recordSystemFailure(
      modelName: string,
      probeToken?: string | null,
    ): Promise<void> {
      return recordOutcome(
        modelName,
        "system_failure",
        probeToken ?? null,
        null,
      );
    },

    recordQuotaError(
      modelName: string,
      quotaKind: GeminiQuotaKind,
      probeToken?: string | null,
    ): Promise<void> {
      return recordOutcome(
        modelName,
        "quota_error",
        probeToken ?? null,
        quotaKind,
      );
    },
  };
}

export function createSupabaseGeminiHealthStore(
  options: SupabaseGeminiHealthStoreOptions,
): GeminiHealthStore {
  const rawStore = createRawSupabaseGeminiHealthStore(options);
  return createCachedGeminiHealthStore(rawStore, {
    cacheTtlMs: options.cacheTtlMs ?? HEALTH_CACHE_TTL_MS,
    now: options.now,
  });
}
