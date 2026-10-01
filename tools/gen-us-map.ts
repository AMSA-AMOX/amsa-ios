// Pre-projects the research page's US map exactly as research/page.tsx does at
// runtime (geoAlbersUsa().fitSize([975, 610]), Puerto Rico removed), so the iOS
// app renders identical geometry without shipping d3.
import { writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { geoAlbersUsa, geoPath } from "d3-geo";
import { feature } from "topojson-client";
import { webModule } from "./web-module";

const { FIPS_TO_ABBR } = await webModule<{ FIPS_TO_ABBR: Record<string, string> }>(
  "app/(dashboard)/dashboard/research/state-data.ts",
);

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, "../AMSA/Resources/Data/us-states.json");
const topo = JSON.parse(readFileSync(resolve(here, "node_modules/us-atlas/states-10m.json"), "utf8"));

const MAP_WIDTH = 975;
const MAP_HEIGHT = 610;

const all = feature(topo, topo.objects.states) as unknown as GeoJSON.FeatureCollection;
const mapFeatures: GeoJSON.FeatureCollection = {
  type: "FeatureCollection",
  features: all.features.filter((f) => String(f.id ?? "") !== "72"),
};

const projection = geoAlbersUsa().fitSize([MAP_WIDTH, MAP_HEIGHT], mapFeatures);
const pathBuilder = geoPath(projection);

const projected = mapFeatures.features.map((f) => {
  const fips = String(f.id ?? "");
  const [cx, cy] = pathBuilder.centroid(f);
  return {
    fips,
    abbr: FIPS_TO_ABBR[fips] ?? "",
    d: pathBuilder(f) ?? "",
    cx: Number.isFinite(cx) ? cx : null,
    cy: Number.isFinite(cy) ? cy : null,
  };
});

// Territories without an abbreviation (60, 66, 69, 78) fall outside AlbersUsa's
// extents: the web renders them as empty paths, so they are dropped here.
const unmapped = projected.filter((s) => !s.abbr);
const visibleUnmapped = unmapped.filter((s) => s.d !== "");
if (visibleUnmapped.length) throw new Error(`unmapped visible FIPS: ${visibleUnmapped.map((s) => s.fips).join(",")}`);
const states = projected.filter((s) => s.abbr);
if (states.length !== 51) throw new Error(`expected 51 shapes, got ${states.length}`);
const badCommands = states.filter((s) => /[^MLZ0-9.,\-e]/.test(s.d));
if (badCommands.length) throw new Error(`unexpected path commands in: ${badCommands.map((s) => s.abbr).join(",")}`);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ width: MAP_WIDTH, height: MAP_HEIGHT, states }) + "\n");
console.log(`wrote ${out} (${states.length} states)`);
