#!/usr/bin/env bash
set -euo pipefail

UI_URL="https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
UI_ROOT="/var/lib/mihomo/ui"
TMP_DIR=$(mktemp -d)
ZIP_FILE="${TMP_DIR}/metacubexd.zip"
NEW_DIR="${TMP_DIR}/ui"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$NEW_DIR"

echo "[1/4] Download metacubexd UI archive"
if ! curl -fsSL --max-time 60 "$UI_URL" -o "$ZIP_FILE"; then
  echo "Direct download failed, retrying through local proxy"
  curl -fsSL --proxy http://127.0.0.1:7890 --max-time 120 "$UI_URL" -o "$ZIP_FILE"
fi

echo "[2/4] Extract UI files"
python3 - "$ZIP_FILE" "$NEW_DIR" <<'PY'
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

zip_path = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(zip_path) as archive:
    for info in archive.infolist():
        parts = PurePosixPath(info.filename).parts
        if len(parts) <= 1:
            continue
        rel = Path(*parts[1:])
        target = out_dir / rel
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(info) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)
PY

echo "[3/4] Install UI files"
rm -rf "${UI_ROOT}.bak"
if [[ -d "$UI_ROOT" ]]; then
  mv "$UI_ROOT" "${UI_ROOT}.bak"
fi
mv "$NEW_DIR" "$UI_ROOT"
chown -R mihomo:mihomo "$UI_ROOT"

cat > "${UI_ROOT}/config.js" <<'EOF'
window.__METACUBEXD_CONFIG__ = {
  defaultBackendURL: window.location.origin,
}
EOF
chown mihomo:mihomo "${UI_ROOT}/config.js"

echo "[4/4] Verify local UI endpoint"
curl -fsS http://127.0.0.1:9090/ui/ | sed -n '1,3p'
