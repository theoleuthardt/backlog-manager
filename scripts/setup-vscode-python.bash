#!/bin/bash
set -euo pipefail

# Points VS Code/VSCodium's Python tooling (Pylance/Pyright, Pyrefly, ...) at
# backend/.venv instead of whatever "python" happens to resolve to on PATH -
# without this, every backend file shows "cannot find module" for anything
# installed in the venv (litestar, sqlalchemy, ...). .vscode/ is gitignored,
# so this has to be run once per machine/checkout rather than committed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="$REPO_ROOT/backend/.venv/bin/python"
BACKEND_SRC="$REPO_ROOT/backend/src"
SETTINGS_DIR="$REPO_ROOT/.vscode"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

if [ ! -x "$VENV_PYTHON" ]; then
    echo "error: $VENV_PYTHON not found or not executable - run 'task backend:install' first" >&2
    exit 1
fi

mkdir -p "$SETTINGS_DIR"
[ -f "$SETTINGS_FILE" ] || echo '{}' >"$SETTINGS_FILE"

python3 - "$SETTINGS_FILE" "$VENV_PYTHON" "$BACKEND_SRC" <<'PYEOF'
import json
import re
import sys

settings_file, venv_python, backend_src = sys.argv[1:4]


def strip_jsonc(text):
    """Strip // and /* */ comments (outside string literals) so VS Code's
    settings.json - which allows comments and trailing commas - can be
    parsed with the standard json module."""
    out = []
    in_string = in_line_comment = in_block_comment = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
                out.append(c)
            i += 1
            continue
        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(nxt)
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        out.append(c)
        i += 1
    # Trailing commas before a closing bracket/brace are also legal JSONC.
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


with open(settings_file) as f:
    raw = f.read()

settings = json.loads(strip_jsonc(raw))

# Only these two keys are touched - everything else in the file is left as-is.
settings["python.defaultInterpreterPath"] = venv_python

extra_paths = settings.get("python.analysis.extraPaths", [])
if backend_src not in extra_paths:
    extra_paths.append(backend_src)
settings["python.analysis.extraPaths"] = extra_paths

with open(settings_file, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")
PYEOF

echo "Updated $SETTINGS_FILE:"
echo "  python.defaultInterpreterPath = $VENV_PYTHON"
echo "  python.analysis.extraPaths    includes \"$BACKEND_SRC\""
echo "Reload the VS Code/VSCodium window for it to take effect."
echo "If the interpreter shown in the status bar doesn't switch after reload,"
echo "it was already pinned for this workspace - run 'Python: Select Interpreter'"
echo "(or 'Python: Clear Workspace Interpreter Setting') from the command palette"
echo "and pick $VENV_PYTHON."
