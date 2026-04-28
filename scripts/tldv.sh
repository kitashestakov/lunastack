#!/bin/bash
set -euo pipefail

# Luna Stack — tldv.io API wrapper
# Usage: scripts/tldv.sh <subcommand> [args]
# Config: ~/.luna-stack/config.yaml (reads tldv_api_token and email)
#
# Security invariant
# ------------------
# Subcommand `meeting-list-mine` ALWAYS filters the API response so only
# meetings where the configured user's email is in the meeting's data
# are returned. The /calls skill must use `meeting-list-mine`, never raw
# `meeting-list`.
#
# IMPORTANT: at Luna Pastel the tldv account is a shared one (ba@lunapastel.io)
# that gets invited to every team call, so the API token sees ALL team
# meetings — not just the ones the token-owner participated in. We therefore
# filter on the recruiter's own email being present in the meeting's
# participant data, NOT on token ownership.
#
# Filter strategy (schema-independent)
# ------------------------------------
# Instead of guessing field names like invitees/participants/attendees and
# assuming each has an .email key, we serialize each meeting object to its
# JSON representation and check whether the recruiter's email appears as a
# substring. This catches the email regardless of whether tldv stores it as
# .invitees[].email, .participants[].address, .attendees[].user.email, etc.
# False-positive risk (email mentioned in meeting title or transcript without
# the person actually attending) is acceptable — the user re-confirms the
# meeting before any save in /calls Step 3.
#
# Two-pass approach:
#   1. Fast pass: filter the /meetings list response with the substring check.
#   2. Enrichment fallback: if the list response doesn't include participant
#      details (some APIs return only summaries), refetch each meeting via
#      /meetings/{id} and re-apply the substring check. This makes N+1 calls
#      but only when needed, and only against meetings the token can already
#      see.
#
# API base / auth
# ---------------
# - https://pasta.tldv.io/v1alpha1 (tldv public API)
# - Header: x-api-key: <token>
# - Endpoints assumed: GET /meetings, /meetings/{id}, /meetings/{id}/transcript,
#   /meetings/{id}/highlights. The list-array container is tried as
#   .results / .data / .items / bare array.

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
  meeting-list-raw [--limit N] [--query Q]
                              Diagnostic: raw, unfiltered tldv response. Use only
                              for debugging when meeting-list-mine returns wrong
                              results — to inspect the actual JSON shape.
  whoami                      Print configured email and a token sanity check.
EOF
  exit 1
fi

cmd="$1"; shift

# Returns the JSON array of meetings from a raw tldv list response,
# trying common container fields.
extract_meetings='((.results // .data // .items // (if type == "array" then . else [] end)))'

case "$cmd" in
  whoami)
    echo "email: ${USER_EMAIL}"
    echo "token: ${API_TOKEN:0:8}…${API_TOKEN: -4}"
    ;;

  meeting-list-raw)
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
    api_get "/meetings${qs}"
    ;;

  meeting-list-mine)
    # SECURITY INVARIANT: only return meetings where USER_EMAIL appears
    # somewhere in the meeting's data. /calls must use this command, not
    # the raw API. The substring check is applied here in shell so it cannot
    # be bypassed from the skill prompt.
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

    # Pass 1 — substring filter on the list response itself.
    # Schema-independent: catches the email in any field name (invitees,
    # participants, attendees, organizer, address, user.email, etc.).
    pass1=$(echo "$raw" | jq --arg email "$USER_EMAIL" "
      ${extract_meetings}
      | map(select(tostring | contains(\$email)))
    ")

    pass1_count=$(echo "$pass1" | jq 'length')

    if [ "$pass1_count" -gt 0 ]; then
      echo "$pass1"
      exit 0
    fi

    # Pass 2 — enrichment fallback. The list endpoint may return only
    # summaries without participant details; refetch each meeting individually
    # and apply the same substring check against the detailed object.
    ids=$(echo "$raw" | jq -r "
      ${extract_meetings}
      | .[] | (.id // ._id // .meetingId // empty)
    ")

    enriched="[]"
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      detail=$(api_get "/meetings/${id}" 2>/dev/null || echo "null")
      [ "$detail" = "null" ] && continue
      if echo "$detail" | jq --arg email "$USER_EMAIL" -e 'tostring | contains($email)' >/dev/null 2>&1; then
        enriched=$(jq -s '.[0] + [.[1]]' <(echo "$enriched") <(echo "$detail"))
      fi
    done <<< "$ids"

    echo "$enriched"
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
