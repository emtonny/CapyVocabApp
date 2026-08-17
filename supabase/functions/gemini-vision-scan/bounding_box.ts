export interface BoundingBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export const DEFAULT_BOUNDING_BOX_RATIO = 0.5;

const MIN_COORDINATE = 0;
const MAX_COORDINATE = 1000;
const MIN_BOX_SIZE = 1;

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
