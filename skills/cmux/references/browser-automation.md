# Browser automation

Read this when you need to verify a UI, test a dev server, check rendered
output, debug a CSS issue, or interact with a running app from a script.

For the complete browser CLI surface, run `cmux browser --help` — what
follows is the path most tasks take.

## Open a browser split and capture the surface ref

```bash
# Returns: OK surface=surface:N pane=pane:M placement=split|reuse
BROWSER_OUT=$(cmux browser open-split "http://localhost:3000")
BROWSER_SURFACE=$(echo "$BROWSER_OUT" | sed -E 's/.*surface=(surface:[0-9]+).*/\1/')
```

`cmux browser open-split` does NOT accept a `--direction` flag — the daemon
silently ignores it. When direction matters, create the pane explicitly:

```bash
cmux new-pane --type browser --direction right --url "http://localhost:3000"
```

## Inspect and interact

A surface can be passed positionally (`cmux browser <surface> <subcommand>`)
or via `--surface <surface>`.

```bash
cmux browser "$BROWSER_SURFACE" snapshot --compact            # DOM (interactive elements)
cmux browser "$BROWSER_SURFACE" get text ".error-message"     # Extract text
cmux browser "$BROWSER_SURFACE" click "button.submit"         # Click element
cmux browser "$BROWSER_SURFACE" fill "#search" "query"        # Type into field
cmux browser "$BROWSER_SURFACE" wait --selector ".loaded"     # Wait for element
cmux browser "$BROWSER_SURFACE" eval "document.title"         # Run JS
cmux browser "$BROWSER_SURFACE" screenshot --out /tmp/v.png   # Capture screenshot
cmux browser "$BROWSER_SURFACE" console list                  # Browser console log
cmux browser "$BROWSER_SURFACE" errors list                   # Page errors
```

Other useful subcommands: `goto|navigate`, `back|forward|reload`, `dblclick`,
`hover`, `press`, `select`, `scroll`, `is visible|enabled|checked`,
`find role|text|…`, `dialog accept|dismiss`, `download`, `cookies`, `storage`,
`tab`, `frame`, `highlight`, `state save|load`.

## Cleanup

Don't leave idle browser surfaces open.

```bash
cmux close-surface --surface "$BROWSER_SURFACE"
```
