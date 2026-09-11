import "edge-runtime";

// Supabase provides this global at runtime. Declare the narrow API used here
// so standalone `deno check` validates the function before deployment.
declare namespace EdgeRuntime {
  function waitUntil<T>(promise: Promise<T>): Promise<T>;
}

import {
  buildGenerationConfig,
  fetchGeminiModelChain,
  GeminiChainError,
  GeminiCircuitOpenError,
} from "./gemini_client.ts";
import { createSupabaseGeminiHealthStore } from "./gemini_model_health.ts";
import { ImagePayloadError, parseScanPayload } from "./image_payload.ts";
import {
  createSupabaseScanLedgerStore,
  ScanLedgerUnavailableError,
  type ScanReservation,
} from "./scan_ledger.ts";
import {
  type BoundingBox,
  DEFAULT_BOUNDING_BOX_RATIO,
  normalizeBoundingBox,
  rankWordsByBoxArea,
  shrinkBoundingBox,
} from "./bounding_box.ts";
import {
  GeminiHierarchyShapeError,
  HIERARCHY_SCHEMA_VERSION,
  type HierarchyValidationMetrics,
  normalizeVersion2Hierarchy,
} from "./detection_hierarchy.ts";
import {
  type DetectionRankingMetrics,
  selectHierarchyDetections,
  selectLegacyDetections,
} from "./detection_ranking.ts";
import { buildScanPrompt } from "./scan_prompt.ts";
import { resolveModelPolicy } from "./model_policy.ts";
import {
  authenticateRequest,
  RequestAuthenticationError,
  resolveSupabasePublicApiKey,
} from "../_shared/auth.ts";
import {
  APP_CAPABILITIES,
  CapabilityDeniedError,
  createSupabaseEntitlementStore,
  EntitlementResolutionError,
  requireCapability,
} from "../_shared/entitlements.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_API_BASE_URL = Deno.env.get("GEMINI_API_BASE_URL")?.trim() ||
  undefined;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SUPABASE_PUBLIC_API_KEY = resolveSupabasePublicApiKey((name) =>
  Deno.env.get(name)
);
const ENTITLEMENT_STORE = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createSupabaseEntitlementStore({
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  })
  : undefined;
const GEMINI_HEALTH_STORE = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createSupabaseGeminiHealthStore({
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  })
  : undefined;
const SCAN_LEDGER_STORE = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createSupabaseScanLedgerStore({
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  })
  : undefined;
const MAX_WORDS = 12;
const REDUCED_BOX_AREA_SCALE = DEFAULT_BOUNDING_BOX_RATIO ** 2;
const HIERARCHY_RANKING_OVERRIDE = Deno.env.get(
  "GEMINI_HIERARCHY_RANKING_ENABLED",
)?.trim().toLowerCase();

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    schema_version: {
      type: "INTEGER",
      minimum: HIERARCHY_SCHEMA_VERSION,
      maximum: HIERARCHY_SCHEMA_VERSION,
      description: "The response contract version. Always return 2.",
    },
    words: {
      type: "ARRAY",
      maxItems: MAX_WORDS,
      items: {
        type: "OBJECT",
        properties: {
          number: {
            type: "INTEGER",
            minimum: 1,
            maximum: MAX_WORDS,
          },
          id: {
            type: "STRING",
            minLength: 1,
            description:
              "A unique immutable scan-local ID such as d1. It is not the display number.",
          },
          kind: {
            type: "STRING",
            enum: ["object", "part", "unknown"],
            description:
              "object for an independent item, part for a physical component of a returned object, or unknown when evidence is insufficient.",
          },
          parent_id: {
            type: "STRING",
            nullable: true,
            description:
              "For kind part, the immutable ID of its returned object parent; otherwise null.",
          },
          word: { type: "STRING" },
          phonetic: { type: "STRING" },
          meaning_vi: { type: "STRING" },
          box_2d: {
            type: "ARRAY",
            items: { type: "INTEGER" },
            minItems: 4,
            maxItems: 4,
            description:
              "Bounding box coordinates [ymin, xmin, ymax, xmax] as normalized integers from 0 to 1000.",
          },
        },
        required: ["number", "word", "phonetic", "meaning_vi", "box_2d"],
      },
    },
  },
  required: ["schema_version", "words"],
};

