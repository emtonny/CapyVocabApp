import type { EntitlementTier } from "../_shared/entitlements.ts";

const LEDGER_REQUEST_TIMEOUT_MS = 1_500;
const RESULT_TTL_MS = 24 * 60 * 60 * 1_000;

type Fetcher = typeof fetch;

export type ScanReservationDecision =
  | "reserved"
  | "replay"
  | "in_progress"
  | "expired";

export interface ScanReservation {
  readonly decision: ScanReservationDecision;
  readonly attemptCount: number;
  readonly resultJson: Record<string, unknown> | null;
  readonly modelUsed: string | null;
  readonly serviceTier: EntitlementTier;
  readonly inputTokenCount: number;
  readonly outputTokenCount: number;
  readonly totalTokenCount: number;
}

export interface ReserveScanRequest {
  readonly userId: string;
  readonly clientRequestId: string;
  readonly serviceTier: EntitlementTier;
}

interface ScanCompletionBase {
  readonly userId: string;
  readonly clientRequestId: string;
  readonly baseAttemptCount: number;
  readonly baseInputTokenCount: number;
  readonly baseOutputTokenCount: number;
  readonly baseTotalTokenCount: number;
  readonly upstreamAttempts: number;
  readonly modelUsed: string | null;
  readonly latencyMs: number;
  readonly inputTokenCount?: number | null;
  readonly outputTokenCount?: number | null;
  readonly totalTokenCount?: number | null;
}

export interface SuccessfulScanCompletion extends ScanCompletionBase {
  readonly wordCount: number;
  readonly resultJson: Record<string, unknown>;
}

export interface FailedScanCompletion extends ScanCompletionBase {
  readonly errorCode: string;
}

export interface ScanLedgerStore {
  reserve(request: ReserveScanRequest): Promise<ScanReservation>;
  completeSuccess(completion: SuccessfulScanCompletion): Promise<void>;
  completeFailure(completion: FailedScanCompletion): Promise<void>;
}

export interface SupabaseScanLedgerStoreOptions {
  readonly supabaseUrl: string;
  readonly serviceRoleKey: string;
  readonly fetcher?: Fetcher;
  readonly requestTimeoutMs?: number;
  readonly now?: () => Date;
}

export class ScanLedgerUnavailableError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "ScanLedgerUnavailableError";
  }
}

function readNullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function readTokenCount(value: number | null | undefined): number | null {
  return Number.isInteger(value) && value! >= 0 ? value! : null;
}

function readStoredCount(value: unknown): number {
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : 0;
}

function parseReservation(value: unknown): ScanReservation {
  if (!Array.isArray(value) || value.length !== 1) {
    throw new Error("Reservation RPC returned an invalid row count");
  }
  const row = value[0] as Record<string, unknown>;
  const decision = row.decision;
  const serviceTier = row.service_tier;
  const attemptCount = row.attempt_count;
  if (
    !["reserved", "replay", "in_progress", "expired"].includes(
      String(decision),
    ) ||
    (serviceTier !== "free" && serviceTier !== "pro") ||
    !Number.isInteger(attemptCount) ||
    Number(attemptCount) < 0
  ) {
    throw new Error("Reservation RPC returned an invalid row");
  }
  const resultJson = row.result_json;
  if (
    resultJson !== null &&
    (typeof resultJson !== "object" || Array.isArray(resultJson))
  ) {
    throw new Error("Reservation RPC returned an invalid result");
  }
  if (decision === "replay" && resultJson === null) {
    throw new Error("Reservation RPC returned replay without a result");
  }
  return {
    decision: decision as ScanReservationDecision,
    attemptCount: Number(attemptCount),
    resultJson: resultJson as Record<string, unknown> | null,
    modelUsed: readNullableString(row.model_used),
    serviceTier,
    inputTokenCount: readStoredCount(row.input_token_count),
    outputTokenCount: readStoredCount(row.output_token_count),
    totalTokenCount: readStoredCount(row.total_token_count),
  };
}

export function createSupabaseScanLedgerStore(
  options: SupabaseScanLedgerStoreOptions,
): ScanLedgerStore {
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.requestTimeoutMs ?? LEDGER_REQUEST_TIMEOUT_MS;
  const now = options.now ?? (() => new Date());
  const headers = {
    apikey: options.serviceRoleKey,
    Authorization: `Bearer ${options.serviceRoleKey}`,
    Accept: "application/json",
    "Content-Type": "application/json",
  };

  async function request(path: string, init: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetcher(`${baseUrl}${path}`, {
        ...init,
        headers: { ...headers, ...init.headers },
        signal: controller.signal,
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(
          `Scan ledger request failed (${response.status}): ${
            body.slice(0, 200)
          }`,
        );
      }
      return response;
    } catch (error) {
      throw new ScanLedgerUnavailableError(
        "Scan ledger database is unavailable",
        { cause: error },
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  async function complete(
    completion: ScanCompletionBase,
    body: Record<string, unknown>,
  ): Promise<void> {
    const query = new URLSearchParams({
      user_id: `eq.${completion.userId}`,
      client_request_id: `eq.${completion.clientRequestId}`,
      status: "eq.processing",
      select: "id",
    });
    const response = await request(`/rest/v1/ai_scan_requests?${query}`, {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(body),
    });
    const rows: unknown = await response.json();
    if (!Array.isArray(rows) || rows.length !== 1) {
      throw new ScanLedgerUnavailableError(
        "Scan ledger completion did not update one processing request",
      );
    }
  }

  function completionFields(completion: ScanCompletionBase, at: Date) {
    return {
      model_used: completion.modelUsed,
      attempt_count: completion.baseAttemptCount +
        completion.upstreamAttempts,
      input_token_count: completion.baseInputTokenCount +
        (readTokenCount(completion.inputTokenCount) ?? 0),
      output_token_count: completion.baseOutputTokenCount +
        (readTokenCount(completion.outputTokenCount) ?? 0),
      total_token_count: completion.baseTotalTokenCount +
        (readTokenCount(completion.totalTokenCount) ?? 0),
      latency_ms: Math.max(0, Math.round(completion.latencyMs)),
      completed_at: at.toISOString(),
      updated_at: at.toISOString(),
    };
  }

  return {
    async reserve(reservation): Promise<ScanReservation> {
      try {
        const response = await request(
          "/rest/v1/rpc/reserve_ai_scan_request",
          {
            method: "POST",
            body: JSON.stringify({
              p_user_id: reservation.userId,
              p_client_request_id: reservation.clientRequestId,
              p_service_tier: reservation.serviceTier,
            }),
          },
        );
        return parseReservation(await response.json());
      } catch (error) {
        if (error instanceof ScanLedgerUnavailableError) throw error;
        throw new ScanLedgerUnavailableError(
          "Scan ledger reservation failed",
          { cause: error },
        );
      }
    },

    async completeSuccess(completion): Promise<void> {
      const completedAt = now();
      await complete(completion, {
        ...completionFields(completion, completedAt),
        status: "succeeded",
        word_count: Math.max(0, Math.round(completion.wordCount)),
        error_code: null,
        result_json: completion.resultJson,
        result_expires_at: new Date(
          completedAt.getTime() + RESULT_TTL_MS,
        ).toISOString(),
      });
    },

    async completeFailure(completion): Promise<void> {
      const completedAt = now();
      await complete(completion, {
        ...completionFields(completion, completedAt),
        status: "failed",
        word_count: null,
        error_code: completion.errorCode,
        result_json: null,
        result_expires_at: null,
      });
    },
  };
}
