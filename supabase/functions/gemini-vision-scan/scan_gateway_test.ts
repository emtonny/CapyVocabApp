import assert from "node:assert/strict";
import test from "node:test";
import {
  buildOpenAiRequestBody,
  DEFAULT_NATIVE_GEMINI_BASE_URL,
  DEFAULT_VILAO_BASE_URL,
  DEFAULT_VILAO_MODEL,
  isUsableScanGatewayResponse,
  readScanGatewayResponse,
  resolveOpenAiEndpoint,
  resolveScanGateway,
  resolveScanModelPolicy,
} from "./scan_gateway.ts";
import {
  fetchGeminiModelChain,
  normalizeDetectedWordFields,
} from "./gemini_client.ts";

const noSecrets = () => undefined;
const vilaoEnvironment = (name: string) =>
  name === "GEMINI_BASE_URL" ? DEFAULT_VILAO_BASE_URL : undefined;
const logger = { warn() {}, error() {} };

test("native Gemini remains the safe default for Free and Pro", () => {
  const gateway = resolveScanGateway(noSecrets);
  assert.equal(gateway.baseUrl, DEFAULT_NATIVE_GEMINI_BASE_URL);
  assert.equal(gateway.openAi, false);
  assert.equal(
    resolveScanModelPolicy("free", gateway, noSecrets).primaryModel,
    "gemini-3.5-flash-lite",
  );
  assert.equal(
    resolveScanModelPolicy("pro", gateway, noSecrets).primaryModel,
    "gemini-3.7-flash",
  );
});

test("existing Vilao environment wins over native-Gemini configuration", () => {
  const env = new Map([
    ["GEMINI_BASE_URL", " https://api.vilao.ai/v1/ "],
    ["GEMINI_MODEL", " custom-vilao-model "],
    ["GEMINI_API_BASE_URL", "http://127.0.0.1:8787/v1beta/models"],
    ["GEMINI_FREE_MODEL", "not-the-vilao-model"],
  ]);
  const read = (name: string) => env.get(name);
  const gateway = resolveScanGateway(read);
  assert.equal(gateway.openAi, true);
  assert.equal(
    resolveScanModelPolicy("free", gateway, read).primaryModel,
    "custom-vilao-model",
  );
});

test("native Gemini and the P6 stub remain explicit opt-ins", () => {
  for (
    const baseUrl of [
      "https://generativelanguage.googleapis.com/v1beta/models",
      "http://127.0.0.1:8787/v1beta/models",
    ]
  ) {
    const read = (name: string) =>
      name === "GEMINI_API_BASE_URL" ? baseUrl : undefined;
    const gateway = resolveScanGateway(read);
    assert.equal(gateway.openAi, false);
    assert.equal(gateway.baseUrl, baseUrl);
    assert.equal(
      resolveScanModelPolicy("free", gateway, read).primaryModel,
      "gemini-3.5-flash-lite",
    );
  }
  const gateway = resolveScanGateway((name) =>
    name === "GEMINI_BASE_URL"
      ? "https://generativelanguage.googleapis.com/v1beta/models"
      : undefined
  );
  assert.equal(gateway.openAi, false);
});

test("blank settings retain native defaults and endpoints are not duplicated", () => {
  assert.deepEqual(
    resolveScanGateway(() => "  "),
    resolveScanGateway(noSecrets),
  );
  for (const suffix of ["", "/", "/chat/completions", "/chat/completions/"]) {
    const endpoint = resolveOpenAiEndpoint(
      `${DEFAULT_VILAO_BASE_URL}${suffix}`,
      "fixture-key",
    );
    assert.equal(endpoint.url, `${DEFAULT_VILAO_BASE_URL}/chat/completions`);
    assert.equal(endpoint.headers.Authorization, "Bearer fixture-key");
    assert.equal(endpoint.url.includes("fixture-key"), false);
  }
});

