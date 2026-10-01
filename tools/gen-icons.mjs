// Copies inline <svg> icons verbatim from the web source into
// AMSA/Resources/Assets.xcassets/Icons/<name>.imageset as template images.
// Each manifest entry locates the <svg> that contains `match` (a unique snippet
// of its path data) in `file`, so geometry and stroke width are never retyped.
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "../reference-amsa-website/src");
const outDir = resolve(here, "../AMSA/Resources/Assets.xcassets/Icons");
const manifest = JSON.parse(readFileSync(resolve(here, "icons.json"), "utf8"));

const ATTR_RENAMES = {
  strokeWidth: "stroke-width",
  strokeLinecap: "stroke-linecap",
  strokeLinejoin: "stroke-linejoin",
  strokeMiterlimit: "stroke-miterlimit",
  fillRule: "fill-rule",
  clipRule: "clip-rule",
  fillOpacity: "fill-opacity",
  strokeOpacity: "stroke-opacity",
};
const DROP = new Set(["className", "style", "key", "xmlns", "aria-hidden", "ariaHidden", "focusable", "role", "onClick"]);

const KNOWN = new Set([
  "viewBox", "fill", "stroke", "strokeWidth", "strokeLinecap", "strokeLinejoin", "strokeMiterlimit", "fillRule",
  "clipRule", "fillOpacity", "strokeOpacity", "opacity", "d", "cx", "cy", "r", "rx", "ry", "x", "y", "x1", "y1",
  "x2", "y2", "width", "height", "points", "transform", "stroke-width", "stroke-linecap", "stroke-linejoin",
  "fill-rule", "clip-rule", ...DROP,
]);

/** Removes `name={…}` expressions with balanced braces (template-literal classNames contain `${…}`). */
function stripExpressionAttrs(text) {
  let out = "";
  let i = 0;
  while (i < text.length) {
    const m = /^([a-zA-Z_:][\w:.-]*)\s*=\s*\{/.exec(text.slice(i));
    if (m && DROP.has(m[1])) {
      let depth = 0;
      let j = i + m[0].length - 1;
      for (; j < text.length; j++) {
        if (text[j] === "{") depth++;
        else if (text[j] === "}" && --depth === 0) break;
      }
      i = j + 1;
      continue;
    }
    out += text[i++];
  }
  return out;
}

/** Parses JSX attributes: name="v" | name={v} | name={"v"} | bare. */
function parseAttrs(raw) {
  const text = stripExpressionAttrs(raw);
  const attrs = {};
  const re = /([a-zA-Z_:][\w:.-]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|\{\s*(?:"([^"]*)"|'([^']*)'|([^{}]*?))\s*\}))?/g;
  let m;
  while ((m = re.exec(text))) {
    const [, name, dq, sq, bdq, bsq, expr] = m;
    const value = dq ?? sq ?? bdq ?? bsq ?? (expr !== undefined ? expr.trim() : "true");
    if (!KNOWN.has(name)) throw new Error(`unexpected attribute "${name}" in: ${raw.trim().slice(0, 120)}`);
    attrs[name] = value;
  }
  return attrs;
}

function svgAttrString(attrs, overrides = {}) {
  const out = [];
  for (const [name, raw] of Object.entries({ ...attrs, ...overrides })) {
    if (DROP.has(name)) continue;
    let value = String(raw);
    if (!/^[-\w.#%\s,]+$/.test(value) && !/^[MmLlHhVvCcSsQqTtAaZz0-9.,\s-]+$/.test(value)) {
      throw new Error(`dynamic attribute ${name}={${value}} — add an override in icons.json`);
    }
    if (value === "currentColor") value = "#000000";
    out.push(`${ATTR_RENAMES[name] ?? name}="${value}"`);
  }
  return out.join(" ");
}

function extract(entry) {
  const src = readFileSync(resolve(web, entry.file), "utf8");
  let at = -1;
  let from = 0;
  for (let n = 0; n <= (entry.occurrence ?? 0); n++) {
    at = src.indexOf(entry.match, from);
    if (at < 0) throw new Error(`${entry.name}: "${entry.match}" not found in ${entry.file}`);
    from = at + 1;
  }
  const start = src.lastIndexOf("<svg", at);
  const end = src.indexOf("</svg>", at);
  if (start < 0 || end < 0) throw new Error(`${entry.name}: enclosing <svg> not found`);
  const svg = src.slice(start, end + "</svg>".length);
  const openEnd = svg.indexOf(">");
  const rootAttrs = parseAttrs(svg.slice(4, openEnd));
  const inner = svg.slice(openEnd + 1, -"</svg>".length);

  const children = [];
  const childRe = /<(path|circle|rect|line|polyline|polygon|ellipse)\b([^>]*?)\/?>/g;
  let m;
  while ((m = childRe.exec(inner))) children.push(`<${m[1]} ${svgAttrString(parseAttrs(m[2]), entry.childOverrides ?? {})}/>`);
  if (!children.length) throw new Error(`${entry.name}: no drawable children`);

  const viewBox = entry.viewBox ?? rootAttrs.viewBox ?? "0 0 24 24";
  const [, , w, h] = viewBox.split(/\s+/).map(Number);
  const root = { ...rootAttrs, ...(entry.rootOverrides ?? {}) };
  delete root.viewBox;
  delete root.width;
  delete root.height;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${viewBox}" ${svgAttrString(root)}>\n  ${children.join("\n  ")}\n</svg>\n`;
}

// Regenerate from scratch so removed entries disappear.
mkdirSync(outDir, { recursive: true });
for (const name of readdirSync(outDir)) if (name.endsWith(".imageset")) rmSync(resolve(outDir, name), { recursive: true });
writeFileSync(
  resolve(outDir, "Contents.json"),
  JSON.stringify({ info: { author: "xcode", version: 1 }, properties: { "provides-namespace": true } }, null, 2) + "\n",
);

const seen = new Set();
for (const entry of manifest) {
  if (seen.has(entry.name)) throw new Error(`duplicate icon name ${entry.name}`);
  seen.add(entry.name);
  const svg = entry.svg ?? extract(entry);
  const dir = resolve(outDir, `${entry.name}.imageset`);
  mkdirSync(dir, { recursive: true });
  writeFileSync(resolve(dir, `${entry.name}.svg`), svg);
  writeFileSync(
    resolve(dir, "Contents.json"),
    JSON.stringify(
      {
        images: [{ filename: `${entry.name}.svg`, idiom: "universal" }],
        info: { author: "xcode", version: 1 },
        properties: { "preserves-vector-representation": true, "template-rendering-intent": "template" },
      },
      null,
      2,
    ) + "\n",
  );
}
console.log(`wrote ${manifest.length} icons`);
