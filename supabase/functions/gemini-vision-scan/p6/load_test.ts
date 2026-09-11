type ServiceTier = "free" | "pro";
type LoadProfile = "free" | "pro" | "free99-pro1" | "free98-pro2";

export interface LoadResult {
  expectedTier: ServiceTier;
  status: number;
  latencyMs: number;
  serviceTier: string | null;
  modelUsed: string | null;
}

export interface LoadSummary {
  total: number;
  successRate: number;
  rate429: number;
  p50Ms: number;
  p95Ms: number;
  p99Ms: number;
  tierMismatches: number;
  modelMismatches: number;
  statuses: Record<string, number>;
  passed: boolean;
}

const PROFILE_PRO_SHARE: Record<LoadProfile, number> = {
  free: 0,
  pro: 1,
  "free99-pro1": 0.01,
  "free98-pro2": 0.02,
};

const TEST_IMAGE_BASE64 =
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EH//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EH//2Q==";

export function tierForRequest(
  profile: LoadProfile,
  requestIndex: number,
): ServiceTier {
  const proShare = PROFILE_PRO_SHARE[profile];
  const proBefore = Math.floor(requestIndex * proShare);
  const proAfter = Math.floor((requestIndex + 1) * proShare);
  return proAfter > proBefore ? "pro" : "free";
}

export function validateProfileSample(
  profile: LoadProfile,
  totalRequests: number,
): void {
  const proShare = PROFILE_PRO_SHARE[profile];
  if (proShare > 0 && proShare < 1) {
    const minimumRequests = Math.ceil(1 / proShare);
    if (totalRequests < minimumRequests) {
      throw new Error(
        `${profile} requires at least ${minimumRequests} requests to include its Pro share`,
      );
    }
  }
}

function percentile(values: number[], percentileValue: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.max(
    0,
    Math.ceil((percentileValue / 100) * sorted.length) - 1,
  );
  return sorted[index];
}

export function summarizeLoadResults(
  results: LoadResult[],
  freeModel: string,
  proModels: ReadonlySet<string>,
): LoadSummary {
  const statuses: Record<string, number> = {};
  let successes = 0;
  let quotaErrors = 0;
  let tierMismatches = 0;
  let modelMismatches = 0;

  for (const result of results) {
    statuses[String(result.status)] = (statuses[String(result.status)] ?? 0) +
      1;
    if (result.status === 200) successes += 1;
    if (result.status === 429) quotaErrors += 1;
    if (result.status === 200 && result.serviceTier !== result.expectedTier) {
      tierMismatches += 1;
    }
    if (
      result.status === 200 &&
      (result.expectedTier === "free"
        ? result.modelUsed !== freeModel
        : !result.modelUsed || !proModels.has(result.modelUsed))
    ) {
      modelMismatches += 1;
    }
  }

  const total = results.length;
  const successRate = total === 0 ? 0 : successes / total;
  const rate429 = total === 0 ? 0 : quotaErrors / total;
  return {
    total,
    successRate,
    rate429,
    p50Ms: percentile(results.map((result) => result.latencyMs), 50),
    p95Ms: percentile(results.map((result) => result.latencyMs), 95),
    p99Ms: percentile(results.map((result) => result.latencyMs), 99),
    tierMismatches,
    modelMismatches,
    statuses,
    passed: successRate >= 0.99 && rate429 < 0.01 &&
      tierMismatches === 0 && modelMismatches === 0,
  };
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function readInteger(name: string, fallback: number, min: number, max: number) {
  const value = Number(Deno.env.get(name) ?? fallback);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer from ${min} to ${max}`);
  }
  return value;
}

async function sendScan(
  targetUrl: string,
  token: string,
  expectedTier: ServiceTier,
): Promise<LoadResult> {
  const startedAt = performance.now();
  try {
    const response = await fetch(targetUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        request_id: crypto.randomUUID(),
        image_base64: TEST_IMAGE_BASE64,
      }),
      signal: AbortSignal.timeout(90_000),
    });
    let body: Record<string, unknown> = {};
    try {
      body = await response.json();
    } catch {
      // Status and latency still belong in the report for non-JSON failures.
    }
    return {
      expectedTier,
      status: response.status,
      latencyMs: Math.round(performance.now() - startedAt),
      serviceTier: typeof body.service_tier === "string"
        ? body.service_tier
        : null,
      modelUsed: typeof body.model_used === "string" ? body.model_used : null,
    };
  } catch {
    return {
      expectedTier,
      status: 0,
      latencyMs: Math.round(performance.now() - startedAt),
      serviceTier: null,
      modelUsed: null,
    };
  }
}

if (import.meta.main) {
  if (Deno.env.get("P6_CONFIRM_GEMINI_STUB") !== "YES") {
    throw new Error(
      "Refusing load test without P6_CONFIRM_GEMINI_STUB=YES; never load-test a real Gemini key",
    );
  }

  const targetUrl = requiredEnv("P6_TARGET_URL");
  const profile = requiredEnv("P6_PROFILE") as LoadProfile;
  if (!(profile in PROFILE_PRO_SHARE)) {
    throw new Error(`Unsupported P6_PROFILE: ${profile}`);
  }
  const rpm = readInteger("P6_RPM", 15, 1, 500);
  const durationSeconds = readInteger("P6_DURATION_SECONDS", 60, 1, 3_600);
  const freeToken = profile === "pro" ? null : requiredEnv("P6_FREE_JWT");
  const proToken = profile === "free" ? null : requiredEnv("P6_PRO_JWT");
  const freeModel = Deno.env.get("GEMINI_FREE_MODEL")?.trim() ||
    "gemini-3.5-flash-lite";
  const proModels = new Set([
    Deno.env.get("GEMINI_PRO_MODEL")?.trim() || "gemini-3.7-flash",
    Deno.env.get("GEMINI_PRO_FALLBACK_MODEL")?.trim() || "gemini-3.6-flash",
  ]);

  const totalRequests = Math.ceil((rpm * durationSeconds) / 60);
  validateProfileSample(profile, totalRequests);
  const intervalMs = 60_000 / rpm;
  const startedAt = performance.now();
  const pending: Array<Promise<LoadResult>> = [];
  for (let index = 0; index < totalRequests; index += 1) {
    const scheduledAt = startedAt + index * intervalMs;
    const waitMs = scheduledAt - performance.now();
    if (waitMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, waitMs));
    }
    const tier = tierForRequest(profile, index);
    pending.push(sendScan(
      targetUrl,
      tier === "pro" ? proToken! : freeToken!,
      tier,
    ));
  }

  const summary = summarizeLoadResults(
    await Promise.all(pending),
    freeModel,
    proModels,
  );
  console.log(
    JSON.stringify({ profile, rpm, durationSeconds, ...summary }, null, 2),
  );
  if (!summary.passed) Deno.exitCode = 1;
}
