import type { GeminiHealthStore, GeminiModelHealth } from "./gemini_client.ts";

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
}

export function createCachedGeminiHealthStore(
  innerStore: GeminiHealthStore,
  options?: CachedHealthStoreOptions,
): GeminiHealthStore {
  const ttlMs = options?.cacheTtlMs ?? HEALTH_CACHE_TTL_MS;
  const now = options?.now ?? (() => Date.now());
  const cache = new Map<string, { isHealthy: boolean; expiresAt: number }>();

  return {
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

    async recordSuccess(modelName: string): Promise<void> {
      const cached = cache.get(modelName);
      if (cached && !cached.isHealthy) {
        cache.delete(modelName);
      }
      await innerStore.recordSuccess(modelName);
    },

    async recordSystemFailure(modelName: string): Promise<void> {
      cache.delete(modelName);
      await innerStore.recordSystemFailure(modelName);
    },
  };
}

export function createRawSupabaseGeminiHealthStore(
  options: SupabaseGeminiHealthStoreOptions,
): GeminiHealthStore {
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.requestTimeoutMs ?? HEALTH_REQUEST_TIMEOUT_MS;
  const headers = {
    apikey: options.serviceRoleKey,
    Authorization: `Bearer ${options.serviceRoleKey}`,
    "Content-Type": "application/json",
  };

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
    outcome: "success" | "system_failure",
  ): Promise<void> {
    await request("/rest/v1/rpc/record_gemini_model_health", {
      method: "POST",
      body: JSON.stringify({
        p_model_name: modelName,
        p_outcome: outcome,
      }),
    });
  }

  return {
    async getModelHealth(
      modelNames: readonly string[],
    ): Promise<readonly GeminiModelHealth[]> {
      const response = await request(
        "/rest/v1/gemini_model_health?select=model_name,is_healthy",
      );
      const rows: unknown = await response.json();
      if (!Array.isArray(rows)) {
        throw new Error("Supabase health response is not an array");
      }

      const requestedModels = new Set(modelNames);
      return rows.flatMap((row) => {
        const candidate = row as GeminiModelHealthRow;
        if (
          typeof candidate.model_name !== "string" ||
          typeof candidate.is_healthy !== "boolean" ||
          !requestedModels.has(candidate.model_name)
        ) {
          return [];
        }
        return [{
          modelName: candidate.model_name,
          isHealthy: candidate.is_healthy,
        }];
      });
    },

    recordSuccess(modelName: string): Promise<void> {
      return recordOutcome(modelName, "success");
    },

    recordSystemFailure(modelName: string): Promise<void> {
      return recordOutcome(modelName, "system_failure");
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
