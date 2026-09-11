const DEFAULT_STUB_PORT = 8787;

export interface GeminiStubOptions {
  delayMs?: number;
}

export function createGeminiStubHandler(
  options: GeminiStubOptions = {},
): (request: Request) => Promise<Response> {
  const delayMs = Math.max(0, options.delayMs ?? 0);

  return async (request) => {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return Response.json({ status: "ok", service: "p6-gemini-stub" });
    }
    if (
      request.method !== "POST" || !url.pathname.endsWith(":generateContent")
    ) {
      return Response.json({ error: "not_found" }, { status: 404 });
    }

    if (delayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }

    return Response.json(
      {
        candidates: [
          {
            finishReason: "STOP",
            content: {
              parts: [
                {
                  text: JSON.stringify({ schema_version: 2, words: [] }),
                },
              ],
            },
          },
        ],
        usageMetadata: {
          promptTokenCount: 10,
          candidatesTokenCount: 2,
          totalTokenCount: 12,
        },
      },
      { headers: { "X-P6-Gemini-Stub": "true" } },
    );
  };
}

if (import.meta.main) {
  const port = Number(Deno.env.get("P6_STUB_PORT") ?? DEFAULT_STUB_PORT);
  const delayMs = Number(Deno.env.get("P6_STUB_DELAY_MS") ?? 0);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("P6_STUB_PORT must be an integer between 1 and 65535");
  }
  if (!Number.isFinite(delayMs) || delayMs < 0) {
    throw new Error("P6_STUB_DELAY_MS must be a non-negative number");
  }

  console.log(`P6 Gemini stub listening on http://127.0.0.1:${port}`);
  Deno.serve(
    { hostname: "0.0.0.0", port },
    createGeminiStubHandler({ delayMs }),
  );
}
