import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";

import {
  buildGenerationConfig,
  buildOpenAiRequestBody,
  fetchGeminiModelChain,
  GeminiChainError,
  isOpenAiCompatible,
  normalizeDetectedWordFields,
  resolveGeminiGatewayConfig,
} from "./gemini_client.ts";
import { createSupabaseGeminiHealthStore } from "./gemini_model_health.ts";
import {
  type BoundingBox,
  DEFAULT_BOUNDING_BOX_RATIO,
  normalizeBoundingBox,
  rankWordsByBoxArea,
  shrinkBoundingBox,
} from "./bounding_box.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const { baseUrl: GEMINI_BASE_URL, model: GEMINI_MODEL } =
  resolveGeminiGatewayConfig(
    Deno.env.get("GEMINI_BASE_URL"),
    Deno.env.get("GEMINI_MODEL"),
  );
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const GEMINI_HEALTH_STORE = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createSupabaseGeminiHealthStore({
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
  })
  : undefined;
const MAX_WORDS = 12;
const REDUCED_BOX_AREA_SCALE = DEFAULT_BOUNDING_BOX_RATIO ** 2;

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
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
  required: ["words"],
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

function cleanJsonText(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith("```")) {
    return trimmed
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();
  }
  return trimmed;
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

Deno.serve(async (req) => {
  const scanId = crypto.randomUUID();
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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

  try {
    const { image_base64 } = await req.json();

    if (!image_base64 || typeof image_base64 !== "string") {
      return new Response(
        JSON.stringify({
          error: "invalid_request",
          message: "Thieu image_base64",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (image_base64.length > 600000) {
      return new Response(
        JSON.stringify({
          error: "image_too_large",
          message: "Anh vuot qua gioi han cho phep",
        }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const isOpenAi = isOpenAiCompatible(GEMINI_BASE_URL);
    const modelChain = [GEMINI_MODEL];

    const geminiResult = await fetchGeminiModelChain({
      apiKey: GEMINI_API_KEY,
      scanId,
      baseUrl: GEMINI_BASE_URL,
      modelChain,
      createRequestBody: (model) =>
        isOpenAi
          ? buildOpenAiRequestBody(model, PROMPT, image_base64)
          : {
            contents: [
              {
                parts: [
                  { text: PROMPT },
                  {
                    inline_data: {
                      mime_type: "image/jpeg",
                      data: image_base64,
                    },
                  },
                ],
              },
            ],
            generationConfig: buildGenerationConfig(model, RESPONSE_SCHEMA),
          },
      healthStore: GEMINI_HEALTH_STORE,
    });
    const { response: geminiRes, model, modelsTried, attemptsForModel } =
      geminiResult;

    if (geminiRes.status === 429) {
      return new Response(
        JSON.stringify({
          error: "quota_exceeded",
          message: "He thong dang ban, thu lai sau",
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
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
      return new Response(
        JSON.stringify({
          error: "upstream_unavailable",
          message:
            "Dich vu Gemini tam thoi khong kha dung, vui long thu lai sau",
          upstream_status: geminiRes.status,
          scan_id: scanId,
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
      return new Response(
        JSON.stringify({
          error: "gemini_error",
          message: `Khong the phan tich anh (status ${geminiRes.status})`,
          upstream_status: geminiRes.status,
          scan_id: scanId,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const geminiData = await geminiRes.json();
    const finishReason =
      geminiData?.choices?.[0]?.finish_reason ??
      geminiData?.candidates?.[0]?.finishReason;
    const usage =
      geminiData?.usage ??
      geminiData?.usageMetadata;
    const rawText =
      geminiData?.choices?.[0]?.message?.content ??
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      console.error(
        "Empty response. finishReason:",
        finishReason,
        "usage:",
        JSON.stringify(usage),
      );
      return new Response(
        JSON.stringify({
          error: "empty_response",
          message: "Khong nhan dien duoc tu vung nao",
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let parsed;
    try {
      parsed = JSON.parse(cleanJsonText(rawText));
    } catch {
      console.error(
        "JSON parse failed, finishReason:",
        finishReason,
        "usage:",
        JSON.stringify(usage),
        "raw:",
        rawText.slice(0, 200),
      );
      return new Response(
        JSON.stringify({
          error: "truncated_response",
          message:
            "Ket qua bi cat ngan do qua nhieu du lieu, vui long thu lai voi anh don gian hon",
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (Array.isArray(parsed.words)) {
      // Rank using Gemini's full boxes, then shrink exactly once before the
      // response reaches Flutter or local persistence.
      const normalizedWords = parsed.words.map(normalizeDetectedWordFields);
      parsed.words = deduplicateWords(rankWordsByBoxArea(normalizedWords)).slice(
        0,
        MAX_WORDS,
      ).map((word: unknown, index: number) => {
        const wordWithReducedBox = shrinkDetectedWordBox(word);
        return wordWithReducedBox && typeof wordWithReducedBox === "object"
          ? { ...wordWithReducedBox, number: index + 1 }
          : wordWithReducedBox;
      });
    }

    const words = Array.isArray(parsed.words) ? parsed.words : [];
    logSuspiciousBoxes(words, scanId);
    console.log(
      "Gemini scan success",
      JSON.stringify({
        scanId,
        model,
        modelsTried,
        failedModelsBeforeSuccess: modelsTried - 1,
        attemptsForModel,
        finishReason: finishReason ?? null,
        usageMetadata: usage ?? null,
        wordCount: words.length,
      }),
    );

    return new Response(JSON.stringify(parsed), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const isChainError = err instanceof GeminiChainError;
    const isTimeout = isChainError && err.kind === "timeout";
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
