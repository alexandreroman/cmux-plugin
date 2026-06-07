---
name: open-browser
description: Open a browser split pane alongside the current terminal and navigate to the dev server or a specified URL. Use for visual verification of UI, debugging layout issues, or testing a running app. Arguments: optional URL (defaults to http://localhost:3000).
argument-hint: "[url]"
---

Open a cmux browser split for visual verification.

1. Check we're inside cmux — if not, explain that this requires cmux and stop.
2. Resolve the URL: `$ARGUMENTS` if provided, otherwise `http://localhost:3000`.
   If `$ARGUMENTS` also names something to check (e.g. "localhost:8080 check the
   nav"), extract both the URL and the intent.
3. Open the browser split at that URL and capture the returned surface ref
   (`open-split` opens directly at the URL; it does not take a `--direction`
   flag):
   ```bash
   OUT=$(cmux browser open-split "<url>")
   SURFACE=$(echo "$OUT" | sed -E 's/.*surface=(surface:[0-9]+).*/\1/')
   ```
4. Confirm the page loaded: `cmux browser "$SURFACE" snapshot --compact`.
5. Report what you see — page title, any visible errors, key UI elements (and
   the requested intent, if one was given).
