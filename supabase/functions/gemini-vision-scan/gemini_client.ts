import {
  type GeminiModelPolicy,
  shouldFallbackModelFailure,
  shouldRetryModelFailure,
} from "./model_policy.ts";

const DEFAULT_GEMINI_API_BASE_URL =
  "https://generativelanguage.googleapis.com/v1beta/models";
const GEMINI_RETRY_DELAY_MS = 750;
const GEMINI_RETRY_JITTER_MS = 250;
const MAX_RETRY_AFTER_MS = 5_000;
const MAX_UPSTREAM_ATTEMPTS = 2;
const GEMINI_ATTEMPT_TIMEOUT_MS = 35_000;
const MODEL_HEALTH_FAILURE_STATUSES = new Set([500, 502, 503, 504]);

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type Logger = Pick<Console, "warn" | "error">;

export type GeminiFailureKind = "timeout" | "network";
export type GeminiCircuitState =
  | "healthy"
  | "degraded"
  | "open"
  | "half_open";
export type GeminiQuotaKind = "rpm" | "tpm" | "rpd" | "unknown";

export interface GeminiCircuitPermit {
  allowed: boolean;
  state: GeminiCircuitState;
  probeToken: string | null;
  retryAfterSeconds: number | null;
}

export class GeminiChainError extends Error {
  readonly kind: GeminiFailureKind;
  readonly model: string;
  readonly modelsTried: number;
  readonly upstreamAttempts: number;

  constructor(
    kind: GeminiFailureKind,
    model: string,
    modelsTried: number,
    upstreamAttempts: number,
    cause: unknown,
  ) {
    super(
      kind === "timeout"
        ? "All Gemini models timed out"
        : "All Gemini models failed with a network error",
      { cause },
    );
    this.name = "GeminiChainError";
    this.kind = kind;
    this.model = model;
    this.modelsTried = modelsTried;
    this.upstreamAttempts = upstreamAttempts;
  }
}

export class GeminiCircuitOpenError extends Error {
  readonly model: string;
  readonly modelsTried: number;
  readonly upstreamAttempts: number;
  readonly retryAfterSeconds: number | null;

  constructor(
    model: string,
    modelsTried: number,
    upstreamAttempts: number,
    retryAfterSeconds: number | null,
  ) {
    super(`Gemini circuit is open for ${model}`);
    this.name = "GeminiCircuitOpenError";
    this.model = model;
    this.modelsTried = modelsTried;
    this.upstreamAttempts = upstreamAttempts;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export interface GeminiChainResult {
  response: Response;
  model: string;
  modelsTried: number;
  attemptsForModel: number;
  upstreamAttempts: number;
  quotaKind: GeminiQuotaKind | null;
}

export interface GeminiModelHealth {
  modelName: string;
  isHealthy: boolean;
}

export interface GeminiHealthStore {
  getModelHealth(
    modelNames: readonly string[],
  ): Promise<readonly GeminiModelHealth[]>;
  acquireAttempt?: (modelName: string) => Promise<GeminiCircuitPermit>;
  recordSuccess(modelName: string, probeToken?: string | null): Promise<void>;
  recordSystemFailure(
    modelName: string,
    probeToken?: string | null,
  ): Promise<void>;
  recordQuotaError?: (
    modelName: string,
    quotaKind: GeminiQuotaKind,
    probeToken?: string | null,
  ) => Promise<void>;
}

interface GeminiChainOptions {
  apiKey: string;
  scanId: string;
  modelPolicy: GeminiModelPolicy;
  createRequestBody: (model: string) => unknown;
  fetcher?: Fetcher;
  sleep?: (delayMs: number) => Promise<void>;
  random?: () => number;
  attemptTimeoutMs?: number;
  logger?: Logger;
  healthStore?: GeminiHealthStore;
  scheduleBackgroundTask?: (task: Promise<void>) => void;
  apiBaseUrl?: string;
}

interface GeminiAttemptOptions {
  apiKey: string;
  model: string;
  requestBody: unknown;
  fetcher: Fetcher;
  timeoutMs: number;
  apiBaseUrl?: string;
}

interface GeminiAttemptResult {
  response: Response;
}

class GeminiAttemptError extends Error {
  readonly kind: GeminiFailureKind;

  constructor(kind: GeminiFailureKind, cause: unknown) {
    super(
      kind === "timeout" ? "Gemini request timed out" : "Gemini network error",
      {
        cause,
      },
    );
    this.name = "GeminiAttemptError";
    this.kind = kind;
  }
}

export function buildGenerationConfig(model: string, responseSchema: unknown) {
  const commonConfig = {
    responseMimeType: "application/json",
    responseSchema,
    maxOutputTokens: 8192,
  };

  if (model.startsWith("gemini-2.5-")) {
    return {
      ...commonConfig,
      temperature: 0.2,
      thinkingConfig: { thinkingBudget: 0 },
    };
  }

  return {
    ...commonConfig,
    thinkingConfig: { thinkingLevel: "low" },
  };
}

export async function fetchGemini(
  options: GeminiAttemptOptions,
): Promise<GeminiAttemptResult> {
  const controller = new AbortController();
  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, options.timeoutMs);

  try {
    const apiBaseUrl = options.apiBaseUrl ?? DEFAULT_GEMINI_API_BASE_URL;
    const endpoint = `${apiBaseUrl.replace(/\/+$/, "")}/${
      encodeURIComponent(options.model)
    }:generateContent?key=${encodeURIComponent(options.apiKey)}`;
    const response = await options.fetcher(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify(options.requestBody),
    });
    return { response };
  } catch (error) {
    throw new GeminiAttemptError(timedOut ? "timeout" : "network", error);
  } finally {
    clearTimeout(timeout);
  }
}

