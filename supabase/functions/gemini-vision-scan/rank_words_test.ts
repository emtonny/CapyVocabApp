import assert from "node:assert/strict";
import test from "node:test";

import {
  normalizeBoundingBox,
  rankWordsByBoxArea,
  readBoxArea,
} from "./bounding_box.ts";

test("normalizeBoundingBox converts box_2d [ymin, xmin, ymax, xmax] into {x, y, w, h}", () => {
  const result = normalizeBoundingBox({
    box_2d: [100, 200, 400, 700], // ymin: 100, xmin: 200, ymax: 400, xmax: 700
  });
  assert.deepEqual(result, {
    x: 200,
    y: 100,
    w: 500, // 700 - 200
    h: 300, // 400 - 100
  });
});

test("normalizeBoundingBox preserves box {x, y, w, h}", () => {
  const result = normalizeBoundingBox({
    box: { x: 50, y: 80, w: 120, h: 200 },
  });
  assert.deepEqual(result, {
    x: 50,
    y: 80,
    w: 120,
    h: 200,
  });
});

test("readBoxArea calculates area accurately or returns -1 for invalid records", () => {
  assert.equal(readBoxArea({ box: { w: 100, h: 200 } }), 20000);
  assert.equal(readBoxArea({ box_2d: [100, 200, 300, 400] }), 40000); // 200 * 200
  assert.equal(readBoxArea({ box: { w: 0, h: 0 } }), 0);
  assert.equal(readBoxArea({ box: { w: -10, h: 50 } }), -1);
  assert.equal(readBoxArea({ box: null }), -1);
  assert.equal(readBoxArea(null), -1);
});

test("rankWordsByBoxArea ranks items from smallest bounding box to largest", () => {
  const words = [
    { word: "desk", box: { x: 0, y: 0, w: 500, h: 400 } }, // area: 200,000
    { word: "pen", box: { x: 10, y: 10, w: 20, h: 50 } },   // area: 1,000
    { word: "book", box: { x: 20, y: 20, w: 100, h: 100 } }, // area: 10,000
  ];

  const ranked = rankWordsByBoxArea(words) as typeof words;

  assert.deepEqual(
    ranked.map((item) => item.word),
    ["pen", "book", "desk"],
  );
});

test("rankWordsByBoxArea preserves original order on area tie-break", () => {
  const words = [
    { word: "item-first", box: { x: 0, y: 0, w: 100, h: 100 } },  // area: 10,000
    { word: "item-second", box: { x: 50, y: 50, w: 100, h: 100 } }, // area: 10,000
  ];

  const ranked = rankWordsByBoxArea(words) as typeof words;

  assert.deepEqual(
    ranked.map((item) => item.word),
    ["item-first", "item-second"],
  );
});

test("when items exceed MAX_WORDS (12), slice(0, 12) retains smallest and drops largest", () => {
  const maxWords = 12;
  const words = Array.from({ length: 16 }, (_, index) => ({
    word: `object-${index}`,
    box: {
      x: index * 10,
      y: index * 10,
      w: (index + 1) * 10,
      h: (index + 1) * 10,
    },
  }));
  // object-0: 10x10=100 (smallest) ... object-15: 160x160=25600 (largest)

  // Shuffle or reverse order to test sorting independence
  const reversed = [...words].reverse();
  const ranked = rankWordsByBoxArea(reversed) as typeof words;
  const sliced = ranked.slice(0, maxWords);

  assert.equal(sliced.length, maxWords);

  // Assert smallest 12 are kept: object-0 to object-11
  const expectedKeptWords = Array.from(
    { length: maxWords },
    (_, index) => `object-${index}`,
  );
  assert.deepEqual(
    sliced.map((item) => item.word),
    expectedKeptWords,
  );

  // Assert largest 4 (object-12, object-13, object-14, object-15) are dropped
  const droppedWords = ["object-12", "object-13", "object-14", "object-15"];
  for (const dropped of droppedWords) {
    assert.ok(
      !sliced.some((item) => item.word === dropped),
      `Expected ${dropped} to be excluded`,
    );
  }
});

