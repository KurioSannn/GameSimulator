#!/bin/zsh
# NUSANTARA release builder (D-096).
#
#   scripts/release/build_release.sh 1.0.0              full release: Windows .exe, macOS .zip, Android .apk
#   scripts/release/build_release.sh 1.0.1 --patch 1.0.0  small update: per-platform patch packs against 1.0.0
#
# Output: build/releases/<version>/ with the artifacts, base packs (kept locally for future patches),
# and update.json, the manifest the in-game Updater reads. Publishing is a separate, manual step:
# upload everything in build/releases/<version>/ except base_*.pck to a GitHub release tagged v<version>
# (see docs/RELEASE.md). The Android release keystore stays outside the repo (~/.nusantara/).
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION="${1:?version, e.g. 1.0.0}"
PATCH_FROM=""
[[ "${2:-}" == "--patch" ]] && PATCH_FROM="${3:?base version for --patch}"
GODOT=tools/Godot.app/Contents/MacOS/Godot
OUT="build/releases/$VERSION"
REPO_URL="${NUSANTARA_RELEASE_BASE:-https://github.com/KurioSannn/GameSimulator/releases/download}"
mkdir -p "$OUT"

python3 scripts/release/set_version.py "$VERSION"
$GODOT --headless --path game --import >/dev/null 2>&1 || true

typeset -A EXT=(Windows exe macOS zip Android apk)
typeset -A KEY=(Windows windows macOS macos Android android)

if [[ -f ~/.nusantara/release_keystore.properties ]]; then
  set -a; . ~/.nusantara/release_keystore.properties; set +a
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore" GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias" GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$password"
fi

for P in Windows macOS Android; do
  K=${KEY[$P]}
  if [[ -z "$PATCH_FROM" ]]; then
    echo "== $P full build"
    $GODOT --headless --path game --export-release "$P" "../$OUT/NUSANTARA-$VERSION-$K.${EXT[$P]}" 2>&1 | grep -E "ERROR|error:" || true
    test -s "$OUT/NUSANTARA-$VERSION-$K.${EXT[$P]}"
    # base pack of this release: the reference for later small updates (not published)
    $GODOT --headless --path game --export-pack "$P" "../$OUT/base_$K.pck" 2>&1 | grep -E "ERROR" || true
  else
    BASE="build/releases/$PATCH_FROM/base_$K.pck"
    test -f "$BASE" || { echo "missing $BASE"; exit 1; }
    echo "== $P patch $PATCH_FROM -> $VERSION"
    $GODOT --headless --path game --export-patch "$P" "../$OUT/patch-$VERSION-$K.pck" --patches "../$BASE" 2>&1 | grep -E "ERROR" || true
    test -s "$OUT/patch-$VERSION-$K.pck"
    cp "$BASE" "$OUT/base_$K.pck"   # patches stay relative to the binary line's base
  fi
done
python3 scripts/release/write_manifest.py "$VERSION" "$OUT" "$REPO_URL" "$PATCH_FROM"
echo "Release files in $OUT"
ls -la "$OUT"
