#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

godot_bin="${GODOT:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
	if [[ -x "${HOME}/.local/bin/godot" ]]; then
		godot_bin="${HOME}/.local/bin/godot"
	else
		echo "godot 4.7.2 stable must be on PATH" >&2
		exit 1
	fi
fi

version="$("$godot_bin" --version)"
case "$version" in
	4.7.2.stable*) ;;
	*)
		echo "Godot 4.7.2 stable is required, found ${version}" >&2
		exit 1
		;;
esac

mkdir -p build/web/web
"$godot_bin" --headless --path . --export-release "Web" build/web/index.html
cp -f web/host.css web/host.js build/web/web/
test -f build/web/index.html
