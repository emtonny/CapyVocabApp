import { HIERARCHY_SCHEMA_VERSION } from "./detection_hierarchy.ts";

export function buildScanPrompt(maxWords: number): string {
  const denseSceneTarget = Math.min(8, maxWords);

  return `Inspect the entire image systematically, including the center, edges, foreground, and background. Scan left to right and foreground to background before selecting the final items.

Build an internal inventory of all clearly visible independent objects and useful visible object parts. Then return as many distinct and confidently identifiable vocabulary items as possible, up to ${maxWords}.

When ${denseSceneTarget}-${maxWords} distinct items are clearly visible, do not stop after identifying only the most prominent objects. Do not ignore a smaller object solely because larger objects have already been selected.

There is no minimum required count. Do not invent, guess, or duplicate items to fill the result limit. Omit a candidate whenever the visual evidence is insufficient.

Prioritize independent objects first. Use remaining result slots for useful visible parts such as a door, handle, wheel, drawer, or keyboard, provided that the corresponding parent object is also returned.

When multiple visible instances share the same base object type, normally return only the single clearest representative.

Return more than one instance only when they are visually and semantically distinct subtypes that can be named confidently from directly observable evidence, such as "office chair" versus "dining chair", or "spray bottle" versus "water bottle".

Prefer established, natural subtype names over ad-hoc descriptions created only to make labels different. Use visible attributes such as color, material, pattern, shape, or size only when the distinction is unmistakable and materially useful for vocabulary learning. Material and relative size must not be inferred when the image does not provide reliable visual evidence.

Do not invent attributes, functions, brands, materials, or subtypes to fill the result limit. If instances are visually indistinguishable, return only one representative.

Return \`schema_version\` as the integer ${HIERARCHY_SCHEMA_VERSION}.

Assign each selected item a unique sequential number using the field \`number\`, starting from \`1\` and continuing in order (\`1, 2, 3, ...\`) with no duplicates or skipped numbers.

For each detection, also assign a unique immutable string \`id\` in response order (\`d1\`, \`d2\`, ...). The \`id\` is different from the display \`number\` and must never be duplicated. A \`parent_id\` always references \`id\`, never \`number\`.

Classify every detection with exactly one \`kind\`:
- \`object\`: an independently recognizable physical item. It stays an object when it is inside, on, or beside another object. Use \`parent_id: null\`.
- \`part\`: a visible physical component of another object returned in this same response. Use that parent object's \`id\` as \`parent_id\`.
- \`unknown\`: use only when visual evidence is insufficient to safely choose object or part. Use \`parent_id: null\`.

Spatial containment alone is not a parent-part relationship. A shirt inside a wardrobe is an \`object\` with no parent. A wardrobe door or drawer can be a \`part\` of the wardrobe. A bicycle wheel can be a \`part\` of the bicycle. A laptop keyboard can be a \`part\` of the laptop. Never return a part unless its object parent is also returned. Do not create part-of-part relationships.

For each detection, return: its \`number\`, \`id\`, \`kind\`, \`parent_id\`; a natural and accurate English name, lowercase and normally singular; its IPA pronunciation; an accurate, natural Vietnamese meaning that closely matches the actual detection shown; and its bounding box.

Use the most specific object name supported by the visual evidence, but do not infer or guess any subtype, brand, function, or characteristic that is not clearly visible in the image.

Bounding box coordinates must be INTEGERS from 0 to 1000, not decimal values from 0.0 to 1.0. \`x/y\` represent the top-left corner, and \`w/h\` represent the width and height relative to the full image dimensions.

Return the FULL and PIXEL-TIGHT bounding box of the entire visible object.

Each side of the box must closely follow the object's outermost visible pixels:
- left x: the object's leftmost visible point;
- right edge: the object's rightmost visible point;
- top y: the object's highest visible point;
- bottom edge: the object's lowest visible point.

Include the smallest possible amount of margin or background. Do not enlarge the box to include nearby, overlapping, or visually related objects. For transparent, hollow, or irregularly shaped objects, include only the object's own visible structure and full silhouette; do not treat objects visible through or behind it as part of the object.

Before returning each box, independently verify all four edges. Moving any edge inward must crop the target object, while moving it outward would add unnecessary background.

Return valid JSON only, with no additional explanation, and never return more than ${maxWords} elements in the \`words\` array.`;
}
