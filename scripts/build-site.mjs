import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const output = process.argv[2] ? resolve(process.argv[2]) : null;
if (!output) throw new Error("Usage: node scripts/build-site.mjs <output-directory>");

await mkdir(resolve(output, "assets"), { recursive: true });

const html = await readFile(resolve(root, "site/index.html"), "utf8");

await Promise.all([
  writeFile(resolve(output, "index.html"), html),
  copyFile(resolve(root, "site/styles.css"), resolve(output, "styles.css")),
  copyFile(resolve(root, "site/release.json"), resolve(output, "release.json")),
  copyFile(resolve(root, "site/assets/favicon.png"), resolve(output, "assets/favicon.png")),
  copyFile(resolve(root, "site/assets/studio-rendered.jpg"), resolve(output, "assets/studio-rendered.jpg")),
  copyFile(resolve(root, "site/assets/studio-catalog.jpg"), resolve(output, "assets/studio-catalog.jpg")),
]);

console.log(`Built Local AI Video Studio site at ${output}`);
