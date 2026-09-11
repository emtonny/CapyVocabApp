const MAX_BASE64_IMAGE_LENGTH = 600_000;
export const MAX_BINARY_IMAGE_BYTES = 450_000;

export class ImagePayloadError extends Error {
  readonly status: number;
  readonly code:
    | "invalid_request"
    | "invalid_request_id"
    | "image_too_large";

  constructor(
    status: number,
    code: "invalid_request" | "invalid_request_id" | "image_too_large",
    message: string,
  ) {
    super(message);
    this.name = "ImagePayloadError";
    this.status = status;
    this.code = code;
  }
}

export interface ScanPayload {
  readonly clientRequestId: string;
  readonly imageBase64: string;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function readClientRequestId(value: unknown): string {
  if (value === undefined || value === null || value === "") {
    return crypto.randomUUID();
  }
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new ImagePayloadError(
      400,
      "invalid_request_id",
      "request_id khong hop le",
    );
  }
  return value.toLowerCase();
}

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  const chunks: string[] = [];
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    chunks.push(
      String.fromCharCode(...bytes.subarray(offset, offset + chunkSize)),
    );
  }
  return btoa(chunks.join(""));
}

export async function parseScanPayload(request: Request): Promise<ScanPayload> {
  const contentType = request.headers.get("content-type")
    ?.split(";", 1)[0]
    .trim()
    .toLowerCase();

  if (
    contentType === "image/jpeg" || contentType === "application/octet-stream"
  ) {
    const bytes = new Uint8Array(await request.arrayBuffer());
    if (bytes.length === 0) {
      throw new ImagePayloadError(400, "invalid_request", "Anh trong");
    }
    if (bytes.length > MAX_BINARY_IMAGE_BYTES) {
      throw new ImagePayloadError(
        413,
        "image_too_large",
        "Anh vuot qua gioi han cho phep",
      );
    }
    return {
      clientRequestId: readClientRequestId(
        request.headers.get("x-request-id"),
      ),
      imageBase64: encodeBase64(bytes),
    };
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new ImagePayloadError(
      400,
      "invalid_request",
      "Payload anh khong hop le",
    );
  }
  const record = body as {
    request_id?: unknown;
    image_base64?: unknown;
  };
  const imageBase64 = record?.image_base64;
  if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
    throw new ImagePayloadError(400, "invalid_request", "Thieu image_base64");
  }
  if (imageBase64.length > MAX_BASE64_IMAGE_LENGTH) {
    throw new ImagePayloadError(
      413,
      "image_too_large",
      "Anh vuot qua gioi han cho phep",
    );
  }
  return {
    clientRequestId: readClientRequestId(record?.request_id),
    imageBase64,
  };
}

export async function parseImagePayload(request: Request): Promise<string> {
  return (await parseScanPayload(request)).imageBase64;
}
