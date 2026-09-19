import type { EntitlementTier } from "../_shared/entitlements.ts";
import { type GeminiModelPolicy, resolveModelPolicy } from "./model_policy.ts";

export const DEFAULT_VILAO_BASE_URL = "https://api.vilao.ai/v1";
export const DEFAULT_VILAO_MODEL = "gemini-3.8-flash";
export const DEFAULT_NATIVE_GEMINI_BASE_URL =
  "https://generativelanguage.googleapis.com/v1beta/models";

type EnvironmentReader = (name: string) => string | undefined;

export function isOpenAiCompatible(baseUrl: string): boolean {
  return new URL(baseUrl).hostname !== "generativelanguage.googleapis.com";
}

export function resolveScanGateway(readEnv: EnvironmentReader) {
  const baseUrl = readEnv("GEMINI_BASE_URL")?.trim();
  const apiBaseUrl = readEnv("GEMINI_API_BASE_URL")?.trim();
  const resolvedUrl = baseUrl || apiBaseUrl || DEFAULT_NATIVE_GEMINI_BASE_URL;
  return {
    baseUrl: resolvedUrl,
    // OpenAI-compatible gateways are opt-in. Without an explicit gateway,
    // retain the native Gemini path that the deployed secret supports.
    openAi: baseUrl ? isOpenAiCompatible(baseUrl) : false,
    model: readEnv("GEMINI_MODEL")?.trim() || DEFAULT_VILAO_MODEL,
  };
}

export function resolveScanModelPolicy(
  tier: EntitlementTier,
  gateway: ReturnType<typeof resolveScanGateway>,
  readEnv: EnvironmentReader,
): GeminiModelPolicy {
  // Both tiers use the user's Vilao model. Never send its key to Google as fallback.
  return gateway.openAi
    ? { tier, primaryModel: gateway.model, fallbackModel: null }
    : resolveModelPolicy(tier, readEnv);
}

export function resolveOpenAiEndpoint(baseUrl: string, apiKey: string) {
  const cleanUrl = baseUrl.trim().replace(/\/+$/, "");
  return {
    url: cleanUrl.endsWith("/chat/completions")
      ? cleanUrl
      : `${cleanUrl}/chat/completions`,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
  };
}

export function buildOpenAiRequestBody(
  model: string,
  prompt: string,
  imageBase64: string,
) {
  return {
    model,
    messages: [{
      role: "user",
      content: [
        { type: "text", text: prompt },
        {
          type: "image_url",
          image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
        },
      ],
    }],
    stream: false,
    max_tokens: 8192,
    temperature: 0.2,
  };
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function readScanGatewayResponse(value: unknown) {
  const data = record(value);
  const choice = record(Array.isArray(data.choices) ? data.choices[0] : null);
  const candidate = record(
    Array.isArray(data.candidates) ? data.candidates[0] : null,
  );
  const content = record(candidate.content);
  const part = record(Array.isArray(content.parts) ? content.parts[0] : null);
  const rawText = record(choice.message).content ?? part.text;
  const openAiUsage = record(data.usage);
  return {
    rawText: typeof rawText === "string"
      ? rawText.trim().replace(/^```(?:json)?\s*\n?([\s\S]*?)\n?```$/i, "$1")
        .trim()
      : "",
    finishReason: choice.finish_reason ?? candidate.finishReason,
    usage: data.usageMetadata ?? (data.usage
      ? {
        promptTokenCount: openAiUsage.prompt_tokens,
        candidatesTokenCount: openAiUsage.completion_tokens,
        totalTokenCount: openAiUsage.total_tokens,
      }
      : undefined),
  };
}

export async function isUsableScanGatewayResponse(
  response: Response,
): Promise<boolean> {
  try {
    const { rawText } = readScanGatewayResponse(await response.json());
    if (!rawText) return false;

    const parsed = JSON.parse(rawText);
    return !(
      parsed !== null &&
      typeof parsed === "object" &&
      !Array.isArray(parsed) &&
      Array.isArray((parsed as Record<string, unknown>).words) &&
      ((parsed as Record<string, unknown>).words as unknown[]).length === 0
    );
  } catch {
    // Let the handler return its existing precise malformed/truncated response.
    return true;
  }
}
