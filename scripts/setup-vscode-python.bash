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
import sys

settings_file, venv_python, backend_src = sys.argv[1:4]

with open(settings_file) as f:
    settings = json.load(f)

# Only these two keys are touched - everything else in the file is left as-is.
settings["python.defaultInterpreterPath"] = venv_python
settings["python.analysis.extraPaths"] = [backend_src]

with open(settings_file, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")
PYEOF

echo "Updated $SETTINGS_FILE:"
echo "  python.defaultInterpreterPath = $VENV_PYTHON"
echo "  python.analysis.extraPaths    = [\"$BACKEND_SRC\"]"
echo "Reload the VS Code/VSCodium window for it to take effect."
