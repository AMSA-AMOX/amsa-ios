// Extracts static datasets from the web source into AMSA/Resources/Data/*.json.
// Exported constants are imported directly; non-exported ones are pulled out of
// the source text as literals and evaluated, so nothing is hand-transcribed.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { webModule } from "./web-module";

type StateInfo = {
  name: string; cities: string[]; colTier: string; monthlyRent: string; climate: string;
  tempRange: string; publicTransport: string; transitInfo: string; places: string[];
};
const { STATE_DATA, FIPS_TO_ABBR } = await webModule<{
  STATE_DATA: Record<string, StateInfo>;
  FIPS_TO_ABBR: Record<string, string>;
}>("app/(dashboard)/dashboard/research/state-data.ts");
const { STATE_NAMES } = await webModule<{ STATE_NAMES: Record<string, string> }>(
  "app/(dashboard)/dashboard/research/state-names.ts",
);
const { POST_TOPICS } = await webModule<{ POST_TOPICS: readonly string[] }>("components/posts/types.ts");

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "../reference-amsa-website/src");
const outDir = resolve(here, "../AMSA/Resources/Data");

/** Evaluates `const NAME ... = <literal>;` from a source file. The literal must be pure data. */
function literal<T>(file: string, name: string): T {
  const src = readFileSync(resolve(web, file), "utf8");
  const start = src.search(new RegExp(`const ${name}\\b[^=]*=\\s*`));
  if (start < 0) throw new Error(`${name} not found in ${file}`);
  const from = src.indexOf("=", start) + 1;
  // Walk brackets to find the end of the literal.
  let i = from;
  while (/\s/.test(src[i])) i++;
  const open = src[i];
  const close = open === "{" ? "}" : open === "[" ? "]" : null;
  if (!close) throw new Error(`${name}: unsupported literal start ${open}`);
  let depth = 0;
  let inStr: string | null = null;
  for (let j = i; j < src.length; j++) {
    const ch = src[j];
    if (inStr) {
      if (ch === "\\") j++;
      else if (ch === inStr) inStr = null;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === "`") inStr = ch;
    else if (ch === open) depth++;
    else if (ch === close && --depth === 0) {
      const text = src.slice(i, j + 1);
      return new Function(`return (${text});`)() as T;
    }
  }
  throw new Error(`${name}: unterminated literal`);
}

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(msg);
}

// ── States ────────────────────────────────────────────────────────────────────
type StateSvg = { file: string; location: string };
const STATE_SVG = literal<Record<string, StateSvg>>("app/(dashboard)/dashboard/places/page.tsx", "STATE_SVG");
const abbrToFips = Object.fromEntries(Object.entries(FIPS_TO_ABBR).map(([fips, abbr]) => [abbr, fips]));

const stateAbbrs = Object.keys(STATE_DATA);
assert(stateAbbrs.length === 51, `STATE_DATA: expected 51, got ${stateAbbrs.length}`);
assert(Object.keys(STATE_SVG).length === 51, "STATE_SVG: expected 51");
assert(Object.keys(FIPS_TO_ABBR).length === 51, "FIPS_TO_ABBR: expected 51");
assert(Object.keys(STATE_NAMES).length === 51, "STATE_NAMES: expected 51");

const states = stateAbbrs.map((abbr) => {
  const info = STATE_DATA[abbr];
  assert(STATE_NAMES[abbr] === info.name, `name mismatch for ${abbr}`);
  assert(STATE_SVG[abbr], `no photo for ${abbr}`);
  assert(abbrToFips[abbr], `no fips for ${abbr}`);
  return { abbr, fips: abbrToFips[abbr], ...info, photo: STATE_SVG[abbr] };
});

// ── Constants ─────────────────────────────────────────────────────────────────
const standardFields = literal<string[]>("app/(dashboard)/dashboard/research/page.tsx", "STANDARD_FIELDS");
const placeReviewPrompts = literal<string[]>("app/(dashboard)/dashboard/places/[abbr]/page.tsx", "PLACE_REVIEW_PROMPTS");
const collegeReviewPrompts = literal<string[]>(
  "app/(dashboard)/dashboard/research/college/[id]/page.tsx",
  "COLLEGE_REVIEW_PROMPTS",
);
assert(standardFields.length === 60, `STANDARD_FIELDS: expected 60, got ${standardFields.length}`);
assert(POST_TOPICS.length === 20, "POST_TOPICS: expected 20");
assert(placeReviewPrompts.length === 6 && collegeReviewPrompts.length === 6, "review prompts: expected 6 + 6");

const constants = {
  standardFields,
  postTopics: [...POST_TOPICS],
  placeReviewPrompts,
  collegeReviewPrompts,
};

// ── Logo lookup aliases ───────────────────────────────────────────────────────
// Ordered [name, domain] pairs: getKnownSchoolDomain's prefix match returns the
// first hit in insertion order, which a Swift Dictionary would not preserve.
const logoAliases = {
  schools: Object.entries(literal<Record<string, string>>("lib/logo-lookup.ts", "SCHOOL_DOMAIN_ALIASES")),
  companies: Object.entries(literal<Record<string, string>>("lib/logo-lookup.ts", "COMPANY_DOMAIN_ALIASES")),
};

mkdirSync(outDir, { recursive: true });
const write = (name: string, data: unknown) => {
  writeFileSync(resolve(outDir, name), JSON.stringify(data, null, 2) + "\n");
  console.log(`wrote ${name}`);
};
write("states.json", states);
write("constants.json", constants);
write("logo-aliases.json", logoAliases);
