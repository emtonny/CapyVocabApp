import {
  type ProviderFailureCode,
  type TranslationClaim,
  type TranslationQueue,
  TranslationQueueUnavailableError,
} from "./contracts.ts";

type Fetcher = typeof fetch;

export interface SupabaseTranslationQueueOptions {
  readonly supabaseUrl: string;
  readonly serviceRoleKey: string;
  readonly fetcher?: Fetcher;
  readonly requestTimeoutMs?: number;
}

const DEFAULT_QUEUE_TIMEOUT_MS = 5_000;

function requiredString(row: Record<string, unknown>, key: string): string {
  const value = row[key];
  if (typeof value !== "string" || !value) {
    throw new TranslationQueueUnavailableError(
      `Translation claim has invalid ${key}`,
    );
  }
  return value;
}

function parseLanguage(value: string, field: string): "vi" | "en" {
  if (value !== "vi" && value !== "en") {
    throw new TranslationQueueUnavailableError(
      `Translation claim has invalid ${field}`,
    );
  }
  return value;
}

export function parseTranslationClaim(value: unknown): TranslationClaim | null {
  if (!Array.isArray(value) || value.length > 1) {
    throw new TranslationQueueUnavailableError(
      "Translation claim RPC returned an invalid row count",
    );
  }
  if (value.length === 0) return null;
  if (!value[0] || typeof value[0] !== "object" || Array.isArray(value[0])) {
    throw new TranslationQueueUnavailableError(
      "Translation claim RPC returned an invalid row",
    );
  }
  const row = value[0] as Record<string, unknown>;
  const attemptCount = row.attempt_count;
  if (
    !Number.isInteger(attemptCount) || Number(attemptCount) < 1 ||
    Number(attemptCount) > 4
  ) {
    throw new TranslationQueueUnavailableError(
      "Translation claim has invalid attempt_count",
    );
  }
  const leaseExpiresAt = requiredString(row, "lease_expires_at");
  if (Number.isNaN(Date.parse(leaseExpiresAt))) {
    throw new TranslationQueueUnavailableError(
      "Translation claim has invalid lease_expires_at",
    );
  }
  const sourceLanguageCode = parseLanguage(
    requiredString(row, "source_language_code"),
    "source_language_code",
  );
  const targetLanguageCode = parseLanguage(
    requiredString(row, "target_language_code"),
    "target_language_code",
  );
  if (sourceLanguageCode === targetLanguageCode) {
    throw new TranslationQueueUnavailableError(
      "Translation claim languages must differ",
    );
  }
  return {
    translationId: requiredString(row, "translation_id"),
    claimToken: requiredString(row, "claim_token"),
    rawText: requiredString(row, "raw_text"),
    sourceLanguageCode,
    targetLanguageCode,
    provider: requiredString(row, "provider"),
    model: requiredString(row, "model"),
    promptVersion: requiredString(row, "prompt_version"),
    translatorVersion: requiredString(row, "translator_version"),
    attemptCount: Number(attemptCount),
    leaseExpiresAt,
  };
}

export function createSupabaseTranslationQueue(
  options: SupabaseTranslationQueueOptions,
): TranslationQueue {
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.requestTimeoutMs ?? DEFAULT_QUEUE_TIMEOUT_MS;
  const headers = {
    apikey: options.serviceRoleKey,
    Authorization: `Bearer ${options.serviceRoleKey}`,
    Accept: "application/json",
    "Content-Type": "application/json",
  };

  async function rpc(
    name: string,
    body: Record<string, unknown>,
  ): Promise<unknown> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetcher(`${baseUrl}/rest/v1/rpc/${name}`, {
        method: "POST",
        headers,
        signal: controller.signal,
        body: JSON.stringify(body),
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw new TranslationQueueUnavailableError(
          `Translation queue RPC ${name} failed with status ${response.status}`,
        );
      }
      return await response.json();
    } catch (error) {
      if (error instanceof TranslationQueueUnavailableError) throw error;
      throw new TranslationQueueUnavailableError(
        `Translation queue RPC ${name} is unavailable`,
        { cause: error },
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  async function requireTrue(
    name: string,
    body: Record<string, unknown>,
  ): Promise<void> {
    if (await rpc(name, body) !== true) {
      throw new TranslationQueueUnavailableError(
        `Translation queue RPC ${name} returned an invalid result`,
      );
    }
  }

  return {
    async claim(translatorVersion): Promise<TranslationClaim | null> {
      return parseTranslationClaim(
        await rpc("claim_chat_translation", {
          p_translator_version: translatorVersion,
        }),
      );
    },

    async complete(request): Promise<void> {
      await requireTrue("complete_chat_translation", {
        p_translation_id: request.translationId,
        p_claim_token: request.claimToken,
        p_translated_text: request.translatedText,
      });
    },

    async fail(request): Promise<void> {
      const errorCode: ProviderFailureCode = request.errorCode;
      await requireTrue("fail_chat_translation", {
        p_translation_id: request.translationId,
        p_claim_token: request.claimToken,
        p_error_code: errorCode,
        p_provider_retry_after_seconds: request.providerRetryAfterSeconds ??
          null,
      });
    },
  };
}
