import { access, readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const requiredFiles = [
  "site/index.html",
  "site/styles.css",
  "site/release.json",
  "Sources/StudioApp/Resources/AppIcon.png",
  "site/assets/studio-rendered.jpg",
  "site/assets/studio-catalog.jpg",
];

await Promise.all(requiredFiles.map((file) => access(resolve(root, file))));

const html = await readFile(resolve(root, "site/index.html"), "utf8");
const release = JSON.parse(await readFile(resolve(root, "site/release.json"), "utf8"));
const requiredCopy = [
  "Apple silicon Mac",
  "macOS 14 or newer",
  "Local and offline",
  "Contact pending",
  "Distribution build in preparation",
];

for (const copy of requiredCopy) {
  if (!html.includes(copy)) throw new Error(`Missing required release copy: ${copy}`);
}

if (release.schema !== "fleet.mac-release.v1") throw new Error("Unsupported release schema");
if (!release.version || !release.build) throw new Error("Release version and build are required");

if (release.downloadUrl !== null) {
  const gates = Object.values(release.trust ?? {});
  if (gates.length !== 4 || gates.some((value) => value !== true)) {
    throw new Error("A download URL requires every trust gate to pass");
  }
  if (!/^[a-f0-9]{64}$/i.test(release.sha256 ?? "")) {
    throw new Error("A download URL requires a valid SHA-256 checksum");
  }
  if (!release.supportUrl) throw new Error("A download URL requires a support URL");
}

const binaryUrls = html.match(/https?:[^\s"']+\.(?:dmg|pkg|zip)/gi) ?? [];
if (binaryUrls.length > 0 && release.downloadUrl === null) {
  throw new Error("The page exposes a binary URL while release metadata is closed");
}

console.log("Local AI Video Studio site check passed; binary distribution remains fail-closed.");
