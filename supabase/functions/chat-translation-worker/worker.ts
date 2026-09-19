import {
  CHAT_PROVIDER_TIMEOUT_MS,
  CHAT_TRANSLATION_MAX_LENGTH,
  CHAT_TRANSLATOR_VERSION,
  type ProviderFailureCode,
  type TranslationProvider,
  TranslationProviderFailure,
  type TranslationQueue,
  TranslationQueueUnavailableError,
  type WorkerLogger,
  type WorkerRunResult,
} from "./contracts.ts";

const NOOP_LOGGER: WorkerLogger = {
  info: () => {},
  warn: () => {},
};

export interface RunTranslationWorkerOptions {
  readonly queue: TranslationQueue;
  readonly provider: TranslationProvider;
  readonly logger?: WorkerLogger;
  readonly translatorVersion?: string;
  readonly providerTimeoutMs?: number;
  readonly now?: () => number;
  readonly signal?: AbortSignal;
}

function isValidOutput(value: unknown): value is string {
  if (typeof value !== "string" || !/\S/u.test(value)) return false;
  const characterLength = Array.from(value).length;
  return characterLength >= 1 &&
    characterLength <= CHAT_TRANSLATION_MAX_LENGTH;
}

function providerFailure(
  error: unknown,
  timedOut: boolean,
): { code: ProviderFailureCode; retryAfterSeconds: number | null } {
  if (timedOut) {
    return { code: "PROVIDER_TIMEOUT", retryAfterSeconds: null };
  }
  if (error instanceof TranslationProviderFailure) {
    return { code: error.code, retryAfterSeconds: error.retryAfterSeconds };
  }
  return { code: "PROVIDER_NETWORK", retryAfterSeconds: null };
}

export async function runTranslationWorker(
  options: RunTranslationWorkerOptions,
): Promise<WorkerRunResult> {
  const logger = options.logger ?? NOOP_LOGGER;
  const now = options.now ?? Date.now;
  const translatorVersion = options.translatorVersion ??
    CHAT_TRANSLATOR_VERSION;
  const timeoutMs = options.providerTimeoutMs ?? CHAT_PROVIDER_TIMEOUT_MS;
  const claim = await options.queue.claim(translatorVersion);
  if (!claim) {
    logger.info("chat_translation_idle", { translatorVersion });
    return { status: "idle" };
  }
  const leaseExpiresAt = Date.parse(claim.leaseExpiresAt);
  if (
    claim.translatorVersion !== translatorVersion ||
    !Number.isFinite(leaseExpiresAt) ||
    leaseExpiresAt <= now()
  ) {
    throw new TranslationQueueUnavailableError(
      "Translation claim policy or lease is invalid",
    );
  }

  const startedAt = now();
  logger.info("chat_translation_claimed", {
    translationId: claim.translationId,
    attemptCount: claim.attemptCount,
    sourceLanguageCode: claim.sourceLanguageCode,
    targetLanguageCode: claim.targetLanguageCode,
    translatorVersion: claim.translatorVersion,
    promptVersion: claim.promptVersion,
    model: claim.model,
  });

  const controller = new AbortController();
  let timedOut = false;
  const abortFromCaller = () => controller.abort(options.signal?.reason);
  if (options.signal?.aborted) abortFromCaller();
  else {options.signal?.addEventListener("abort", abortFromCaller, {
      once: true,
    });}
  const timeout = setTimeout(() => {
    timedOut = true;
    controller.abort(new DOMException("Provider timeout", "TimeoutError"));
  }, timeoutMs);

  try {
    let result;
    try {
      result = await options.provider.translate({
        rawText: claim.rawText,
        sourceLanguageCode: claim.sourceLanguageCode,
        targetLanguageCode: claim.targetLanguageCode,
        model: claim.model,
        promptVersion: claim.promptVersion,
        translatorVersion: claim.translatorVersion,
        signal: controller.signal,
      });
    } catch (error) {
      const failure = providerFailure(error, timedOut);
      await options.queue.fail({
        translationId: claim.translationId,
        claimToken: claim.claimToken,
        errorCode: failure.code,
        providerRetryAfterSeconds: failure.retryAfterSeconds,
      });
      logger.warn("chat_translation_failed", {
        translationId: claim.translationId,
        attemptCount: claim.attemptCount,
        errorCode: failure.code,
        latencyMs: Math.max(0, Math.round(now() - startedAt)),
      });
      return {
        status: "failed",
        translationId: claim.translationId,
        attemptCount: claim.attemptCount,
        errorCode: failure.code,
      };
    }

    if (!isValidOutput(result?.translatedText)) {
      await options.queue.fail({
        translationId: claim.translationId,
        claimToken: claim.claimToken,
        errorCode: "OUTPUT_INVALID",
        providerRetryAfterSeconds: null,
      });
      logger.warn("chat_translation_failed", {
        translationId: claim.translationId,
        attemptCount: claim.attemptCount,
        errorCode: "OUTPUT_INVALID",
        latencyMs: Math.max(0, Math.round(now() - startedAt)),
      });
      return {
        status: "failed",
        translationId: claim.translationId,
        attemptCount: claim.attemptCount,
        errorCode: "OUTPUT_INVALID",
      };
    }

    // If this write returns an ambiguous error, do not call fail: the database
    // may already have committed success. Lease recovery resolves the state.
    await options.queue.complete({
      translationId: claim.translationId,
      claimToken: claim.claimToken,
      translatedText: result.translatedText,
    });
    logger.info("chat_translation_succeeded", {
      translationId: claim.translationId,
      attemptCount: claim.attemptCount,
      latencyMs: Math.max(0, Math.round(now() - startedAt)),
    });
    return {
      status: "succeeded",
      translationId: claim.translationId,
      attemptCount: claim.attemptCount,
    };
  } finally {
    clearTimeout(timeout);
    options.signal?.removeEventListener("abort", abortFromCaller);
  }
}
