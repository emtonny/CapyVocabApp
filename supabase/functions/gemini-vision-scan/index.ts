import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent";
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
              h: { type: "INTEGER" }
            },
            required: ["x", "y", "w", "h"]
          }
        },
        required: ["word", "phonetic", "meaning_vi", "box"]
      }
    }
  },
  required: ["words"]
};

const PROMPT = `Ban la tro ly nhan dien do vat trong anh de hoc tu vung tieng Anh.
Hay xac dinh CAC DOI TUONG RO RANG, PHO BIEN nhat trong anh.
GIOI HAN NGHIEM NGAT: TOI DA ${MAX_WORDS} DOI TUONG - neu anh co nhieu hon,
CHI chon ${MAX_WORDS} doi tuong quan trong/ro rang nhat, bo qua phan con lai.

Voi moi doi tuong, tra ve: tu tieng Anh (thuong, so it), phien am IPA,
nghia tieng Viet ngan gon, va toa do khung bao quanh doi tuong do.

QUAN TRONG VE TOA DO: tra ve duoi dang SO NGUYEN trong khoang 0 den 1000
(KHONG PHAI so thap phan 0.0-1.0), voi x/y la goc tren-trai cua khung,
w/h la chieu rong/cao cua khung, tat ca tinh theo ty le so voi kich
thuoc anh (anh rong/cao = 1000 don vi).

Tra loi NGAY, khong can suy nghi nhieu buoc - day la tac vu nhan dien
don gian. Chi tra JSON, khong giai thich them, khong vuot qua
${MAX_WORDS} phan tu trong mang words.`;

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "server_misconfigured", message: "GEMINI_API_KEY chua duoc dat" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const { image_base64 } = await req.json();

    if (!image_base64 || typeof image_base64 !== "string") {
      return new Response(
        JSON.stringify({ error: "invalid_request", message: "Thieu image_base64" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (image_base64.length > 600000) {
      return new Response(
        JSON.stringify({ error: "image_too_large", message: "Anh vuot qua gioi han cho phep" }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);

    const geminiRes = await fetch(`${GEMINI_ENDPOINT}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: "image/jpeg", data: image_base64 } }
            ]
          }
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          temperature: 0.2,
          maxOutputTokens: 8192,
          thinkingConfig: {
            thinkingLevel: "low"
          }
        }
      })
    }).finally(() => clearTimeout(timeout));

    if (geminiRes.status === 429) {
      return new Response(
        JSON.stringify({ error: "quota_exceeded", message: "He thong dang ban, thu lai sau" }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error("Gemini error:", geminiRes.status, errText);
      return new Response(
        JSON.stringify({ error: "gemini_error", message: `Khong the phan tich anh (status ${geminiRes.status})` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiRes.json();
    const finishReason = geminiData?.candidates?.[0]?.finishReason;
    const usage = geminiData?.usageMetadata;
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!rawText) {
      console.error("Empty response. finishReason:", finishReason, "usage:", JSON.stringify(usage));
      return new Response(
        JSON.stringify({ error: "empty_response", message: "Khong nhan dien duoc tu vung nao" }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch (parseErr) {
      console.error("JSON parse failed, finishReason:", finishReason, "usage:", JSON.stringify(usage), "raw:", rawText.slice(0, 200));
      return new Response(
        JSON.stringify({
          error: "truncated_response",
          message: "Ket qua bi cat ngan do qua nhieu du lieu, vui long thu lai voi anh don gian hon"
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (Array.isArray(parsed.words) && parsed.words.length > MAX_WORDS) {
      parsed.words = parsed.words.slice(0, MAX_WORDS);
    }

    return new Response(JSON.stringify(parsed), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  } catch (err) {
    const isTimeout = err instanceof Error && err.name === "AbortError";
    console.error("gemini-vision-scan error:", err);
    return new Response(
      JSON.stringify({
        error: isTimeout ? "timeout" : "internal_error",
        message: isTimeout ? "Qua thoi gian cho, vui long thu lai" : "Da xay ra loi, vui long thu lai"
      }),
      { status: isTimeout ? 504 : 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
