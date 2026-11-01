#!/usr/bin/env bash
# gofilectl.sh — minimal GoFile API helper (upload direction only)
# Verified live against the 2026 API:
#   - POST /accounts              -> guest token (tier "guest"), always free
#   - GET  /servers               -> upload servers
#   - POST uploadfile?token=...   -> per-file wrapper folder + downloadPage
# NOT available without premium: listing content, folder creation, direct links.
# Requires: curl, jq. Optional: GOFILE_TOKEN env (free-account token, more durable)
set -euo pipefail

API="https://api.gofile.io"

mint_guest_token() {
  curl -fsS -X POST "$API/accounts" | jq -r '.data.token'
}

token() {
  if [[ -n "${GOFILE_TOKEN:-}" ]]; then echo "$GOFILE_TOKEN"; else mint_guest_token; fi
}

pick_server() {
  curl -fsS "$API/servers" | jq -r '.data.servers[0].name'
}

# upload <file> — prints "file -> downloadPage"
cmd_upload() {
  local file="$1" tok server url resp out
  tok=$(token)
  server=$(pick_server)
  url="https://${server}.gofile.io/contents/uploadfile?token=${tok}"
  resp=""
  for i in 1 2 3; do
    resp=$(curl -fsS --max-time 7200 -F "file=@${file}" "$url") && break
    echo "upload attempt $i failed, retrying..." >&2
    sleep 15
  done
  [[ -n "$resp" ]] || { echo "upload failed after retries" >&2; return 1; }
  echo "$(basename "$file") -> $(echo "$resp" | jq -r '.data.downloadPage')"
}

case "${1:-}" in
  upload) shift; cmd_upload "$@" ;;
  guest)  mint_guest_token ;;
  server) pick_server ;;
  *) echo "usage: $0 {upload <file> | guest | server}" >&2; exit 2 ;;
esac
