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

STALE_INTERPRETER="$(python3 - "$SETTINGS_FILE" "$VENV_PYTHON" "$BACKEND_SRC" <<'PYEOF'
import json
import sys

settings_file, venv_python, backend_src = sys.argv[1:4]


def strip_jsonc(text):
    """Strip // and /* */ comments (outside string literals) so VS Code
    settings.json, which allows comments and trailing commas, can be
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
    return "".join(out)


def strip_trailing_commas(text):
    """Drop a "," that is immediately followed (ignoring whitespace) by a
    closing "}" or "]" - legal in JSONC, rejected by json.loads. Comma
    characters inside string values are left untouched."""
    out = []
    in_string = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
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
        if c == ",":
            j = i + 1
            while j < n and text[j] in " \t\r\n":
                j += 1
            if j < n and text[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)


with open(settings_file) as f:
    raw = f.read()

settings = json.loads(strip_trailing_commas(strip_jsonc(raw)))

# Only these two keys are touched - everything else in the file is left as-is.
previous_interpreter = settings.get("python.defaultInterpreterPath")
settings["python.defaultInterpreterPath"] = venv_python

extra_paths = settings.get("python.analysis.extraPaths", [])
if backend_src not in extra_paths:
    extra_paths.append(backend_src)
settings["python.analysis.extraPaths"] = extra_paths

with open(settings_file, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")

# The VS Code / VSCodium Python extension only reads python.defaultInterpreterPath
# the first time it loads a workspace; once it has picked an interpreter for
# this workspace it ignores further changes to the setting. A settings.json
# that already pointed somewhere else means that has likely already happened,
# so tell the caller to warn the user instead of claiming the reload will work.
if previous_interpreter is not None and previous_interpreter != venv_python:
    print("stale")
PYEOF
)"

echo "Updated $SETTINGS_FILE:"
echo "  python.defaultInterpreterPath = $VENV_PYTHON"
echo "  python.analysis.extraPaths    includes \"$BACKEND_SRC\""

if [ "$STALE_INTERPRETER" = "stale" ]; then
    echo
    echo "warning: $SETTINGS_FILE already pointed at a different interpreter." >&2
    echo "VS Code/VSCodium's Python extension only reads python.defaultInterpreterPath" >&2
    echo "the first time it loads a workspace, so it may have already pinned the old" >&2
    echo "one and reloading won't switch it. Run 'Python: Select Interpreter' (or" >&2
    echo "'Python: Clear Workspace Interpreter Setting') from the command palette and" >&2
    echo "pick $VENV_PYTHON." >&2
else
    echo "Reload the VS Code/VSCodium window for it to take effect."
fi
