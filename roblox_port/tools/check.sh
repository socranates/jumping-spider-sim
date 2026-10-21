#!/usr/bin/env bash
# types: luau-lsp analyze (strict) with the Rojo sourcemap; compile: luau-compile --null on every module.
# Usage: bash tools/check.sh types|compile  (needs $HOME/bin/rojo, $HOME/lsp/luau-lsp + globalTypes.d.luau, $HOME/luau/luau-compile; see .github/workflows/roblox-port.yml)
set -u
PORT="${PORT:-$(cd "$(dirname "$0")/.." && pwd)}"
export PATH="$HOME/bin:$PATH"
cd "$PORT" || exit 2
case "${1:-}" in
  types)
    rojo sourcemap default.project.json --output sourcemap.json >/dev/null || exit 2
    "$HOME/lsp/luau-lsp" analyze --sourcemap=sourcemap.json --definitions="$HOME/lsp/globalTypes.d.luau" \
      --ignore="**/tests/**" --no-strict-dm-types src
    ;;
  compile)
    n=0; ok=0
    while IFS= read -r f; do
      n=$((n+1))
      if "$HOME/luau/luau-compile" --null "$f" >/dev/null 2>"${TMPDIR:-/tmp}/compile_err.txt"; then ok=$((ok+1)); else echo "FAIL $f"; cat "${TMPDIR:-/tmp}/compile_err.txt"; fi
    done < <(find src -name '*.luau' | sort)
    echo "compile $ok/$n"
    [ "$ok" = "$n" ]
    ;;
  *) echo "usage: check.sh types|compile"; exit 2;;
esac
