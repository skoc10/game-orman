#!/usr/bin/env bash
# Birim testlerini headless çalıştırır. Önce import ile sınıf önbelleğini günceller.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --import --path . >/dev/null 2>&1 || true
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
