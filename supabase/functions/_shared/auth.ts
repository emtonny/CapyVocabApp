export interface AuthenticatedUser {
  readonly id: string;
}

export interface AuthenticateRequestOptions {
  supabaseUrl: string;
  publicApiKey: string;
  fetcher?: typeof fetch;
  requestTimeoutMs?: number;
}

export class RequestAuthenticationError extends Error {
  readonly status: 401 | 503;
  readonly code: "authentication_required" | "auth_unavailable";

  constructor(
    status: 401 | 503,
    code: "authentication_required" | "auth_unavailable",
    message: string,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = "RequestAuthenticationError";
    this.status = status;
    this.code = code;
  }
}

const AUTH_REQUEST_TIMEOUT_MS = 2_000;

function readBearerToken(request: Request): string {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);
  if (!match) {
    throw new RequestAuthenticationError(
      401,
      "authentication_required",
      "Bearer JWT is required",
    );
  }
  return match[1];
}

export function resolveSupabasePublicApiKey(
  readEnv: (name: string) => string | undefined,
): string | undefined {
  const direct = readEnv("SUPABASE_PUBLISHABLE_KEY")?.trim() ||
    readEnv("SUPABASE_ANON_KEY")?.trim();
  if (direct) return direct;

  const rawKeys = readEnv("SUPABASE_PUBLISHABLE_KEYS")?.trim();
  if (!rawKeys) return undefined;
  try {
    const parsed: unknown = JSON.parse(rawKeys);
    if (!parsed || typeof parsed !== "object") return undefined;
    return Object.values(parsed).find((value) =>
      typeof value === "string" && value.trim().length > 0
    ) as string | undefined;
  } catch {
    return undefined;
  }
}

export async function authenticateRequest(
  request: Request,
  options: AuthenticateRequestOptions,
): Promise<AuthenticatedUser> {
  const token = readBearerToken(request);
  const baseUrl = options.supabaseUrl.replace(/\/+$/, "");
  const fetcher = options.fetcher ?? fetch;
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    options.requestTimeoutMs ?? AUTH_REQUEST_TIMEOUT_MS,
  );

  try {
    const response = await fetcher(`${baseUrl}/auth/v1/user`, {
      headers: {
        apikey: options.publicApiKey,
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
      signal: controller.signal,
    });

    if (response.status === 401 || response.status === 403) {
      throw new RequestAuthenticationError(
        401,
        "authentication_required",
        "JWT is invalid or expired",
      );
    }
    if (!response.ok) {
      throw new RequestAuthenticationError(
        503,
        "auth_unavailable",
        "Authentication service is unavailable",
      );
    }

    const body: unknown = await response.json();
    const id = (body as { id?: unknown })?.id;
    if (typeof id !== "string" || !id.trim()) {
      throw new RequestAuthenticationError(
        503,
        "auth_unavailable",
        "Authentication service returned an invalid user",
      );
    }
    return { id };
  } catch (error) {
    if (error instanceof RequestAuthenticationError) throw error;
    throw new RequestAuthenticationError(
      503,
      "auth_unavailable",
      "Authentication service is unavailable",
      { cause: error },
    );
  } finally {
    clearTimeout(timeout);
  }
}
