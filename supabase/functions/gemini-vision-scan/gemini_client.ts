export const MODEL_CHAIN = [
  "gemini-3.5-flash-lite",
  "gemini-3.6-flash",
] as const;

const GEMINI_API_BASE_URL =
  "https://generativelanguage.googleapis.com/v1beta/models";
const GEMINI_503_RETRY_DELAY_MS = 750;
const GEMINI_ATTEMPT_TIMEOUT_MS = 35_000;
const MODEL_FAILOVER_STATUSES = new Set([404, 429, 500, 502, 503, 504]);
const MODEL_HEALTH_FAILURE_STATUSES = new Set([500, 502, 503, 504]);

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type Logger = Pick<Console, "warn" | "error">;

export type GeminiFailureKind = "timeout" | "network";

export class GeminiChainError extends Error {
  readonly kind: GeminiFailureKind;
  readonly model: string;
  readonly modelsTried: number;

  constructor(
    kind: GeminiFailureKind,
    model: string,
    modelsTried: number,
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
  }
}

export interface GeminiChainResult {
  response: Response;
  model: string;
  modelsTried: number;
  attemptsForModel: number;
}

export interface GeminiModelHealth {
  modelName: string;
  isHealthy: boolean;
}

export interface GeminiHealthStore {
  getModelHealth(
    modelNames: readonly string[],
  ): Promise<readonly GeminiModelHealth[]>;
  recordSuccess(modelName: string): Promise<void>;
  recordSystemFailure(modelName: string): Promise<void>;
}

interface GeminiChainOptions {
  apiKey: string;
  scanId: string;
  createRequestBody: (model: string) => unknown;
  fetcher?: Fetcher;
  sleep?: (delayMs: number) => Promise<void>;
  attemptTimeoutMs?: number;
  logger?: Logger;
  healthStore?: GeminiHealthStore;
}

interface GeminiAttemptOptions {
  apiKey: string;
  model: string;
  requestBody: unknown;
  fetcher: Fetcher;
  timeoutMs: number;
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
    const endpoint = `${GEMINI_API_BASE_URL}/${
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

async function loadOrderedModelChain(
  healthStore: GeminiHealthStore | undefined,
  logger: Logger,
  scanId: string,
): Promise<string[]> {
  const defaultChain = [...MODEL_CHAIN];
  if (!healthStore) return defaultChain;

  try {
    const rows = await healthStore.getModelHealth(defaultChain);
    const healthByModel = new Map(
      rows.map((row) => [row.modelName, row.isHealthy]),
    );

    // Modern JS sorting is stable. Models with the same/unknown health retain
    // their configured priority in MODEL_CHAIN.
    return defaultChain.sort((first, second) =>
      Number(healthByModel.get(first) === false) -
      Number(healthByModel.get(second) === false)
    );
  } catch (error) {
    logger.warn(
      "Gemini health read failed; using default model chain",
      JSON.stringify({ scanId, error: String(error) }),
    );
    return defaultChain;
  }
}

async function recordAttemptHealth(
  healthStore: GeminiHealthStore | undefined,
  logger: Logger,
  scanId: string,
  model: string,
  outcome: "success" | "system_failure",
): Promise<void> {
  if (!healthStore) return;

  try {
    if (outcome === "success") {
      await healthStore.recordSuccess(model);
    } else {
      await healthStore.recordSystemFailure(model);
    }
  } catch (error) {
    logger.warn(
      "Gemini health write failed; continuing scan",
      JSON.stringify({ scanId, model, outcome, error: String(error) }),
    );
  }
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
  let lastAttemptError: GeminiAttemptError | undefined;
  const orderedModelChain = await loadOrderedModelChain(
    options.healthStore,
    logger,
    options.scanId,
  );

  for (
    let modelIndex = 0;
    modelIndex < orderedModelChain.length;
    modelIndex += 1
  ) {
    const model = orderedModelChain[modelIndex];
    const modelsTried = modelIndex + 1;
    const isLastModel = modelsTried === orderedModelChain.length;

    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        const { response } = await fetchGemini({
          apiKey: options.apiKey,
          model,
          requestBody: options.createRequestBody(model),
          fetcher,
          timeoutMs,
        });

        if (response.ok) {
          await recordAttemptHealth(
            options.healthStore,
            logger,
            options.scanId,
            model,
            "success",
          );
        } else if (MODEL_HEALTH_FAILURE_STATUSES.has(response.status)) {
          await recordAttemptHealth(
            options.healthStore,
            logger,
            options.scanId,
            model,
            "system_failure",
          );
        }

        if (response.status === 503 && attempt === 1) {
          await response.body?.cancel();
          logger.warn(
            "Gemini model retry",
            JSON.stringify({
              scanId: options.scanId,
              model,
              status: response.status,
              failedAttempt: attempt,
              nextAttempt: attempt + 1,
              delayMs: GEMINI_503_RETRY_DELAY_MS,
            }),
          );
          await sleep(GEMINI_503_RETRY_DELAY_MS);
          continue;
        }

        if (MODEL_FAILOVER_STATUSES.has(response.status) && !isLastModel) {
          await response.body?.cancel();
          logger.warn(
            "Gemini model fallback",
            JSON.stringify({
              scanId: options.scanId,
              model,
              status: response.status,
              attemptsForModel: attempt,
              nextModel: orderedModelChain[modelIndex + 1],
            }),
          );
          break;
        }

        return { response, model, modelsTried, attemptsForModel: attempt };
      } catch (error) {
        if (!(error instanceof GeminiAttemptError)) throw error;
        lastAttemptError = error;
        await recordAttemptHealth(
          options.healthStore,
          logger,
          options.scanId,
          model,
          "system_failure",
        );
        logger.warn(
          "Gemini model fallback",
          JSON.stringify({
            scanId: options.scanId,
            model,
            failureKind: error.kind,
            attemptsForModel: attempt,
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
    lastAttemptError,
  );
}