async function recordAttemptHealth(
  healthStore: GeminiHealthStore | undefined,
  logger: Logger,
  scanId: string,
  model: string,
  outcome: "success" | "system_failure" | "quota_error",
  probeToken: string | null,
  quotaKind: GeminiQuotaKind | null,
): Promise<void> {
  if (!healthStore) return;

  try {
    if (outcome === "success") {
      await healthStore.recordSuccess(model, probeToken);
    } else if (outcome === "system_failure") {
      await healthStore.recordSystemFailure(model, probeToken);
    } else if (healthStore.recordQuotaError) {
      await healthStore.recordQuotaError(
        model,
        quotaKind ?? "unknown",
        probeToken,
      );
    }
  } catch (error) {
    logger.warn(
      "Gemini health write failed; continuing scan",
      JSON.stringify({
        scanId,
        model,
        outcome,
        quotaKind,
        error: String(error),
      }),
    );
  }
}

async function dispatchAttemptHealth(
  healthStore: GeminiHealthStore | undefined,
  logger: Logger,
  scanId: string,
  model: string,
  outcome: "success" | "system_failure" | "quota_error",
  probeToken: string | null,
  quotaKind: GeminiQuotaKind | null,
  scheduleBackgroundTask: ((task: Promise<void>) => void) | undefined,
  awaitWrite = false,
): Promise<void> {
  const task = recordAttemptHealth(
    healthStore,
    logger,
    scanId,
    model,
    outcome,
    probeToken,
    quotaKind,
  );
  if (scheduleBackgroundTask && !awaitWrite) {
    scheduleBackgroundTask(task);
    return;
  }
  await task;
}

async function acquireCircuitPermit(
  healthStore: GeminiHealthStore | undefined,
  logger: Logger,
  scanId: string,
  model: string,
): Promise<GeminiCircuitPermit> {
  if (!healthStore?.acquireAttempt) {
    return {
      allowed: true,
      state: "healthy",
      probeToken: null,
      retryAfterSeconds: null,
    };
  }

  try {
    return await healthStore.acquireAttempt(model);
  } catch (error) {
    logger.warn(
      "Gemini circuit read failed; continuing with configured policy",
      JSON.stringify({ scanId, model, error: String(error) }),
    );
    return {
      allowed: true,
      state: "healthy",
      probeToken: null,
      retryAfterSeconds: null,
    };
  }
}

