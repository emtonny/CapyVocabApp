import assert from "node:assert/strict";
import test from "node:test";

import { buildScanPrompt } from "./scan_prompt.ts";

test("prompt requests broad coverage without requiring a fabricated minimum", () => {
  const prompt = buildScanPrompt(12);

  assert.match(prompt, /Inspect the entire image systematically/);
  assert.match(prompt, /Scan left to right and foreground to background/);
  assert.match(prompt, /When 8-12 distinct items are clearly visible/);
  assert.match(prompt, /do not stop after identifying only the most prominent/);
  assert.match(prompt, /There is no minimum required count/);
  assert.match(
    prompt,
    /Omit a candidate whenever the visual evidence is insufficient/,
  );
  assert.match(prompt, /Prioritize independent objects first/);
});

test("prompt allows only evidence-backed same-type subtypes", () => {
  const prompt = buildScanPrompt(12);

  assert.match(prompt, /visually and semantically distinct subtypes/);
  assert.match(prompt, /directly observable evidence/);
  assert.match(
    prompt,
    /Do not invent attributes, functions, brands, materials, or subtypes/,
  );
  assert.match(
    prompt,
    /visually indistinguishable, return only one representative/,
  );
  assert.match(prompt, /never return more than 12 elements/);
});
