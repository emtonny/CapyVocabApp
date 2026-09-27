import {
  type TranslationProvider,
  type TranslationQueue,
  TranslationQueueUnavailableError,
  type WorkerLogger,
} from "./contracts.ts";
import { runTranslationWorker } from "./worker.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };
const textEncoder = new TextEncoder();

export interface ChatTranslationHandlerOptions {
  readonly triggerSecret?: string;
  readonly queue?: TranslationQueue;
  readonly provider?: TranslationProvider;
  readonly logger?: WorkerLogger;
  readonly requestId?: () => string;
}

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = textEncoder.encode(left);
  const rightBytes = textEncoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

export function createChatTranslationHandler(
  options: ChatTranslationHandlerOptions,
): (request: Request) => Promise<Response> {
  return async (request): Promise<Response> => {
    const requestId = options.requestId?.() ?? crypto.randomUUID();
    if (request.method !== "POST") {
      return jsonResponse(405, { error: "method_not_allowed", requestId });
    }

    const configuredSecret = options.triggerSecret?.trim() ?? "";
    if (!configuredSecret) {
      return jsonResponse(503, { error: "trigger_not_configured", requestId });
    }
    const suppliedSecret = request.headers.get(
      "x-chat-translation-trigger",
    ) ?? "";
    if (!constantTimeEqual(suppliedSecret, configuredSecret)) {
      return jsonResponse(401, { error: "authentication_required", requestId });
    }

    // Missing runtime credentials must fail before claim and consume no attempt.
    if (!options.queue || !options.provider) {
      return jsonResponse(503, { error: "provider_not_configured", requestId });
    }

    try {
      const result = await runTranslationWorker({
        queue: options.queue,
        provider: options.provider,
        logger: options.logger,
        signal: request.signal,
      });
      if (result.status === "idle") return new Response(null, { status: 204 });
      return jsonResponse(200, {
        status: result.status,
        translationId: result.translationId,
        attemptCount: result.attemptCount,
        ...(result.status === "failed" ? { errorCode: result.errorCode } : {}),
        requestId,
      });
    } catch (error) {
      options.logger?.warn("chat_translation_worker_unavailable", {
        requestId,
        reason: error instanceof TranslationQueueUnavailableError
          ? "queue_unavailable"
          : "worker_unavailable",
      });
      return jsonResponse(503, { error: "worker_unavailable", requestId });
    }
  };
}