function readRetryAfterMs(response: Response): number | null {
  const value = response.headers.get("retry-after")?.trim();
  if (!value) return null;

  const seconds = Number(value);
  const delayMs = Number.isFinite(seconds)
    ? Math.ceil(seconds * 1_000)
    : Date.parse(value) - Date.now();
  return Number.isFinite(delayMs) && delayMs >= 0 &&
      delayMs <= MAX_RETRY_AFTER_MS
    ? delayMs
    : null;
}

export async function classifyGeminiQuotaError(
  response: Response,
): Promise<GeminiQuotaKind> {
  if (response.status !== 429) return "unknown";

  let body: string;
  try {
    body = (await response.clone().text()).toLowerCase();
  } catch {
    return "unknown";
  }

  if (
    /tokens?[_ -]?per[_ -]?minute|tokensperminute|inputtokenspermodelperminute|\btpm\b/
      .test(body)
  ) {
    return "tpm";
  }
  if (
    /requests?[_ -]?per[_ -]?day|requestsperday|perdayperprojectpermodel|\brpd\b/
      .test(body)
  ) {
    return "rpd";
  }
  if (
    /requests?[_ -]?per[_ -]?minute|requestsperminute|perminuteperprojectpermodel|\brpm\b/
      .test(body)
  ) {
    return "rpm";
  }
  return "unknown";
}

