#!/usr/bin/env bash
# Birim testlerini headless çalıştırır. Önce import ile sınıf önbelleğini günceller.
# Bir test dosyası derlenemezse GUT onu sessizce atlar; bunu da hata sayarız.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
log="$(mktemp)"
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "Ignoring script|Failed to load script" "$log"; then
	echo "HATA: Derlenemeyen test dosyası var (yukarıdaki SCRIPT ERROR satırlarına bakın)." >&2
	status=1
fi
rm -f "$log"
exit "$status"
