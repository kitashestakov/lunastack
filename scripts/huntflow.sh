#!/bin/bash
set -euo pipefail

# Luna Stack — Huntflow API v2 wrapper
# Usage: scripts/huntflow.sh <subcommand> [args]
# Config: ~/.luna-stack/config.yaml

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
  grep "^${key}:" "$CONFIG_FILE" | sed 's/^[^:]*: *"\?\([^"]*\)"\?$/\1/' | head -1
}

TOKEN=$(get_config "huntflow_token")
ACCOUNT_ID=$(get_config "huntflow_account_id")

if [ -z "$TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "Ошибка: huntflow_token или huntflow_account_id не заданы в конфиге." >&2
  exit 1
fi

# --- HTTP helper ---

hf_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="${API_BASE}/accounts/${ACCOUNT_ID}${endpoint}"
  local args=(
    -s -w "\n%{http_code}"
    -X "$method"
    -H "Authorization: Bearer ${TOKEN}"
    -H "Content-Type: application/json"
  )

  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi

  local response
  response=$(curl "${args[@]}" "$url")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 400 ]; then
    echo "Ошибка Huntflow API (HTTP $http_code):" >&2
    echo "$body" >&2
    exit 1
  fi

  echo "$body"
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
