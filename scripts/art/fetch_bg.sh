#!/bin/zsh
# usage: fetch_bg.sh kind url
set -e
cd "$(dirname $0)/../.."
curl -sfL -o "work/art_raw/bg_$1.png" "$2"
sips -s format jpeg -s formatOptions 86 "work/art_raw/bg_$1.png" --out "game/assets/story/backgrounds/$1.jpg" >/dev/null
echo "$1 $2" >> work/art_raw/bg_urls.txt
echo "ok $1"
