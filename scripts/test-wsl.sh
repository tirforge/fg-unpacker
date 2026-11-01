#!/usr/bin/env bash
# test-wsl.sh — fg-unpacker validation suite for local WSL Ubuntu.
# Run:  wsl -e bash /mnt/c/Users/Thirupathi/Desktop/fg-unpacker/scripts/test-wsl.sh
set -euo pipefail

REPO="/mnt/c/Users/Thirupathi/Desktop/fg-unpacker"
WORK="/tmp/fgtest"
step() { echo; echo "=== $1 ==="; }

step "toolchain check"
for c in curl jq wine python3 p7zip 7z; do
  if command -v "$c" >/dev/null 2>&1; then echo "  ok  $c -> $(command -v $c)"; else echo "  MISSING  $c"; MISS=1; fi
done
if [[ "${MISS:-0}" = 1 ]]; then
  echo "installing missing packages (needs root — run via: wsl -u root ...)"; exit 3
fi
wine --version

step "engine download + sha256"
mkdir -p "$WORK"; cd "$WORK"
curl -fsSL "https://github.com/pisek/fitgirl-extractor/releases/download/v0.2.1/fitgirl-extractor.exe" -o fitgirl-extractor.exe
echo "d4dbe676ee1b9eb23b9dc416ec69654da717c59aa89cb125557b11af59d98054  fitgirl-extractor.exe" | sha256sum -c

step "engine under Wine (wineboot first run may take a minute)"
export WINEPREFIX="$HOME/.wine-fg" WINEDEBUG=-all
wine fitgirl-extractor.exe --version

step "gofilectl.sh guest upload (live probe)"
echo "wsl-guest-upload probe $(date +%s)" > hello.txt
7z a -tzip -mx=0 result.zip hello.txt >/dev/null
bash "$REPO/scripts/gofilectl.sh" upload result.zip

step "plan_bins.py grouping test"
export GITHUB_OUTPUT="$WORK/ghout.txt"
printf '%s\n' \
  "setup.exe|https://example.com/game/setup.exe" \
  "fg-01.bin|https://example.com/game/fg-01.bin" \
  "fg-02.bin|https://example.com/game/fg-02.bin" \
  "fg-03.bin|https://example.com/game/fg-03.bin" \
  "https://example.com/game/fg-04.bin" \
  | python3 "$REPO/scripts/plan_bins.py"
grep -o 'ngroups=[0-9]*' "$GITHUB_OUTPUT"

echo; echo "ALL LOCAL TESTS DONE"
