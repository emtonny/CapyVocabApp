import assert from "node:assert/strict";
import test from "node:test";

import {
  DEFAULT_BOUNDING_BOX_RATIO,
  shrinkBoundingBox,
} from "./bounding_box.ts";

test("shrinks both dimensions by the default ratio while preserving center", () => {
  assert.equal(DEFAULT_BOUNDING_BOX_RATIO, 0.5);
  assert.deepEqual(
    shrinkBoundingBox({ x: 100, y: 200, w: 400, h: 200 }),
    { x: 200, y: 250, w: 200, h: 100 },
  );
});

test("shrinks a full-image box to the centered middle quarter", () => {
  assert.deepEqual(
    shrinkBoundingBox({ x: 0, y: 0, w: 1000, h: 1000 }),
    { x: 250, y: 250, w: 500, h: 500 },
  );
});

test("keeps a box touching the bottom-right edges within image bounds", () => {
  assert.deepEqual(
    shrinkBoundingBox({ x: 900, y: 800, w: 100, h: 200 }),
    { x: 925, y: 850, w: 50, h: 100 },
  );
});

test("keeps the minimum one-unit size for a tiny edge object", () => {
  assert.deepEqual(
    shrinkBoundingBox({ x: 999, y: 999, w: 1, h: 1 }),
    { x: 999, y: 999, w: 1, h: 1 },
  );
});

test("supports a custom ratio without changing the default", () => {
  assert.deepEqual(
    shrinkBoundingBox({ x: 100, y: 100, w: 400, h: 200 }, 0.25),
    { x: 250, y: 175, w: 100, h: 50 },
  );
});

test("clamps a malformed full box before shrinking it", () => {
  assert.deepEqual(
    shrinkBoundingBox({ x: 950, y: 950, w: 100, h: 100 }),
    { x: 963, y: 963, w: 25, h: 25 },
  );
});

test("rejects ratios outside the shrink range", () => {
  assert.throws(() => shrinkBoundingBox({ x: 0, y: 0, w: 10, h: 10 }, 0));
  assert.throws(() => shrinkBoundingBox({ x: 0, y: 0, w: 10, h: 10 }, 1.1));
});