test("Vilao request uses chat completions, an image data URL and the configured model", async () => {
  const gateway = resolveScanGateway(vilaoEnvironment);
  const result = await fetchGeminiModelChain({
    apiKey: "fixture-key",
    scanId: "vilao-request",
    openAiBaseUrl: gateway.baseUrl,
    modelPolicy: resolveScanModelPolicy("free", gateway, vilaoEnvironment),
    createRequestBody: (model) =>
      buildOpenAiRequestBody(model, "scan prompt", "/9j/"),
    fetcher: (input, init) => {
      assert.equal(String(input), `${DEFAULT_VILAO_BASE_URL}/chat/completions`);
      assert.equal(
        new Headers(init?.headers).get("Authorization"),
        "Bearer fixture-key",
      );
      const body = JSON.parse(String(init?.body));
      assert.equal(body.model, DEFAULT_VILAO_MODEL);
      assert.equal(body.stream, false);
      assert.deepEqual(body.messages[0].content, [
        { type: "text", text: "scan prompt" },
        {
          type: "image_url",
          image_url: { url: "data:image/jpeg;base64,/9j/" },
        },
      ]);
      return Promise.resolve(Response.json({ choices: [] }));
    },
    logger,
  });
  assert.equal(result.upstreamAttempts, 1);
  assert.equal(result.model, DEFAULT_VILAO_MODEL);
});

test("Vilao 503 retry stays on Vilao and retains the two-attempt limit", async () => {
  const gateway = resolveScanGateway(vilaoEnvironment);
  let calls = 0;
  const result = await fetchGeminiModelChain({
    apiKey: "fixture-key",
    scanId: "vilao-retry",
    openAiBaseUrl: gateway.baseUrl,
    modelPolicy: resolveScanModelPolicy("pro", gateway, vilaoEnvironment),
    createRequestBody: (model) =>
      buildOpenAiRequestBody(model, "prompt", "/9j/"),
    fetcher: (input) => {
      calls++;
      assert.equal(String(input), `${DEFAULT_VILAO_BASE_URL}/chat/completions`);
      return Promise.resolve(new Response("unavailable", { status: 503 }));
    },
    sleep: () => Promise.resolve(),
    logger,
  });
  assert.equal(calls, 2);
  assert.equal(result.upstreamAttempts, 2);
  assert.equal(result.modelsTried, 1);
});

test("OpenAI JSON fences and token usage map to the scan ledger contract", () => {
  const result = readScanGatewayResponse({
    choices: [{
      finish_reason: "stop",
      message: { content: '```json\n{"schema_version":2,"words":[]}\n```' },
    }],
    usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 },
  });
  assert.deepEqual(JSON.parse(result.rawText), {
    schema_version: 2,
    words: [],
  });
  assert.equal(result.finishReason, "stop");
  assert.deepEqual(result.usage, {
    promptTokenCount: 12,
    candidatesTokenCount: 8,
    totalTokenCount: 20,
  });
});

test("native Gemini response and malformed envelopes remain handled", () => {
  const usage = {
    promptTokenCount: 4,
    candidatesTokenCount: 5,
    totalTokenCount: 9,
  };
  const result = readScanGatewayResponse({
    candidates: [{
      finishReason: "STOP",
      content: { parts: [{ text: '{"words":[]}' }] },
    }],
    usageMetadata: usage,
  });
  assert.equal(result.rawText, '{"words":[]}');
  assert.deepEqual(result.usage, usage);
  for (
    const input of [null, [], {}, { choices: [{ message: { content: 123 } }] }]
  ) {
    assert.equal(readScanGatewayResponse(input).rawText, "");
  }
});

test("empty detection JSON is retryable but malformed JSON keeps its precise error", async () => {
  const response = (content: string) =>
    Response.json({ choices: [{ message: { content } }] });

  assert.equal(
    await isUsableScanGatewayResponse(
      response('{"schema_version":2,"words":[]}'),
    ),
    false,
  );
  assert.equal(
    await isUsableScanGatewayResponse(
      response('{"schema_version":2,"words":[{"word":"cup"}]}'),
    ),
    true,
  );
  assert.equal(await isUsableScanGatewayResponse(response("{invalid")), true);
});

test("Vilao aliases normalize without changing canonical fields or hierarchy", () => {
  const raw = {
    english: "cup",
    ipa: "/kʌp/",
    vietnamese: "cái cốc",
    id: "d1",
    kind: "object",
    parent_id: null,
  };
  assert.deepEqual(normalizeDetectedWordFields(raw), {
    word: "cup",
    phonetic: "/kʌp/",
    meaning_vi: "cái cốc",
    id: "d1",
    kind: "object",
    parent_id: null,
  });
  assert.equal(raw.english, "cup");
  assert.deepEqual(
    normalizeDetectedWordFields({ word: "cup", name: "wrong" }),
    { word: "cup" },
  );
});
