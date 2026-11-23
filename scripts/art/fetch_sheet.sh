#!/bin/zsh
# usage: fetch_sheet.sh NAME ASSET_ID out1 out2 out3 out4   (outs are CASE_id names, written under portraits/locals)
set -e
cd "$(dirname $0)/../.."
PY=/private/tmp/claude-501/-Users-macbookpro-Projects-nusantara-claude-package-desktop-first-v2/37da8979-8364-40d1-b771-f1eb01105ab4/scratchpad/venv/bin/python
L=game/assets/story/portraits/locals
curl -sfL -o "work/art_raw/sheet_$1.png" "https://www.figma.com/api/mcp/asset/$2.png"
echo "sheet_$1 https://www.figma.com/api/mcp/asset/$2.png $3 $4 $5 $6" >> work/art_raw/portrait_urls.txt
$PY -I scripts/art/crop_sheet.py "work/art_raw/sheet_$1.png" "$L/$3.jpg" "$L/$4.jpg" "$L/$5.jpg" "$L/$6.jpg" | wc -l
