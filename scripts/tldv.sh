#!/bin/bash
set -euo pipefail

# Luna Stack — tldv.io API wrapper
# Usage: scripts/tldv.sh <subcommand> [args]
# Config: ~/.luna-stack/config.yaml (reads tldv_api_token and email)
#
# Security invariant
# ------------------
# Subcommand `meeting-list-mine` ALWAYS filters the API response so only
# meetings where the configured user's email is in invitees / participants /
# attendees are returned. The /calls skill must use `meeting-list-mine`,
# never raw `meeting-list`. The shared API token (1Password "tldv API Key")
# could in theory see all meetings, but Luna Stack only ever surfaces the
# ones a recruiter actually attended.
#
# API base / auth
# ---------------
# - https://pasta.tldv.io/v1alpha1 (tldv public API)
# - Header: x-api-key: <token>
# - Endpoints assumed: GET /meetings, /meetings/{id}, /meetings/{id}/transcript,
#   /meetings/{id}/highlights. If tldv changes their API shape, the jq
#   filters below try multiple field names (results / data / items, invitees /
#   participants / attendees) to stay robust.

CONFIG_FILE="$HOME/.luna-stack/config.yaml"
API_BASE="https://pasta.tldv.io/v1alpha1"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Ошибка: конфиг не найден ($CONFIG_FILE). Запустите /onboarding." >&2
  exit 1
fi

get_config() {
  local key="$1"
  grep "^${key}:" "$CONFIG_FILE" | sed "s/^${key}: *//; s/^\"//; s/\"$//" | head -1
}

API_TOKEN=$(get_config "tldv_api_token")
USER_EMAIL=$(get_config "email")

if [ -z "$API_TOKEN" ]; then
  echo "Ошибка: tldv_api_token не задан в конфиге. Запусти /calls — он попросит токен." >&2
  exit 1
fi

if [ -z "$USER_EMAIL" ]; then
  echo "Ошибка: email не задан в конфиге. Запусти /calls — он подставит email из Notion-Команда." >&2
  exit 1
fi

# --- API call helper ---

api_get() {
  local path="$1"
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X GET "${API_BASE}${path}" \
    -H "x-api-key: ${API_TOKEN}" \
    -H "Accept: application/json")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 400 ]; then
    echo "tldv API error ($http_code): $body" >&2
    exit 1
  fi

  echo "$body"
}

# --- Subcommands ---

if [ $# -lt 1 ]; then
  cat >&2 <<EOF
Usage: scripts/tldv.sh <subcommand> [args]

Subcommands:
  meeting-list-mine [--limit N] [--query Q]
                              List meetings where the configured user is a participant.
                              This is the canonical command for skills.
  meeting-get <meeting_id>    Get meeting details (use only after meeting-list-mine confirmed access).
  meeting-transcript <meeting_id>
                              Get transcript text.
  meeting-highlights <meeting_id>
                              Get AI highlights / summary.
  whoami                      Print configured email and a token sanity check.
EOF
  exit 1
fi

cmd="$1"; shift

case "$cmd" in
  whoami)
    echo "email: ${USER_EMAIL}"
    echo "token: ${API_TOKEN:0:8}…${API_TOKEN: -4}"
    ;;

  meeting-list-mine)
    # SECURITY INVARIANT: filter response to only meetings where USER_EMAIL is in
    # invitees / participants / attendees. /calls must use this command, not
    # the raw API. Filter is applied here in shell so it cannot be bypassed
    # by mistake from the skill prompt.
    limit=50
    query=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --limit) limit="$2"; shift 2 ;;
        --query) query="$2"; shift 2 ;;
        *) shift ;;
      esac
    done

    qs="?limit=${limit}"
    if [ -n "$query" ]; then
      qs="${qs}&query=$(printf '%s' "$query" | jq -sRr @uri)"
    fi

    raw=$(api_get "/meetings${qs}")
    # tldv response shape varies — try common containers and participant fields.
    echo "$raw" | jq --arg email "$USER_EMAIL" '
      ((.results // .data // .items // (if type == "array" then . else [] end)))
      | map(select(
          ((.invitees // .participants // .attendees // []))
          | map(.email // empty)
          | any(. == $email)
        ))
    '
    ;;

  meeting-get)
    if [ $# -lt 1 ]; then
      echo "Usage: scripts/tldv.sh meeting-get <meeting_id>" >&2
      exit 1
    fi
    api_get "/meetings/$1"
    ;;

  meeting-transcript)
    if [ $# -lt 1 ]; then
      echo "Usage: scripts/tldv.sh meeting-transcript <meeting_id>" >&2
      exit 1
    fi
    api_get "/meetings/$1/transcript"
    ;;

  meeting-highlights)
    if [ $# -lt 1 ]; then
      echo "Usage: scripts/tldv.sh meeting-highlights <meeting_id>" >&2
      exit 1
    fi
    api_get "/meetings/$1/highlights"
    ;;

  *)
    echo "Unknown subcommand: $cmd" >&2
    exec "$0"
    ;;
esac
