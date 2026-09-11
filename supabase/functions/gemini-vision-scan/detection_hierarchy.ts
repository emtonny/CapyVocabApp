export const HIERARCHY_SCHEMA_VERSION = 2;
export const DETECTION_KINDS = ["object", "part", "unknown"] as const;

export type DetectionKind = typeof DETECTION_KINDS[number];

export interface HierarchyValidationMetrics {
  duplicateIdCount: number;
  normalizedRelationshipCount: number;
}

export interface NormalizedHierarchyResponse {
  response: Record<string, unknown> & {
    schema_version: typeof HIERARCHY_SCHEMA_VERSION;
    words: Record<string, unknown>[];
  };
  metrics: HierarchyValidationMetrics;
}

export class GeminiHierarchyShapeError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GeminiHierarchyShapeError";
  }
}

interface ParsedDetection {
  record: Record<string, unknown>;
  id: string;
  kind: DetectionKind;
  parentId: string | null;
}

export function normalizeVersion2Hierarchy(
  value: unknown,
): NormalizedHierarchyResponse {
  if (!isRecord(value)) {
    throw new GeminiHierarchyShapeError("Response must be an object");
  }
  if (value.schema_version !== HIERARCHY_SCHEMA_VERSION) {
    throw new GeminiHierarchyShapeError(
      `schema_version must be ${HIERARCHY_SCHEMA_VERSION}`,
    );
  }
  if (!Array.isArray(value.words)) {
    throw new GeminiHierarchyShapeError("words must be an array");
  }

  const parsedWords = value.words.map(parseDetectionShape);
  const idCounts = countIds(parsedWords);
  const ambiguousIds = new Set(
    [...idCounts.entries()]
      .filter(([, count]) => count > 1)
      .map(([id]) => id),
  );
  const usedIds = new Set<string>();
  let duplicateIdCount = 0;

  const uniqueWords = parsedWords.map((detection, index) => {
    let id = detection.id;
    if (usedIds.has(id)) {
      duplicateIdCount++;
      id = nextFallbackId(index, usedIds);
    }
    usedIds.add(id);
    return { ...detection, id };
  });
  const kindById = new Map(
    uniqueWords.map((detection) => [detection.id, detection.kind]),
  );
  let normalizedRelationshipCount = 0;

  const words = uniqueWords.map((detection) => {
    const hasValidParent = detection.kind === "part" &&
      detection.parentId !== null &&
      detection.parentId !== detection.id &&
      !ambiguousIds.has(detection.parentId) &&
      kindById.get(detection.parentId) === "object";
    const hasValidNoParent = detection.kind !== "part" &&
      detection.parentId === null;

    if (hasValidParent || hasValidNoParent) {
      return {
        ...detection.record,
        id: detection.id,
        kind: detection.kind,
        parent_id: detection.parentId,
      };
    }

    normalizedRelationshipCount++;
    return {
      ...detection.record,
      id: detection.id,
      kind: "unknown",
      parent_id: null,
    };
  });

  return {
    response: {
      ...value,
      schema_version: HIERARCHY_SCHEMA_VERSION,
      words,
    },
    metrics: { duplicateIdCount, normalizedRelationshipCount },
  };
}

function parseDetectionShape(
  value: unknown,
  index: number,
): ParsedDetection {
  if (!isRecord(value)) {
    throw new GeminiHierarchyShapeError(`words[${index}] must be an object`);
  }

  const id = value.id;
  if (typeof id !== "string" || id.trim().length === 0) {
    throw new GeminiHierarchyShapeError(
      `words[${index}].id must be a non-empty string`,
    );
  }

  const kind = value.kind;
  if (!isDetectionKind(kind)) {
    throw new GeminiHierarchyShapeError(
      `words[${index}].kind must be object, part, or unknown`,
    );
  }

  const parentId = value.parent_id;
  if (
    parentId !== null &&
    (typeof parentId !== "string" || parentId.trim().length === 0)
  ) {
    throw new GeminiHierarchyShapeError(
      `words[${index}].parent_id must be null or a non-empty string`,
    );
  }

  return {
    record: value,
    id: id.trim(),
    kind,
    parentId: typeof parentId === "string" ? parentId.trim() : null,
  };
}

function countIds(words: ParsedDetection[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const word of words) {
    counts.set(word.id, (counts.get(word.id) ?? 0) + 1);
  }
  return counts;
}

function nextFallbackId(index: number, usedIds: Set<string>): string {
  let suffix = index + 1;
  let candidate = `server-d${suffix}`;
  while (usedIds.has(candidate)) {
    candidate = `server-d${++suffix}`;
  }
  return candidate;
}

function isDetectionKind(value: unknown): value is DetectionKind {
  return typeof value === "string" &&
    (DETECTION_KINDS as readonly string[]).includes(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
