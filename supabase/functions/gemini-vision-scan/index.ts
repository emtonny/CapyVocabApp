import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  buildGenerationConfig,
  fetchGeminiModelChain,
  GeminiChainError,
} from "./gemini_client.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const MAX_WORDS = 15;

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    words: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          word: { type: "STRING" },
          phonetic: { type: "STRING" },
          meaning_vi: { type: "STRING" },
          box: {
            type: "OBJECT",
            properties: {
              x: { type: "INTEGER" },
              y: { type: "INTEGER" },
              w: { type: "INTEGER" },
              h: { type: "INTEGER" },
            },
            required: ["x", "y", "w", "h"],
          },
        },
        required: ["word", "phonetic", "meaning_vi", "box"],
      },
    },
  },
  required: ["words"],
};

const PROMPT =
  `Ban la tro ly nhan dien do vat trong anh de hoc tu vung tieng Anh.
Hay xac dinh CAC DOI TUONG RO RANG, PHO BIEN nhat trong anh.
GIOI HAN NGHIEM NGAT: TOI DA ${MAX_WORDS} DOI TUONG - neu anh co nhieu hon,
CHI chon ${MAX_WORDS} doi tuong quan trong/ro rang nhat, bo qua phan con lai.
XEP UU TIEN CAC DOI TUONG THEO THU TU: dien tich bounding box lon hon la
uu tien cao nhat; khi dien tich gan tuong duong, uu tien doi tuong co gia tri
hoc tu vung, pho bien, ro rang va de nhan dien hon.
Neu anh co nhieu vat the cung loai (vi du nhieu qua tao giong nhau), CHI
chon DUNG 1 VAT THE DAI DIEN ro rang/de nhan dien nhat de dua vao ket qua.
KHONG liet ke trung lap nhieu lan cung 1 tu trong mang words tra ve.

Voi moi doi tuong, tra ve: tu tieng Anh (thuong, so it), phien am IPA,
nghia tieng Viet ngan gon, va toa do khung bao quanh doi tuong do.

QUAN TRONG VE TOA DO: tra ve duoi dang SO NGUYEN trong khoang 0 den 1000
(KHONG PHAI so thap phan 0.0-1.0), voi x/y la goc tren-trai cua khung,
w/h la chieu rong/cao cua khung, tat ca tinh theo ty le so voi kich
thuoc anh (anh rong/cao = 1000 don vi).
TOA DO BOX PHAI OM SAT DUNG VIEN VAT THE THAT TRONG ANH, KHONG UOC LUONG
QUA LOA. Voi vat the lon hoac phuc tap (nguoi, do noi that, nhom vat the),
hay tinh tam va kich thuoc dua tren TOAN BO VUNG VAT THE chiem trong anh,
khong chi dua vao phan de nhan dien nhat (vi du: khuon mat).

TRUOC KHI TRA JSON, TU KIEM TRA LAI MOT LAN cho tung box: box phai nam
hoan toan trong anh, om dung vat the tuong ung voi "word" da chon, va
khong bo sot phan ro rang nao cua vat the.

Tra loi NGAY, khong can suy nghi nhieu buoc - day la tac vu nhan dien
don gian. Chi tra JSON, khong giai thich them, khong vuot qua
${MAX_WORDS} phan tu trong mang words.`;

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

    if (areaRatio > 0.7) {
      console.warn("box bất thường lớn", context);
    } else if (areaRatio < 0.005) {
      console.warn("box bất thường nhỏ", context);
    }
  });
}

function rankWordsByBoxArea(words: unknown[]): unknown[] {
  return words
    .map((word, index) => ({ word, index, area: readBoxArea(word) }))
    .sort((first, second) =>
      second.area - first.area || first.index - second.index
    )
    .map(({ word }) => word);
}

function readBoxArea(word: unknown): number {
  if (!word || typeof word !== "object") return -1;
  const box = (word as { box?: unknown }).box;
  if (!box || typeof box !== "object") return -1;
  const { w, h } = box as { w?: unknown; h?: unknown };
  if (typeof w !== "number" || typeof h !== "number") return -1;
  if (!Number.isFinite(w) || !Number.isFinite(h)) return -1;
  return w >= 0 && h >= 0 ? w * h : -1;
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

    const geminiResult = await fetchGeminiModelChain({
      apiKey: GEMINI_API_KEY,
      scanId,
      createRequestBody: (model) => ({
        contents: [
          {
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: "image/jpeg", data: image_base64 } },
            ],
          },
        ],
        generationConfig: buildGenerationConfig(model, RESPONSE_SCHEMA),
      }),
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
    const finishReason = geminiData?.candidates?.[0]?.finishReason;
    const usage = geminiData?.usageMetadata;
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

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
      parsed = JSON.parse(rawText);
    } catch (parseErr) {
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
      parsed.words = rankWordsByBoxArea(parsed.words).slice(0, MAX_WORDS);
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
