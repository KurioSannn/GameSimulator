#!/bin/bash
# Periodically probe official hosts; append results to research/sources/access_log.jsonl.
# Usage: scripts/probe_sources.sh [rounds] [interval_s]
cd "$(dirname "$0")/.."
ROUNDS=${1:-6}; INTERVAL=${2:-600}
URLS=("https://webapi.bps.go.id/developer/" "https://geoservices.big.go.id/rbi/rest/services?f=json" "https://dibi.bnpb.go.id/" "https://data.go.id/" "https://www.djpk.kemenkeu.go.id/" "https://gis.dukcapil.kemendagri.go.id/" "https://proxyapps.data.go.id/")
for r in $(seq 1 "$ROUNDS"); do
  for u in "${URLS[@]}"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 25 -A "NUSANTARA-research-pipeline/0.1" "$u")
    printf '{"at":"%s","source_id":"PROBE","url":"%s","status":"probe","detail":"http %s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$u" "$code" >> research/sources/access_log.jsonl
  done
  if [ "$r" -lt "$ROUNDS" ]; then sleep "$INTERVAL"; fi
done
exit 0
