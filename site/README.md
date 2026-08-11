# Local product-site preview

From the project root:

```bash
python3 -m http.server 4174
```

Then open `http://localhost:4174/site/`.

The source page is static and dependency-free. Its two web-ready product images
are high-quality RGB exports of tracked native design evidence;
`scripts/build-site.mjs` assembles a self-contained output directory for
deployment.

Run the deterministic release-readiness check with:

```bash
node scripts/check-site.mjs
```

`release.json` is deliberately fail-closed. A binary URL is rejected until all
four trust gates pass and the release has a checksum and support URL.