const PROMPT =
  `Identify up to ${MAX_WORDS} of the clearest, most distinct, and most useful primary objects for vocabulary learning in the image.

Accurately identify the true, complete root object (vật thể gốc) itself. Focus on concrete, standalone real-world objects rather than vague background surfaces, walls, floors, reflections, shadows, decorative patterns, textures, or disconnected sub-fragments.

If multiple objects of the same type are present, select only the single clearest representative. Do not return duplicate vocabulary items.

Assign each selected object a unique sequential number using the field \`number\`, starting from \`1\` and continuing in order (\`1, 2, 3, ...\`) with no duplicates or skipped numbers.

For each object, return: its \`number\`; a natural and accurate English name for the root object, lowercase and normally singular; its IPA pronunciation; an accurate, natural Vietnamese meaning that strictly matches the actual root object shown; and its 2D bounding box in \`box_2d\`.

Use the most specific object name supported by the visual evidence, but do not infer or guess any subtype, brand, function, or characteristic that is not clearly visible in the image.

Bounding box coordinates in \`box_2d\` must be an array of 4 INTEGERS [ymin, xmin, ymax, xmax] normalized from 0 to 1000 relative to the full image height and width (0 is top/left, 1000 is bottom/right).

Return the FULL and PIXEL-TIGHT bounding box of the entire visible root object:
- ymin: highest visible point of the object (top edge, 0-1000)
- xmin: leftmost visible point of the object (left edge, 0-1000)
- ymax: lowest visible point of the object (bottom edge, 0-1000)
- xmax: rightmost visible point of the object (right edge, 0-1000)

Include the smallest possible amount of margin or background. Do not enlarge the box to include nearby, overlapping, or visually related objects. For transparent, hollow, or irregularly shaped objects, include only the object's own visible structure and full silhouette; do not treat objects visible through or behind it as part of the object.

Before returning each box, independently verify all four edges:
- ymin must touch the uppermost pixel of the object.
- xmin must touch the leftmost pixel of the object.
- ymax must touch the lowest pixel of the object.
- xmax must touch the rightmost pixel of the object.

Return valid JSON only, with no additional explanation, and never return more than ${MAX_WORDS} elements in the \`words\` array.`;

function logSuspiciousBoxes(words: unknown[], scanId: string) {
  words.forEach((item, index) => {
    if (!item || typeof item !== "object") return;

    const record = item as {
      word?: unknown;
      box?: { x?: unknown; y?: unknown; w?: unknown; h?: unknown };
    };
    const box = record.box;
    if (!box || typeof box.w !== "number" || typeof box.h !== "number") {
      return;
    }
    if (!Number.isFinite(box.w) || !Number.isFinite(box.h)) return;

    const areaRatio = (box.w * box.h) / 1_000_000;
    const context = JSON.stringify({
      scanId,
      index,
      word: typeof record.word === "string" ? record.word : null,
      areaRatio,
      box,
    });

    if (areaRatio > 0.7 * REDUCED_BOX_AREA_SCALE) {
      console.warn("box bất thường lớn", context);
    } else if (areaRatio < 0.005 * REDUCED_BOX_AREA_SCALE) {
      console.warn("box bất thường nhỏ", context);
    }
  });
}

function deduplicateWords(words: unknown[]): unknown[] {
  const seenWords = new Set<string>();

  return words.filter((item) => {
    if (!item || typeof item !== "object") return true;
    const word = (item as { word?: unknown }).word;
    if (typeof word !== "string") return true;

    const normalizedWord = word.trim().toLowerCase();
    if (!normalizedWord || seenWords.has(normalizedWord)) return false;
    seenWords.add(normalizedWord);
    return true;
  });
}
function shrinkDetectedWordBox(word: unknown): unknown {
  if (!word || typeof word !== "object") return word;
  const box = normalizeBoundingBox(word);
  if (!box) return word;

  const shrunkBox = shrinkBoundingBox(box);
  const { box_2d: _, ...rest } = word as Record<string, unknown>;

  return {
    ...rest,
    box: shrunkBox,
  };
}

function usesHierarchyRanking(requestUrl: string): boolean {
  if (HIERARCHY_RANKING_OVERRIDE === "true") return true;
  if (HIERARCHY_RANKING_OVERRIDE === "false") return false;
  return new URL(requestUrl).pathname.endsWith(
    "/gemini-vision-scan-canary",
  );
}

function readUsageCount(usage: unknown, field: string): number | null {
  if (!usage || typeof usage !== "object") return null;
  const value = (usage as Record<string, unknown>)[field];
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : null;
}

