import type { DetectionKind } from "./detection_hierarchy.ts";

export type DetectionRankingStrategy = "legacy_area" | "hierarchy_v2";

export interface DetectionRankingMetrics {
  strategy: DetectionRankingStrategy;
  inputCount: number;
  deduplicatedCount: number;
  selectedCount: number;
  selectedObjectCount: number;
  selectedPartCount: number;
  selectedFallbackCount: number;
  normalizedOrphanCount: number;
}

export interface DetectionRankingResult {
  words: unknown[];
  metrics: DetectionRankingMetrics;
}

interface IndexedDetection {
  record: Record<string, unknown>;
  index: number;
  normalizedWord: string;
  id: string;
  kind: DetectionKind;
  parentId: string | null;
  area: number;
  hasChildren: boolean;
}

export function selectLegacyDetections(
  words: unknown[],
  maxWords: number,
): DetectionRankingResult {
  const selected = deduplicateLegacyWords(rankWordsByBoxArea(words)).slice(
    0,
    maxWords,
  );
  return {
    words: selected,
    metrics: {
      strategy: "legacy_area",
      inputCount: words.length,
      deduplicatedCount: deduplicateLegacyWords(words).length,
      selectedCount: selected.length,
      selectedObjectCount: 0,
      selectedPartCount: 0,
      selectedFallbackCount: selected.length,
      normalizedOrphanCount: 0,
    },
  };
}

export function selectHierarchyDetections(
  words: Record<string, unknown>[],
  maxWords: number,
): DetectionRankingResult {
  const parentIds = new Set(
    words
      .filter((word) =>
        word.kind === "part" && typeof word.parent_id === "string"
      )
      .map((word) => word.parent_id as string),
  );
  const indexed = words.map((record, index) =>
    parseDetection(
      record,
      index,
      parentIds.has(record.id as string),
    )
  );
  const deduplicated = deduplicateHierarchyWords(indexed);
  const retainedObjectIds = new Set(
    deduplicated
      .filter((detection) => detection.kind === "object")
      .map((detection) => detection.id),
  );

  let normalizedOrphanCount = 0;
  const normalized = deduplicated.map((detection) => {
    if (
      detection.kind !== "part" ||
      (detection.parentId !== null && retainedObjectIds.has(detection.parentId))
    ) {
      return detection;
    }
    normalizedOrphanCount++;
    return {
      ...detection,
      record: {
        ...detection.record,
        kind: "unknown",
        parent_id: null,
      },
      kind: "unknown" as const,
      parentId: null,
    };
  });

  const objects = normalized
    .filter((detection) => detection.kind === "object")
    .sort(byResponseOrder);
  const selected = objects.slice(0, maxWords);
  const selectedObjectIds = new Set(selected.map((detection) => detection.id));

  if (selected.length < maxWords) {
    const parts = normalized
      .filter((detection) =>
        detection.kind === "part" &&
        detection.parentId !== null &&
        selectedObjectIds.has(detection.parentId)
      )
      .sort(byResponseOrder);
    selected.push(...parts.slice(0, maxWords - selected.length));
  }

  if (selected.length < maxWords) {
    const fallback = normalized
      .filter((detection) => detection.kind === "unknown")
      .sort(byAreaThenResponseOrder);
    selected.push(...fallback.slice(0, maxWords - selected.length));
  }

  return {
    words: selected.map((detection) => detection.record),
    metrics: {
      strategy: "hierarchy_v2",
      inputCount: words.length,
      deduplicatedCount: deduplicated.length,
      selectedCount: selected.length,
      selectedObjectCount: selected.filter((word) => word.kind === "object")
        .length,
      selectedPartCount: selected.filter((word) => word.kind === "part")
        .length,
      selectedFallbackCount: selected.filter((word) => word.kind === "unknown")
        .length,
      normalizedOrphanCount,
    },
  };
}

function parseDetection(
  record: Record<string, unknown>,
  index: number,
  hasChildren: boolean,
): IndexedDetection {
  const id = typeof record.id === "string" ? record.id : "";
  const kind = isDetectionKind(record.kind) ? record.kind : "unknown";
  const parentId = typeof record.parent_id === "string"
    ? record.parent_id
    : null;
  return {
    record,
    index,
    normalizedWord: normalizeWord(record.word),
    id,
    kind,
    parentId,
    area: readBoxArea(record),
    hasChildren,
  };
}

function deduplicateHierarchyWords(
  detections: IndexedDetection[],
): IndexedDetection[] {
  const order: string[] = [];
  const preferredByWord = new Map<string, IndexedDetection>();

  for (const detection of detections) {
    const key = detection.normalizedWord || `\u0000${detection.index}`;
    const current = preferredByWord.get(key);
    if (!current) {
      order.push(key);
      preferredByWord.set(key, detection);
      continue;
    }
    if (compareDuplicatePreference(detection, current) < 0) {
      preferredByWord.set(key, detection);
    }
  }

  return order.map((key) => preferredByWord.get(key)!);
}

function compareDuplicatePreference(
  first: IndexedDetection,
  second: IndexedDetection,
): number {
  if (first.hasChildren !== second.hasChildren) {
    return first.hasChildren ? -1 : 1;
  }
  const byKind = kindPriority(first.kind) - kindPriority(second.kind);
  if (byKind !== 0) return byKind;
  const byArea = second.area - first.area;
  if (byArea !== 0) return byArea;
  return first.index - second.index;
}

function kindPriority(kind: DetectionKind): number {
  switch (kind) {
    case "object":
      return 0;
    case "part":
      return 1;
    case "unknown":
      return 2;
  }
}

function byResponseOrder(
  first: IndexedDetection,
  second: IndexedDetection,
): number {
  return first.index - second.index;
}

function byAreaThenResponseOrder(
  first: IndexedDetection,
  second: IndexedDetection,
): number {
  return second.area - first.area || first.index - second.index;
}

function rankWordsByBoxArea(words: unknown[]): unknown[] {
  return words
    .map((word, index) => ({ word, index, area: readBoxArea(word) }))
    .sort((first, second) =>
      second.area - first.area || first.index - second.index
    )
    .map(({ word }) => word);
}

function deduplicateLegacyWords(words: unknown[]): unknown[] {
  const seenWords = new Set<string>();
  return words.filter((item) => {
    if (!item || typeof item !== "object") return true;
    const word = (item as Record<string, unknown>).word;
    if (typeof word !== "string") return true;
    const normalizedWord = normalizeWord(word);
    if (!normalizedWord) return false;
    if (seenWords.has(normalizedWord)) return false;
    seenWords.add(normalizedWord);
    return true;
  });
}

function normalizeWord(word: unknown): string {
  return typeof word === "string" ? word.trim().toLowerCase() : "";
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

function isDetectionKind(value: unknown): value is DetectionKind {
  return value === "object" || value === "part" || value === "unknown";
}
