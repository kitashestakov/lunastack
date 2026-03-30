#!/bin/bash
set -euo pipefail

# Luna Stack — Huntflow API v2 wrapper
# Usage: scripts/huntflow.sh <subcommand> [args]
# Config: ~/.luna-stack/config.yaml
#
# Token lifecycle:
#   - access_token lives 7 days
#   - refresh_token lives 14 days
#   - On 401, auto-refreshes via POST /v2/token/refresh
#   - Saves new tokens back to config

CONFIG_FILE="$HOME/.luna-stack/config.yaml"
API_BASE="https://api.huntflow.ai/v2"

# --- Config loading ---

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Ошибка: конфиг не найден ($CONFIG_FILE). Запустите /onboarding." >&2
  exit 1
fi

# Parse YAML values (simple key: "value" or key: value format)
get_config() {
  local key="$1"
  grep "^${key}:" "$CONFIG_FILE" | sed "s/^${key}: *//; s/^\"//; s/\"$//" | head -1
}

# Update a single key in config (preserves other lines)
set_config() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}:" "$CONFIG_FILE"; then
    sed -i '' "s|^${key}:.*|${key}: \"${value}\"|" "$CONFIG_FILE"
  else
    echo "${key}: \"${value}\"" >> "$CONFIG_FILE"
  fi
}

ACCESS_TOKEN=$(get_config "huntflow_access_token")
REFRESH_TOKEN=$(get_config "huntflow_refresh_token")
ACCOUNT_ID=$(get_config "huntflow_account_id")

if [ -z "$ACCESS_TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "Ошибка: huntflow_access_token или huntflow_account_id не заданы в конфиге." >&2
  exit 1
fi

if [ -z "$REFRESH_TOKEN" ]; then
  echo "Предупреждение: huntflow_refresh_token не задан. Автообновление токена не будет работать." >&2
fi

# --- Token refresh ---

refresh_access_token() {
  if [ -z "$REFRESH_TOKEN" ]; then
    echo "Токен Хантфлоу истёк. Получи новый токен в настройках Хантфлоу и обнови его через /onboarding." >&2
    exit 1
  fi

  local refresh_response
  refresh_response=$(curl -s -w "\n%{http_code}" \
    -X POST "${API_BASE}/token/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refresh_token\": \"${REFRESH_TOKEN}\"}")

  local refresh_http_code
  refresh_http_code=$(echo "$refresh_response" | tail -1)
  local refresh_body
  refresh_body=$(echo "$refresh_response" | sed '$d')

  if [ "$refresh_http_code" -ge 400 ]; then
    echo "Токен Хантфлоу истёк. Получи новый токен в настройках Хантфлоу и обнови его через /onboarding." >&2
    exit 1
  fi

  # Extract new tokens from JSON response
  local new_access
  new_access=$(echo "$refresh_body" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"//')
  local new_refresh
  new_refresh=$(echo "$refresh_body" | grep -o '"refresh_token":"[^"]*"' | sed 's/"refresh_token":"//;s/"//')

  if [ -z "$new_access" ]; then
    echo "Ошибка: не удалось получить новый access_token из ответа refresh." >&2
    exit 1
  fi

  # Save new tokens to config
  set_config "huntflow_access_token" "$new_access"
  if [ -n "$new_refresh" ]; then
    set_config "huntflow_refresh_token" "$new_refresh"
    REFRESH_TOKEN="$new_refresh"
  fi

  ACCESS_TOKEN="$new_access"
  echo "Токен Хантфлоу обновлён." >&2
}

# --- HTTP helper ---

hf_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="${API_BASE}/accounts/${ACCOUNT_ID}${endpoint}"

  # First attempt
  local response
  response=$(_do_request "$method" "$url" "$data")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  # If 401 — try refresh and retry
  if [ "$http_code" = "401" ]; then
    refresh_access_token
    response=$(_do_request "$method" "$url" "$data")
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')
  fi

  if [ "$http_code" -ge 400 ]; then
    echo "Ошибка Huntflow API (HTTP $http_code):" >&2
    echo "$body" >&2
    exit 1
  fi

  echo "$body"
}

_do_request() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local args=(
    -s -w "\n%{http_code}"
    -X "$method"
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
    -H "Content-Type: application/json"
  )

  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi

  curl "${args[@]}" "$url"
}

# --- Subcommands ---

cmd_vacancy_create() {
  local json="$1"
  hf_request POST "/vacancies" "$json"
}

cmd_vacancy_get() {
  local vacancy_id="$1"
  hf_request GET "/vacancies/${vacancy_id}"
}

cmd_vacancy_list() {
  local params=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --mine) params="${params:+${params}&}mine=true" ;;
      --opened) params="${params:+${params}&}opened=true" ;;
      *) echo "Неизвестный параметр: $1" >&2; exit 1 ;;
    esac
    shift
  done
  local endpoint="/vacancies"
  if [ -n "$params" ]; then
    endpoint="${endpoint}?${params}"
  fi
  hf_request GET "$endpoint"
}

cmd_vacancy_update() {
  local vacancy_id="$1"
  local json="$2"
  hf_request PUT "/vacancies/${vacancy_id}" "$json"
}

cmd_applicants_list() {
  local vacancy_id="$1"
  hf_request GET "/vacancies/${vacancy_id}/applicants"
}

cmd_applicant_add() {
  local json="$1"
  hf_request POST "/applicants" "$json"
}

cmd_applicant_move() {
  local applicant_id="$1"
  local vacancy_id="$2"
  local status_id="$3"
  local json="{\"vacancy\": ${vacancy_id}, \"status\": ${status_id}}"
  hf_request POST "/applicants/${applicant_id}/vacancy" "$json"
}

# --- Main ---

usage() {
  cat <<'EOF'
Luna Stack — Huntflow API wrapper

Использование: scripts/huntflow.sh <команда> [аргументы]

Команды:
  vacancy-create <json>                    Создать вакансию
  vacancy-get <vacancy_id>                 Получить данные вакансии
  vacancy-list [--mine] [--opened]         Список вакансий
  vacancy-update <vacancy_id> <json>       Обновить вакансию
  applicants-list <vacancy_id>             Список кандидатов по вакансии
  applicant-add <json>                     Добавить кандидата
  applicant-move <applicant_id> <vacancy_id> <status_id>  Переместить кандидата
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 0
fi

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  vacancy-create)   cmd_vacancy_create "$@" ;;
  vacancy-get)      cmd_vacancy_get "$@" ;;
  vacancy-list)     cmd_vacancy_list "$@" ;;
  vacancy-update)   cmd_vacancy_update "$@" ;;
  applicants-list)  cmd_applicants_list "$@" ;;
  applicant-add)    cmd_applicant_add "$@" ;;
  applicant-move)   cmd_applicant_move "$@" ;;
  *)
    echo "Неизвестная команда: $SUBCOMMAND" >&2
    usage
    exit 1
    ;;
esac
