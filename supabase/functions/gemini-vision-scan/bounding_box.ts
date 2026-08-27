export interface BoundingBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export const DEFAULT_BOUNDING_BOX_RATIO = 0.25;

const MIN_COORDINATE = 0;
const MAX_COORDINATE = 1000;
const MIN_BOX_SIZE = 1;

export function normalizeBoundingBox(raw: unknown): BoundingBox | null {
  if (!raw || typeof raw !== "object") return null;

  const record = raw as {
    box_2d?: unknown;
    box?: unknown;
  };

  // Case 1: box_2d: [ymin, xmin, ymax, xmax] (or box: [ymin, xmin, ymax, xmax])
  const candidateArray = Array.isArray(record.box_2d)
    ? record.box_2d
    : Array.isArray(record.box)
    ? record.box
    : null;

  if (candidateArray && candidateArray.length >= 4) {
    const [ymin, xmin, ymax, xmax] = candidateArray.map((v) =>
      typeof v === "number" && Number.isFinite(v) ? v : 0
    );
    const top = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.min(ymin, ymax)));
    const bottom = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.max(ymin, ymax)));
    const left = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.min(xmin, xmax)));
    const right = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.max(xmin, xmax)));

    return {
      x: left,
      y: top,
      w: Math.max(MIN_BOX_SIZE, right - left),
      h: Math.max(MIN_BOX_SIZE, bottom - top),
    };
  }

  // Case 2: box: { x, y, w, h } or box_2d: { x, y, w, h }
  const boxObj = (typeof record.box === "object" && record.box !== null && !Array.isArray(record.box))
    ? (record.box as Record<string, unknown>)
    : (typeof record.box_2d === "object" && record.box_2d !== null && !Array.isArray(record.box_2d))
    ? (record.box_2d as Record<string, unknown>)
    : null;

  if (boxObj) {
    if (
      typeof boxObj.w === "number" &&
      typeof boxObj.h === "number" &&
      Number.isFinite(boxObj.w) &&
      Number.isFinite(boxObj.h)
    ) {
      const xVal = typeof boxObj.x === "number" && Number.isFinite(boxObj.x) ? boxObj.x : 0;
      const yVal = typeof boxObj.y === "number" && Number.isFinite(boxObj.y) ? boxObj.y : 0;
      return {
        x: clamp(Math.round(xVal), MIN_COORDINATE, MAX_COORDINATE - MIN_BOX_SIZE),
        y: clamp(Math.round(yVal), MIN_COORDINATE, MAX_COORDINATE - MIN_BOX_SIZE),
        w: Math.max(MIN_BOX_SIZE, clamp(Math.round(boxObj.w), MIN_BOX_SIZE, MAX_COORDINATE)),
        h: Math.max(MIN_BOX_SIZE, clamp(Math.round(boxObj.h), MIN_BOX_SIZE, MAX_COORDINATE)),
      };
    }

    if (
      typeof boxObj.ymin === "number" &&
      typeof boxObj.xmin === "number" &&
      typeof boxObj.ymax === "number" &&
      typeof boxObj.xmax === "number" &&
      Number.isFinite(boxObj.ymin) &&
      Number.isFinite(boxObj.xmin) &&
      Number.isFinite(boxObj.ymax) &&
      Number.isFinite(boxObj.xmax)
    ) {
      const top = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.min(boxObj.ymin, boxObj.ymax)));
      const bottom = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.max(boxObj.ymin, boxObj.ymax)));
      const left = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.min(boxObj.xmin, boxObj.xmax)));
      const right = Math.max(MIN_COORDINATE, Math.min(MAX_COORDINATE, Math.max(boxObj.xmin, boxObj.xmax)));
      return {
        x: left,
        y: top,
        w: Math.max(MIN_BOX_SIZE, right - left),
        h: Math.max(MIN_BOX_SIZE, bottom - top),
      };
    }
  }

  return null;
}

export function shrinkBoundingBox(
  fullBox: BoundingBox,
  ratio = DEFAULT_BOUNDING_BOX_RATIO,
): BoundingBox {
  if (!Number.isFinite(ratio) || ratio <= 0 || ratio > 1) {
    throw new RangeError("ratio must be greater than 0 and at most 1");
  }

  const left = clamp(
    Math.round(finiteOr(fullBox.x, MIN_COORDINATE)),
    MIN_COORDINATE,
    MAX_COORDINATE - MIN_BOX_SIZE,
  );
  const top = clamp(
    Math.round(finiteOr(fullBox.y, MIN_COORDINATE)),
    MIN_COORDINATE,
    MAX_COORDINATE - MIN_BOX_SIZE,
  );
  const fullWidth = normalizedExtent(fullBox.w, left);
  const fullHeight = normalizedExtent(fullBox.h, top);
  const width = clamp(
    Math.round(fullWidth * ratio),
    MIN_BOX_SIZE,
    fullWidth,
  );
  const height = clamp(
    Math.round(fullHeight * ratio),
    MIN_BOX_SIZE,
    fullHeight,
  );
  const x = clamp(
    Math.round(left + (fullWidth - width) / 2),
    MIN_COORDINATE,
    MAX_COORDINATE - width,
  );
  const y = clamp(
    Math.round(top + (fullHeight - height) / 2),
    MIN_COORDINATE,
    MAX_COORDINATE - height,
  );

  return { x, y, w: width, h: height };
}

function normalizedExtent(value: number, start: number): number {
  const requestedExtent = Math.max(
    MIN_BOX_SIZE,
    Math.round(finiteOr(value, MIN_BOX_SIZE)),
  );
  return clamp(
    requestedExtent,
    MIN_BOX_SIZE,
    MAX_COORDINATE - start,
  );
}

function finiteOr(value: number, fallback: number): number {
  return Number.isFinite(value) ? value : fallback;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

export function rankWordsByBoxArea(words: unknown[]): unknown[] {
  return words
    .map((word, index) => ({
      word,
      index,
      area: readBoxArea(word),
      normalizedBox: normalizeBoundingBox(word),
    }))
    .sort((first, second) =>
      first.area - second.area || first.index - second.index
    )
    .map(({ word, normalizedBox }) => {
      if (normalizedBox && typeof word === "object" && word !== null) {
        const { box_2d: _, ...rest } = word as Record<string, unknown>;
        return {
          ...rest,
          box: normalizedBox,
        };
      }
      return word;
    });
}

export function readBoxArea(word: unknown): number {
  if (!word || typeof word !== "object") return -1;
  const record = word as { box?: unknown; box_2d?: unknown };
  if (record.box && typeof record.box === "object" && !Array.isArray(record.box)) {
    const { w, h } = record.box as { w?: unknown; h?: unknown };
    if (typeof w === "number" && typeof h === "number") {
      if (!Number.isFinite(w) || !Number.isFinite(h)) return -1;
      if (w < 0 || h < 0) return -1;
      return w * h;
    }
  }
  const normalized = normalizeBoundingBox(word);
  if (!normalized) return -1;
  return normalized.w * normalized.h;
}

