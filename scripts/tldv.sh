#!/bin/bash
set -euo pipefail

# Luna Stack — tldv.io API wrapper
# Usage: scripts/tldv.sh <subcommand> [args]
# Config: ~/.luna-stack/config.yaml (reads tldv_api_token and email)
#
# API base / auth
# ---------------
#   https://pasta.tldv.io/v1alpha1
#   Header: x-api-key: <token>
#
# Schema (verified against the live API on 2026-04-28)
# ----------------------------------------------------
# GET /meetings?limit=N&page=N&query=KEYWORD
#   {
#     "page": 1, "pageSize": 50, "pages": 5, "total": 228,
#     "results": [
#       {
#         "id": "string",
#         "name": "string",
#         "happenedAt": "Tue Apr 28 2026 16:22:49 GMT+0000 (Coordinated Universal Time)",  # JS Date
#         "duration": 1053.146,                       # seconds
#         "invitees": [{"name": "...", "email": "..."}],  # always array, may be []
#         "organizer": {"name": "...", "email": "..."},   # always object
#         "url": "https://tldv.io/app/meetings/{id}",
#         "extraProperties": {"conferenceId": "..."}
#       }
#     ]
#   }
#   - ?query=KEYWORD: server-side substring filter on meeting name.
#   - ?q=KEYWORD: ignored (no filtering).
#
# GET /meetings/{id}
#   Same shape as a single result, plus possibly a `template` object.
#   IMPORTANT: happenedAt is ISO 8601 here (e.g. "2026-04-28T12:45:00.000Z"),
#   not the JS Date string used in the list response.
#
# GET /meetings/{id}/transcript
#   {
#     "id": "transcript-id",
#     "meetingId": "meeting-id",
#     "data": [{"startTime": 0, "endTime": 147, "speaker": "...", "text": "..."}]
#   }
#   - May return HTTP 403 ForbiddenError if the meeting's organizer is on a
#     free tldv plan. Body: {"name":"ForbiddenError","message":"This meeting
#     was organized by a Free user and cannot be accessed via API."}
#
# GET /meetings/{id}/highlights
#   {
#     "meetingId": "meeting-id",
#     "data": [{
#       "text": "...",
#       "startTime": 0,
#       "source": "auto",
#       "topic": {"title": "...", "summary": "..."}
#     }]
#   }
#   - Same 403 caveat as transcript.
#
# Security invariant
# ------------------
# `meeting-list-mine` returns ONLY meetings where the configured user's email
# is in .organizer.email or .invitees[].email. The shared API token (from
# 1Password "tldv Token") sees ALL team meetings because ba@lunapastel.io is
# invited to every call — so we MUST filter on the recruiter's own email
# rather than rely on token-owner scoping. The /calls skill must use
# `meeting-list-mine`, never raw `meeting-list-raw`.

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

# Strict GET: exit non-zero on HTTP >= 400.
api_get() {
  local path="$1"
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X GET "${API_BASE}${path}" \
    -H "x-api-key: ${API_TOKEN}" \
    -H "Accept: application/json")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [ "$http_code" -ge 400 ]; then
    echo "tldv API error ($http_code): $body" >&2
    exit 1
  fi
  echo "$body"
}

# Soft GET: return body verbatim regardless of HTTP code. Used for transcript /
# highlights so the caller can detect the 403 ForbiddenError (free-plan
# organizer) and surface it as a friendly message instead of failing the skill.
api_get_soft() {
  local path="$1"
  curl -s \
    -X GET "${API_BASE}${path}" \
    -H "x-api-key: ${API_TOKEN}" \
    -H "Accept: application/json"
}

if [ $# -lt 1 ]; then
  cat >&2 <<EOF
Usage: scripts/tldv.sh <subcommand> [args]

Subcommands:
  meeting-list-mine [--limit N] [--api-limit N] [--query Q]
                              List meetings where the configured user is in
                              .organizer.email or .invitees[].email.
                              --limit:     how many to return after filtering (default 20).
                              --api-limit: how many to fetch from API before filtering (default 200).
                              --query:     server-side substring filter on meeting name.
                              This is the canonical command for skills.
  meeting-get <meeting_id>    Get meeting details (full object, including invitees/organizer).
  meeting-transcript <meeting_id>
                              Get transcript JSON. Returns ForbiddenError body
                              if the organizer is on a free tldv plan — caller
                              must check for it.
  meeting-highlights <meeting_id>
                              Get AI highlights JSON. Same 403 caveat as transcript.
  meeting-list-raw [--limit N] [--query Q]
                              Diagnostic: raw unfiltered list. Do NOT use in skills.
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

  meeting-list-raw)
    api_limit=50
    query=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --limit) api_limit="$2"; shift 2 ;;
        --query) query="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    qs="?limit=${api_limit}"
    if [ -n "$query" ]; then
      qs="${qs}&query=$(printf '%s' "$query" | jq -sRr @uri)"
    fi
    api_get "/meetings${qs}"
    ;;

  meeting-list-mine)
    # SECURITY INVARIANT: only return meetings where USER_EMAIL is in
    # .organizer.email or .invitees[].email — exact match on the verified
    # tldv schema. No substring matching, no enrichment. /calls must use
    # this command, not meeting-list-raw.
    #
    # tldv API caps `limit` at 100. To find the recruiter's meetings we may
    # need to scan more — we paginate up to MAX_PAGES of 100 meetings each,
    # filtering as we go, until we collect display_limit hits or run out.
    page_size=100
    max_pages=3
    display_limit=20
    query=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --limit) display_limit="$2"; shift 2 ;;
        --max-pages) max_pages="$2"; shift 2 ;;
        --query) query="$2"; shift 2 ;;
        *) shift ;;
      esac
    done

    query_qs=""
    if [ -n "$query" ]; then
      query_qs="&query=$(printf '%s' "$query" | jq -sRr @uri)"
    fi

    # Accumulate filtered hits across pages.
    filtered="[]"
    current=1
    while [ "$current" -le "$max_pages" ]; do
      qs="?limit=${page_size}&page=${current}${query_qs}"
      raw=$(api_get "/meetings${qs}")
      page_hits=$(echo "$raw" | jq --arg email "$USER_EMAIL" '
        .results
        | map(select(
            (.organizer.email // "") == $email
            or
            ((.invitees // []) | map(.email // "") | any(. == $email))
          ))
      ')
      filtered=$(jq -s '.[0] + .[1]' <(echo "$filtered") <(echo "$page_hits"))

      total_hits=$(echo "$filtered" | jq 'length')
      if [ "$total_hits" -ge "$display_limit" ]; then
        break
      fi

      # Stop if we've reached the last page from the API's perspective.
      total_pages=$(echo "$raw" | jq -r '.pages // 1')
      if [ "$current" -ge "$total_pages" ]; then
        break
      fi

      current=$((current + 1))
    done

    echo "$filtered" | jq --argjson limit "$display_limit" '.[0:$limit]'
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
    # Soft GET — caller checks for "ForbiddenError" in the body and explains
    # the free-plan-organizer caveat to the recruiter.
    api_get_soft "/meetings/$1/transcript"
    ;;

  meeting-highlights)
    if [ $# -lt 1 ]; then
      echo "Usage: scripts/tldv.sh meeting-highlights <meeting_id>" >&2
      exit 1
    fi
    api_get_soft "/meetings/$1/highlights"
    ;;

  *)
    echo "Unknown subcommand: $cmd" >&2
    exec "$0"
    ;;
esac