Deno.serve(async (req) => {
  const scanId = crypto.randomUUID();
  const requestStartedAt = Date.now();
  let ledgerRequest: {
    readonly userId: string;
    readonly clientRequestId: string;
    readonly reservation: ScanReservation;
  } | undefined;
  let upstreamAttempts = 0;
  let modelUsed: string | null = null;
  let usageForLedger: unknown;
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Expose-Headers": "Retry-After, X-Idempotency-Replayed",
  };

  async function completeFailure(errorCode: string): Promise<void> {
    if (!ledgerRequest || !SCAN_LEDGER_STORE) return;
    try {
      await SCAN_LEDGER_STORE.completeFailure({
        userId: ledgerRequest.userId,
        clientRequestId: ledgerRequest.clientRequestId,
        baseAttemptCount: ledgerRequest.reservation.attemptCount,
        baseInputTokenCount: ledgerRequest.reservation.inputTokenCount,
        baseOutputTokenCount: ledgerRequest.reservation.outputTokenCount,
        baseTotalTokenCount: ledgerRequest.reservation.totalTokenCount,
        upstreamAttempts,
        modelUsed,
        latencyMs: Date.now() - requestStartedAt,
        inputTokenCount: readUsageCount(usageForLedger, "promptTokenCount"),
        outputTokenCount: readUsageCount(
          usageForLedger,
          "candidatesTokenCount",
        ),
        totalTokenCount: readUsageCount(usageForLedger, "totalTokenCount"),
        errorCode,
      });
    } catch (error) {
      console.error("Scan ledger failure completion failed", {
        scanId,
        clientRequestId: ledgerRequest.clientRequestId,
        error,
      });
    }
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_PUBLIC_API_KEY) {
    return new Response(
      JSON.stringify({
        error: "auth_unavailable",
        message: "Dich vu xac thuc chua san sang",
      }),
      {
        status: 503,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Retry-After": "3",
        },
      },
    );
  }

  try {
    const authenticatedUser = await authenticateRequest(req, {
      supabaseUrl: SUPABASE_URL,
      publicApiKey: SUPABASE_PUBLIC_API_KEY,
    });
    if (!ENTITLEMENT_STORE) {
      throw new EntitlementResolutionError(
        "Subscription database configuration is unavailable",
      );
    }
    const entitlements = await requireCapability(
      authenticatedUser.id,
      APP_CAPABILITIES.aiScanBasic,
      ENTITLEMENT_STORE,
    );
    const modelPolicy = resolveModelPolicy(entitlements.tier);

    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({
          error: "server_misconfigured",
          message: "GEMINI_API_KEY chua duoc dat",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!SCAN_LEDGER_STORE) {
      throw new ScanLedgerUnavailableError(
        "Scan ledger database configuration is unavailable",
      );
    }

    const payload = await parseScanPayload(req);
    const reservation = await SCAN_LEDGER_STORE.reserve({
      userId: authenticatedUser.id,
      clientRequestId: payload.clientRequestId,
      serviceTier: entitlements.tier,
    });

    if (reservation.decision === "replay") {
      return new Response(JSON.stringify(reservation.resultJson), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "X-Idempotency-Replayed": "true",
        },
      });
    }
    if (reservation.decision === "in_progress") {
      return new Response(
        JSON.stringify({
          error: "request_in_progress",
          message: "Yeu cau quet nay dang duoc xu ly",
          request_id: payload.clientRequestId,
        }),
        {
          status: 409,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": "2",
          },
        },
      );
    }
    if (reservation.decision === "expired") {
      return new Response(
        JSON.stringify({
          error: "request_result_expired",
          message: "Ket qua cu da het han, vui long tao thao tac quet moi",
          request_id: payload.clientRequestId,
        }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    ledgerRequest = {
      userId: authenticatedUser.id,
      clientRequestId: payload.clientRequestId,
      reservation,
    };

    const geminiResult = await fetchGeminiModelChain({
      apiKey: GEMINI_API_KEY,
      scanId,
      modelPolicy,
      createRequestBody: (model) => ({
        contents: [
          {
            parts: [
              { text: PROMPT },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: payload.imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: buildGenerationConfig(model, RESPONSE_SCHEMA),
      }),
      healthStore: GEMINI_HEALTH_STORE,
      scheduleBackgroundTask: (task) => EdgeRuntime.waitUntil(task),
      apiBaseUrl: GEMINI_API_BASE_URL,
    });
    const {
      response: geminiRes,
      model,
      modelsTried,
      attemptsForModel,
      quotaKind,
    } = geminiResult;
    upstreamAttempts = geminiResult.upstreamAttempts;
    modelUsed = model;

    if (geminiRes.status === 429) {
      const quotaErrorCode = quotaKind && quotaKind !== "unknown"
        ? `quota_${quotaKind}_exceeded`
        : "quota_exceeded";
      await completeFailure(quotaErrorCode);
      const retryAfter = geminiRes.headers.get("retry-after");
      console.warn(
        "Gemini quota exhausted",
        JSON.stringify({
          scanId,
          serviceTier: modelPolicy.tier,
          model,
          quotaKind: quotaKind ?? "unknown",
          upstreamAttempts,
          latencyMs: Date.now() - requestStartedAt,
        }),
      );
      return new Response(
        JSON.stringify({
          error: "quota_exceeded",
          message: "He thong dang ban, thu lai sau",
          request_id: payload.clientRequestId,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            ...(retryAfter ? { "Retry-After": retryAfter } : {}),
          },
        },
      );
    }

    if (geminiRes.status === 503) {
      const errText = await geminiRes.text();
      console.error(
        "Gemini unavailable after retries",
        JSON.stringify({
          scanId,
          model,
          modelsTried,
          upstreamStatus: geminiRes.status,
          attemptsForModel,
          body: errText.slice(0, 500),
        }),
      );
      await completeFailure("upstream_unavailable");
      return new Response(
        JSON.stringify({
          error: "upstream_unavailable",
          message:
            "Dich vu Gemini tam thoi khong kha dung, vui long thu lai sau",
          upstream_status: geminiRes.status,
          scan_id: scanId,
          request_id: payload.clientRequestId,
        }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": "3",
          },
        },
      );
    }

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error(
        "Gemini error",
        JSON.stringify({
          scanId,
          model,
          modelsTried,
          upstreamStatus: geminiRes.status,
          body: errText.slice(0, 500),
        }),
      );
      await completeFailure("gemini_error");
      return new Response(
        JSON.stringify({
          error: "gemini_error",
          message: `Khong the phan tich anh (status ${geminiRes.status})`,
          upstream_status: geminiRes.status,
          scan_id: scanId,
          request_id: payload.clientRequestId,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiRes.json();
    const finishReason = geminiData?.candidates?.[0]?.finishReason;
    const usage = geminiData?.usageMetadata;
    usageForLedger = usage;
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      console.error(
        "Empty response. finishReason:",
        finishReason,
        "usage:",
        JSON.stringify(usage),
      );
      await completeFailure("empty_response");
      return new Response(
        JSON.stringify({
          error: "empty_response",
          message: "Khong nhan dien duoc tu vung nao",
          request_id: payload.clientRequestId,
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      console.error(
        "JSON parse failed, finishReason:",
        finishReason,
        "usage:",
        JSON.stringify(usage),
        "raw:",
        rawText.slice(0, 200),
      );
      await completeFailure("truncated_response");
      return new Response(
        JSON.stringify({
          error: "truncated_response",
          message:
            "Ket qua bi cat ngan do qua nhieu du lieu, vui long thu lai voi anh don gian hon",
          request_id: payload.clientRequestId,
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let rawHierarchyMetrics: HierarchyValidationMetrics;
    try {
      const normalized = normalizeVersion2Hierarchy(parsed);
      parsed = normalized.response;
      rawHierarchyMetrics = normalized.metrics;
    } catch (error) {
      if (!(error instanceof GeminiHierarchyShapeError)) throw error;
      console.error(
        "Gemini hierarchy shape invalid",
        JSON.stringify({ scanId, model, reason: error.message }),
      );
      await completeFailure("invalid_hierarchy_response");
      return new Response(
        JSON.stringify({
          error: "invalid_hierarchy_response",
          message: "Ket qua quan he vat the khong hop le, vui long thu lai",
          request_id: payload.clientRequestId,
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const hierarchyRankingEnabled = usesHierarchyRanking(req.url);
    let rankingMetrics: DetectionRankingMetrics | null = null;
    if (Array.isArray(parsed.words)) {
      // Select using Gemini's full boxes, then shrink exactly once before the
      // response reaches Flutter or local persistence.
      const ranking = hierarchyRankingEnabled
        ? selectHierarchyDetections(parsed.words, MAX_WORDS)
        : selectLegacyDetections(parsed.words, MAX_WORDS);
      rankingMetrics = ranking.metrics;
      const selectedWords = ranking.words.map(
        (word: unknown, index: number) => {
          const wordWithReducedBox = shrinkDetectedWordBox(word);
          return wordWithReducedBox && typeof wordWithReducedBox === "object"
            ? { ...wordWithReducedBox, number: index + 1 }
            : wordWithReducedBox;
        },
      );
      parsed = { ...parsed, words: selectedWords };
    }

    const selectedHierarchy = normalizeVersion2Hierarchy(parsed);
    parsed = {
      ...selectedHierarchy.response,
      scan_id: scanId,
      request_id: payload.clientRequestId,
      model_used: model,
      service_tier: entitlements.tier,
      ranking_strategy: hierarchyRankingEnabled
        ? "hierarchy_v2"
        : "legacy_area",
    };

    const words = Array.isArray(parsed.words) ? parsed.words : [];
    logSuspiciousBoxes(words, scanId);
    console.log(
      "Gemini scan success",
      JSON.stringify({
        scanId,
        serviceTier: entitlements.tier,
        model,
        modelsTried,
        failedModelsBeforeSuccess: modelsTried - 1,
        attemptsForModel,
        finishReason: finishReason ?? null,
        usageMetadata: usage ?? null,
        wordCount: words.length,
        hierarchyValidation: {
          raw: rawHierarchyMetrics,
          selected: selectedHierarchy.metrics,
        },
        ranking: rankingMetrics,
      }),
    );

    try {
      await SCAN_LEDGER_STORE.completeSuccess({
        userId: authenticatedUser.id,
        clientRequestId: payload.clientRequestId,
        baseAttemptCount: reservation.attemptCount,
        baseInputTokenCount: reservation.inputTokenCount,
        baseOutputTokenCount: reservation.outputTokenCount,
        baseTotalTokenCount: reservation.totalTokenCount,
        upstreamAttempts,
        modelUsed: model,
        latencyMs: Date.now() - requestStartedAt,
        inputTokenCount: readUsageCount(usage, "promptTokenCount"),
        outputTokenCount: readUsageCount(usage, "candidatesTokenCount"),
        totalTokenCount: readUsageCount(usage, "totalTokenCount"),
        wordCount: words.length,
        resultJson: parsed,
      });
    } catch (error) {
      console.error("Scan ledger success completion failed", {
        scanId,
        clientRequestId: payload.clientRequestId,
        error,
      });
    }

    return new Response(JSON.stringify(parsed), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    if (err instanceof RequestAuthenticationError) {
      return new Response(
        JSON.stringify({ error: err.code, message: err.message }),
        {
          status: err.status,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            ...(err.status === 503 ? { "Retry-After": "3" } : {}),
          },
        },
      );
    }
    if (err instanceof EntitlementResolutionError) {
      console.error("Entitlement resolution failed", { scanId, error: err });
      return new Response(
        JSON.stringify({
          error: "entitlement_unavailable",
          message: "Khong the kiem tra quyen su dung, vui long thu lai sau",
        }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": "3",
          },
        },
      );
    }
    if (err instanceof ScanLedgerUnavailableError) {
      console.error("Scan ledger reservation failed", { scanId, error: err });
      return new Response(
        JSON.stringify({
          error: "scan_ledger_unavailable",
          message: "Khong the bao toan yeu cau quet, vui long thu lai sau",
        }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": "3",
          },
        },
      );
    }
    if (err instanceof CapabilityDeniedError) {
      return new Response(
        JSON.stringify({
          error: "capability_required",
          message: "Tai khoan khong co quyen su dung tinh nang nay",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    if (err instanceof ImagePayloadError) {
      return new Response(
        JSON.stringify({ error: err.code, message: err.message }),
        {
          status: err.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    if (err instanceof GeminiCircuitOpenError) {
      upstreamAttempts = err.upstreamAttempts;
      modelUsed = err.model;
      await completeFailure("circuit_open");
      console.warn(
        "Gemini model pools unavailable",
        JSON.stringify({
          scanId,
          model: err.model,
          modelsTried: err.modelsTried,
          upstreamAttempts: err.upstreamAttempts,
          retryAfterSeconds: err.retryAfterSeconds,
        }),
      );
      return new Response(
        JSON.stringify({
          error: "upstream_unavailable",
          message:
            "Dich vu Gemini tam thoi khong kha dung, vui long thu lai sau",
          scan_id: scanId,
        }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(err.retryAfterSeconds ?? 3),
          },
        },
      );
    }
    const isChainError = err instanceof GeminiChainError;
    const isTimeout = isChainError && err.kind === "timeout";
    if (isChainError) {
      upstreamAttempts = err.upstreamAttempts;
      modelUsed = err.model;
    }
    await completeFailure(isTimeout ? "timeout" : "internal_error");
    console.error("gemini-vision-scan error:", err);
    return new Response(
      JSON.stringify({
        error: isTimeout ? "timeout" : "internal_error",
        message: isTimeout
          ? "Qua thoi gian cho, vui long thu lai"
          : "Da xay ra loi, vui long thu lai",
        ...(isChainError ? { scan_id: scanId } : {}),
      }),
      {
        status: isTimeout ? 504 : 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