export async function fetchGeminiModelChain(
  options: GeminiChainOptions,
): Promise<GeminiChainResult> {
  const fetcher = options.fetcher ?? fetch;
  const sleep = options.sleep ??
    ((delayMs: number) =>
      new Promise((resolve) => setTimeout(resolve, delayMs)));
  const timeoutMs = options.attemptTimeoutMs ?? GEMINI_ATTEMPT_TIMEOUT_MS;
  const logger = options.logger ?? console;
  const random = options.random ?? Math.random;
  const retryDelayMs = () =>
    GEMINI_RETRY_DELAY_MS +
    Math.floor(Math.max(0, Math.min(1, random())) * GEMINI_RETRY_JITTER_MS);
  let lastAttemptError: GeminiAttemptError | undefined;
  let upstreamAttempts = 0;
  const orderedModelChain = [
    options.modelPolicy.primaryModel,
    ...(options.modelPolicy.fallbackModel
      ? [options.modelPolicy.fallbackModel]
      : []),
  ];

  for (
    let modelIndex = 0;
    modelIndex < orderedModelChain.length;
    modelIndex += 1
  ) {
    const model = orderedModelChain[modelIndex];
    const modelsTried = modelIndex + 1;
    const isLastModel = modelsTried === orderedModelChain.length;
    const circuitPermit = await acquireCircuitPermit(
      options.healthStore,
      logger,
      options.scanId,
      model,
    );
    if (!circuitPermit.allowed) {
      logger.warn(
        "Gemini circuit open",
        JSON.stringify({
          scanId: options.scanId,
          model,
          state: circuitPermit.state,
          retryAfterSeconds: circuitPermit.retryAfterSeconds,
          nextModel: isLastModel ? null : orderedModelChain[modelIndex + 1],
        }),
      );
      if (!isLastModel) continue;
      throw new GeminiCircuitOpenError(
        model,
        modelsTried,
        upstreamAttempts,
        circuitPermit.retryAfterSeconds,
      );
    }

    let attemptsForModel = 0;
    while (upstreamAttempts < MAX_UPSTREAM_ATTEMPTS) {
      attemptsForModel += 1;
      upstreamAttempts += 1;
      try {
        const { response } = await fetchGemini({
          apiKey: options.apiKey,
          model,
          requestBody: options.createRequestBody(model),
          fetcher,
          timeoutMs,
          apiBaseUrl: options.apiBaseUrl ?? DEFAULT_GEMINI_API_BASE_URL,
        });

        const quotaKind = response.status === 429
          ? await classifyGeminiQuotaError(response)
          : null;
        if (response.ok) {
          await dispatchAttemptHealth(
            options.healthStore,
            logger,
            options.scanId,
            model,
            "success",
            circuitPermit.probeToken,
            null,
            options.scheduleBackgroundTask,
          );
        } else if (MODEL_HEALTH_FAILURE_STATUSES.has(response.status)) {
          await dispatchAttemptHealth(
            options.healthStore,
            logger,
            options.scanId,
            model,
            "system_failure",
            circuitPermit.probeToken,
            null,
            options.scheduleBackgroundTask,
            true,
          );
        } else if (response.status === 429) {
          await dispatchAttemptHealth(
            options.healthStore,
            logger,
            options.scanId,
            model,
            "quota_error",
            circuitPermit.probeToken,
            quotaKind,
            options.scheduleBackgroundTask,
          );
        }

        const responseFailure = { status: response.status };
        const retryAfterMs = response.status === 429
          ? readRetryAfterMs(response)
          : null;
        if (
          !response.ok && retryAfterMs !== null &&
          upstreamAttempts < MAX_UPSTREAM_ATTEMPTS
        ) {
          await response.body?.cancel();
          logger.warn(
            "Gemini model retry",
            JSON.stringify({
              scanId: options.scanId,
              model,
              status: response.status,
              failedAttempt: attemptsForModel,
              nextAttempt: attemptsForModel + 1,
              delayMs: retryAfterMs,
            }),
          );
          await sleep(retryAfterMs);
          continue;
        }

        if (
          !isLastModel &&
          shouldFallbackModelFailure(options.modelPolicy, responseFailure) &&
          upstreamAttempts < MAX_UPSTREAM_ATTEMPTS
        ) {
          await response.body?.cancel();
          logger.warn(
            "Gemini model fallback",
            JSON.stringify({
              scanId: options.scanId,
              model,
              status: response.status,
              attemptsForModel,
              nextModel: orderedModelChain[modelIndex + 1],
            }),
          );
          break;
        }

        if (
          isLastModel && modelIndex === 0 &&
          shouldRetryModelFailure(responseFailure) &&
          upstreamAttempts < MAX_UPSTREAM_ATTEMPTS
        ) {
          await response.body?.cancel();
          const delayMs = retryDelayMs();
          logger.warn(
            "Gemini model retry",
            JSON.stringify({
              scanId: options.scanId,
              model,
              status: response.status,
              failedAttempt: attemptsForModel,
              nextAttempt: attemptsForModel + 1,
              delayMs,
            }),
          );
          await sleep(delayMs);
          continue;
        }

        return {
          response,
          model,
          modelsTried,
          attemptsForModel,
          upstreamAttempts,
          quotaKind,
        };
      } catch (error) {
        if (!(error instanceof GeminiAttemptError)) throw error;
        lastAttemptError = error;
        await dispatchAttemptHealth(
          options.healthStore,
          logger,
          options.scanId,
          model,
          "system_failure",
          circuitPermit.probeToken,
          null,
          options.scheduleBackgroundTask,
          true,
        );
        if (
          !isLastModel &&
          shouldFallbackModelFailure(options.modelPolicy, {
            kind: error.kind,
          }) && upstreamAttempts < MAX_UPSTREAM_ATTEMPTS
        ) {
          logger.warn(
            "Gemini model fallback",
            JSON.stringify({
              scanId: options.scanId,
              model,
              failureKind: error.kind,
              attemptsForModel,
              nextModel: orderedModelChain[modelIndex + 1],
            }),
          );
          break;
        }
        if (
          isLastModel && modelIndex === 0 &&
          shouldRetryModelFailure({ kind: error.kind }) &&
          upstreamAttempts < MAX_UPSTREAM_ATTEMPTS
        ) {
          const delayMs = retryDelayMs();
          logger.warn(
            "Gemini model retry",
            JSON.stringify({
              scanId: options.scanId,
              model,
              failureKind: error.kind,
              failedAttempt: attemptsForModel,
              nextAttempt: attemptsForModel + 1,
              delayMs,
            }),
          );
          await sleep(delayMs);
          continue;
        }
        logger.warn(
          "Gemini model fallback",
          JSON.stringify({
            scanId: options.scanId,
            model,
            failureKind: error.kind,
            attemptsForModel,
            nextModel: isLastModel ? null : orderedModelChain[modelIndex + 1],
          }),
        );
        break;
      }
    }
  }

  const finalModel = orderedModelChain[orderedModelChain.length - 1];
  throw new GeminiChainError(
    lastAttemptError?.kind ?? "network",
    finalModel,
    orderedModelChain.length,
    upstreamAttempts,
    lastAttemptError,
  );
}
