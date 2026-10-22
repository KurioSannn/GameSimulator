// Triangulate projected polygons (with holes) for the game map mesh. Offline build step only.
//   node scripts/pipelines/game/triangulate_rings.mjs <in.json> <out.json>
// in:  {"parts": [{"rings": [[x0,y0,x1,y1,...], [hole...], ...]}, ...]}  (rings without closing vertex)
// out: {"parts": [{"tris": [i0,i1,i2,...], "deviation": d}, ...]}
//      indices are local to the part (vertex k = k-th vertex of the concatenated rings)
// Uses earcut 3.2.3 (pinned in tools/geo/package.json). earcut handles holes by bridging them
// into the outer ring; `deviation` = |polygon area - triangle area| / polygon area (0 = exact).
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const mod = await import(pathToFileURL(resolve(root, "tools/geo/node_modules/earcut/src/earcut.js")).href);
const earcut = mod.default;
const deviation = mod.deviation;

const [, , inPath, outPath] = process.argv;
const input = JSON.parse(readFileSync(inPath, "utf8"));
const out = [];
for (const part of input.parts) {
  const flat = [];
  const holes = [];
  part.rings.forEach((ring, i) => {
    if (i > 0) holes.push(flat.length / 2);
    for (const v of ring) flat.push(v);
  });
  const tris = earcut(flat, holes.length ? holes : null, 2);
  out.push({ tris, deviation: deviation(flat, holes.length ? holes : null, 2, tris) });
}
writeFileSync(outPath, JSON.stringify({ parts: out }));
