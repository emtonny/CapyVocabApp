import assert from "node:assert/strict";
import test from "node:test";

import {
  ImagePayloadError,
  MAX_BINARY_IMAGE_BYTES,
  parseImagePayload,
  parseScanPayload,
} from "./image_payload.ts";

const REQUEST_ID = "123e4567-e89b-42d3-a456-426614174000";

test("parses JPEG bytes without requiring base64 on the client", async () => {
  const bytes = new Uint8Array([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9]);
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "image/jpeg" },
    body: bytes,
  });

  assert.equal(
    await parseImagePayload(request),
    btoa("\xff\xd8\x01\x02\x03\xff\xd9"),
  );
});

test("keeps the legacy JSON base64 contract", async () => {
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ image_base64: "legacy-base64" }),
  });

  assert.equal(await parseImagePayload(request), "legacy-base64");
});

test("parses the client request id without trusting client identity fields", async () => {
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      request_id: REQUEST_ID,
      image_base64: "compressed-base64",
      user_id: "forged-user",
      service_tier: "pro",
    }),
  });

  assert.deepEqual(await parseScanPayload(request), {
    clientRequestId: REQUEST_ID,
    imageBase64: "compressed-base64",
  });
});

test("rejects malformed request ids before Gemini", async () => {
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      request_id: "not-a-uuid",
      image_base64: "compressed-base64",
    }),
  });

  await assert.rejects(
    () => parseScanPayload(request),
    (error: unknown) =>
      error instanceof ImagePayloadError &&
      error.status === 400 &&
      error.code === "invalid_request_id",
  );
});

test("ignores client-forged identity, tier, capability, and model fields", async () => {
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      image_base64: "trusted-image-field-only",
      user_id: "victim-user",
      is_pro: true,
      plan: "pro",
      tier: "pro",
      model: "gemini-premium-client-choice",
    }),
  });

  assert.equal(
    await parseImagePayload(request),
    "trusted-image-field-only",
  );
});

test("rejects an oversized binary image before encoding it", async () => {
  const request = new Request("https://example.test/scan", {
    method: "POST",
    headers: { "Content-Type": "image/jpeg" },
    body: new Uint8Array(MAX_BINARY_IMAGE_BYTES + 1),
  });

  await assert.rejects(
    () => parseImagePayload(request),
    (error: unknown) =>
      error instanceof ImagePayloadError && error.status === 413,
  );
});
