export const CHAT_TRANSLATOR_VERSION = "chat-translate-v1";
export const CHAT_PROMPT_VERSION = "chat-translate-p1";
export const CHAT_TRANSLATION_MODEL = "gemini-3.5-flash-lite";
export const CHAT_PROVIDER_TIMEOUT_MS = 15_000;
export const CHAT_TRANSLATION_MAX_LENGTH = 16_000;

export type ProviderFailureCode =
  | "PROVIDER_AUTH_DENIED"
  | "PROVIDER_REQUEST_REJECTED"
  | "PROVIDER_RATE_LIMITED"
  | "PROVIDER_TIMEOUT"
  | "PROVIDER_NETWORK"
  | "PROVIDER_UNAVAILABLE"
  | "MALFORMED_RESPONSE"
  | "OUTPUT_INVALID";

export interface TranslationClaim {
  readonly translationId: string;
  readonly claimToken: string;
  readonly rawText: string;
  readonly sourceLanguageCode: "vi" | "en";
  readonly targetLanguageCode: "vi" | "en";
  readonly provider: string;
  readonly model: string;
  readonly promptVersion: string;
  readonly translatorVersion: string;
  readonly attemptCount: number;
  readonly leaseExpiresAt: string;
}

export interface TranslationQueue {
  claim(translatorVersion: string): Promise<TranslationClaim | null>;
  complete(request: {
    readonly translationId: string;
    readonly claimToken: string;
    readonly translatedText: string;
  }): Promise<void>;
  fail(request: {
    readonly translationId: string;
    readonly claimToken: string;
    readonly errorCode: ProviderFailureCode;
    readonly providerRetryAfterSeconds?: number | null;
  }): Promise<void>;
}

export interface TranslationProviderRequest {
  readonly rawText: string;
  readonly sourceLanguageCode: "vi" | "en";
  readonly targetLanguageCode: "vi" | "en";
  readonly model: string;
  readonly promptVersion: string;
  readonly translatorVersion: string;
  readonly signal: AbortSignal;
}

export interface TranslationProviderResult {
  readonly translatedText: string;
}

export interface TranslationProvider {
  translate(
    request: TranslationProviderRequest,
  ): Promise<TranslationProviderResult>;
}

export class TranslationProviderFailure extends Error {
  readonly code: ProviderFailureCode;
  readonly retryAfterSeconds: number | null;

  constructor(
    code: ProviderFailureCode,
    options?: {
      readonly retryAfterSeconds?: number | null;
      readonly cause?: unknown;
    },
  ) {
    super("Translation provider request failed", { cause: options?.cause });
    this.name = "TranslationProviderFailure";
    this.code = code;
    this.retryAfterSeconds = options?.retryAfterSeconds ?? null;
  }
}

export class TranslationQueueUnavailableError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "TranslationQueueUnavailableError";
  }
}

export type SafeLogValue = string | number | boolean | null;

export interface WorkerLogger {
  info(event: string, fields: Readonly<Record<string, SafeLogValue>>): void;
  warn(event: string, fields: Readonly<Record<string, SafeLogValue>>): void;
}

export type WorkerRunResult =
  | { readonly status: "idle" }
  | {
    readonly status: "succeeded";
    readonly translationId: string;
    readonly attemptCount: number;
  }
  | {
    readonly status: "failed";
    readonly translationId: string;
    readonly attemptCount: number;
    readonly errorCode: ProviderFailureCode;
  };
