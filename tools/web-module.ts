// Imports a module from the read-only web source. That package is CommonJS
// (no "type": "module"), so tsx exposes its exports under `default`.
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const web = resolve(dirname(fileURLToPath(import.meta.url)), "../reference-amsa-website/src");

export async function webModule<T>(path: string): Promise<T> {
  const mod = await import(pathToFileURL(resolve(web, path)).href);
  return (mod.default && typeof mod.default === "object" ? { ...mod.default, ...mod } : mod) as T;
}
