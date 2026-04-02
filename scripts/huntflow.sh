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
ACCOUNT_ID="18980"
DIV_EXTERNAL="10665"  # Внешняя вакансия
DIV_INTERNAL="10666"  # Внутренняя вакансия

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Ошибка: huntflow_access_token не задан в конфиге." >&2
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
  local vtype="${2:-external}"

  # Inject account_division if not already in JSON
  if ! echo "$json" | grep -q '"account_division"'; then
    local div_id="$DIV_EXTERNAL"
    if [ "$vtype" = "internal" ]; then
      div_id="$DIV_INTERNAL"
    fi
    # Insert account_division into JSON object
    json=$(echo "$json" | sed "s/^{/{\"account_division\": ${div_id}, /")
  fi

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
  hf_request GET "/applicants?vacancy=${vacancy_id}"
}

cmd_applicant_get() {
  local applicant_id="$1"
  hf_request GET "/applicants/${applicant_id}"
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

cmd_members() {
  hf_request GET "/coworkers"
}

cmd_member_find() {
  local search_name="$1"
  local search_lower
  search_lower=$(echo "$search_name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  local members_raw
  members_raw=$(hf_request GET "/coworkers")

  # Search by name substring (case-insensitive) directly in raw JSON
  # Find entry containing the search name, extract its "member" field
  local result
  result=$(echo "$members_raw" | grep -oi "\"name\":\"[^\"]*${search_lower}[^\"]*\"" | head -1 || true)

  if [ -z "$result" ]; then
    # Try case-insensitive grep on the raw JSON
    result=$(echo "$members_raw" | tr '[:upper:]' '[:lower:]' | grep -o "\"name\":\"[^\"]*${search_lower}[^\"]*\"" | head -1 || true)
  fi

  if [ -z "$result" ]; then
    echo "Пользователь «${search_name}» не найден среди членов организации в Хантфлоу." >&2
    return 1
  fi

  # Extract the actual name to find the corresponding member ID
  local matched_name
  matched_name=$(echo "$result" | sed 's/"name":"//;s/"//')

  # Find the member ID for this name in the original (case-preserved) JSON
  local member_id
  member_id=$(echo "$members_raw" | grep -o "\"member\":[0-9]*,\"name\":\"${matched_name}\"" | head -1 | grep -o '"member":[0-9]*' | sed 's/"member"://' || true)

  if [ -z "$member_id" ]; then
    # Try different JSON key order
    member_id=$(echo "$members_raw" | grep -o "\"name\":\"${matched_name}\"[^}]*\"member\":[0-9]*" | head -1 | grep -o '"member":[0-9]*' | sed 's/"member"://' || true)
  fi

  if [ -z "$member_id" ]; then
    # Last resort: find the entry block containing this name and extract member
    local block
    block=$(echo "$members_raw" | grep -oE "\{[^}]*\"name\":\"${matched_name}\"[^}]*\}" | head -1 || true)
    member_id=$(echo "$block" | grep -o '"member":[0-9]*' | head -1 | sed 's/"member"://' || true)
  fi

  if [ -n "$member_id" ]; then
    echo "$member_id"
  else
    echo "Найден пользователь «${matched_name}», но не удалось определить ID." >&2
    return 1
  fi
}

# --- Dictionary (Клиенты) subcommands ---
# Dictionary code: "klienty"
# Vacancy custom field key: "N6zxOoJFHT4o9du_TFbCk"
# Agency divisions endpoint: /divisions (maps account_division ID → client name)

DICT_CODE="klienty"
CLIENT_FIELD_KEY="N6zxOoJFHT4o9du_TFbCk"

cmd_dict_clients() {
  local raw
  raw=$(hf_request GET "/dictionaries/${DICT_CODE}")
  # Extract fields array entries: each has id, name, foreign, deep, active
  # Output: one JSON object per line for easy parsing
  local fields
  fields=$(echo "$raw" | sed 's/.*"fields":\[/[/' | sed 's/\],.*/]/')
  echo "$fields"
}

cmd_dict_client_add() {
  local name="$1"
  local foreign
  foreign=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')

  # PUT replaces the entire dictionary. Fetch current items, append new one.
  local current_raw
  current_raw=$(hf_request GET "/dictionaries/${DICT_CODE}")

  # Extract existing items as {foreign, name} pairs for the PUT payload
  local existing_items
  existing_items=$(echo "$current_raw" | sed 's/.*"fields":\[//' | sed 's/\],.*//' | \
    grep -oE '\{[^{}]*\}' | \
    while IFS= read -r entry; do
      local ename eforeign
      ename=$(echo "$entry" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"//')
      eforeign=$(echo "$entry" | grep -o '"foreign":"[^"]*"' | head -1 | sed 's/"foreign":"//;s/"//')
      [ -n "$ename" ] && echo "{\"foreign\": \"${eforeign}\", \"name\": \"${ename}\"}"
    done | tr '\n' ',' | sed 's/,$//' || true)

  local new_item="{\"foreign\": \"${foreign}\", \"name\": \"${name}\"}"

  local items
  if [ -z "$existing_items" ]; then
    items="[${new_item}]"
  else
    items="[${existing_items}, ${new_item}]"
  fi

  hf_request PUT "/dictionaries/${DICT_CODE}" "{\"code\": \"${DICT_CODE}\", \"name\": \"Клиенты\", \"items\": ${items}}"
}

cmd_dict_client_find() {
  local search_name="$1"
  local search_lower
  search_lower=$(echo "$search_name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  local dict_raw
  dict_raw=$(hf_request GET "/dictionaries/${DICT_CODE}")

  # Parse fields array — each entry has "id", "name", "foreign"
  local found=""
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local entry_name
    entry_name=$(echo "$entry" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"//')
    local entry_lower
    entry_lower=$(echo "$entry_name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ "$entry_lower" = "$search_lower" ]; then
      local entry_id
      entry_id=$(echo "$entry" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
      echo "{\"id\": ${entry_id}, \"name\": \"${entry_name}\"}"
      found="yes"
      break
    fi
  done <<< "$(echo "$dict_raw" | sed 's/.*"fields":\[//' | sed 's/\],.*//' | grep -oE '\{[^{}]*\}')"

  if [ -z "$found" ]; then
    echo "Клиент \"${search_name}\" не найден в справочнике." >&2
    return 1
  fi
}

# --- Migration ---

cmd_migrate_clients() {
  local mode="${1:---dry-run}"

  echo "=== Миграция клиентов в справочник ==="
  echo ""

  # 1. Fetch dictionary
  echo "Загружаю справочник клиентов..." >&2
  local dict_raw
  dict_raw=$(hf_request GET "/dictionaries/${DICT_CODE}")

  # 2. Fetch divisions (old client structure)
  echo "Загружаю divisions (старая структура клиентов)..." >&2
  local divisions
  divisions=$(hf_request GET "/divisions")

  # 3. Fetch ALL vacancies (with pagination)
  echo "Загружаю все вакансии..." >&2
  local page=1
  local total_pages=1
  local total=0
  local all_vids=""

  while [ "$page" -le "$total_pages" ]; do
    local page_data
    page_data=$(hf_request GET "/vacancies?page=${page}&count=30")
    if [ "$page" -eq 1 ]; then
      total=$(echo "$page_data" | grep -o '"total_items":[0-9]*' | sed 's/"total_items"://')
      total_pages=$(echo "$page_data" | grep -o '"total_pages":[0-9]*' | sed 's/"total_pages"://')
      echo "Найдено вакансий: ${total} (страниц: ${total_pages})" >&2
    fi
    local page_vids
    page_vids=$(echo "$page_data" | grep -oE '"id":[0-9]+,"created"' | sed 's/,"created"//;s/"id"://')
    all_vids="${all_vids}${all_vids:+
}${page_vids}"
    page=$((page + 1))
  done
  echo "" >&2

  # Helper: resolve division ID to name
  _div_name() {
    local div_id="$1"
    local result
    result=$(echo "$divisions" | grep -oE "\"id\":${div_id}[^}]*" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' || true)
    echo "$result"
  }

  # Helper: find client in dictionary by name (case-insensitive)
  _dict_find() {
    local search="$1"
    local search_lower
    search_lower=$(echo "$search" | tr '[:upper:]' '[:lower:]')
    local entries
    entries=$(echo "$dict_raw" | sed 's/.*"fields":\[//' | sed 's/\],.*//' | grep -oE '\{[^{}]*\}' || true)
    [ -z "$entries" ] && return 0
    echo "$entries" | while IFS= read -r entry; do
      local ename
      ename=$(echo "$entry" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"//')
      local elower
      elower=$(echo "$ename" | tr '[:upper:]' '[:lower:]')
      if [ "$elower" = "$search_lower" ]; then
        echo "$entry"
        return 0
      fi
    done
  }

  echo "ID | Позиция | Division | Клиент | Dict field | Статус"
  echo "---|---------|----------|--------|------------|-------"

  for vid in $all_vids; do
    [ -z "$vid" ] && continue
    local vdata
    vdata=$(hf_request GET "/vacancies/${vid}" 2>/dev/null)

    local position
    position=$(echo "$vdata" | grep -o '"position":"[^"]*"' | sed 's/"position":"//;s/"//')

    local division
    division=$(echo "$vdata" | grep -o '"account_division":[0-9]*' | sed 's/"account_division"://')

    local dict_value
    dict_value=$(echo "$vdata" | grep -o "\"${CLIENT_FIELD_KEY}\":[^,}]*" | sed "s/\"${CLIENT_FIELD_KEY}\"://")

    # Resolve division to client name
    local client_name=""
    if [ -n "$division" ] && [ "$division" != "null" ]; then
      client_name=$(_div_name "$division")
    fi

    if [ "$dict_value" != "null" ] && [ -n "$dict_value" ]; then
      echo "${vid} | ${position} | ${division} | ${client_name:-(unknown)} | ${dict_value} | уже заполнено"
      continue
    fi

    if [ -z "$client_name" ]; then
      echo "${vid} | ${position} | ${division} | (не найден) | null | пропущено — нет имени клиента"
      continue
    fi

    # Skip placeholder client names
    case "$client_name" in
      *"Нужно добавить"*|*"нужно добавить"*|*"TODO"*|*"todo"*)
        echo "${vid} | ${position} | ${division} | ${client_name} | null | пропущено — заглушка"
        continue
        ;;
    esac

    # Check if client exists in dictionary
    local dict_entry
    dict_entry=$(_dict_find "$client_name")

    if [ "$mode" = "--apply" ]; then
      # Add to dictionary if not found
      if [ -z "$dict_entry" ]; then
        echo "  → Добавляю клиента '${client_name}' в справочник..." >&2
        cmd_dict_client_add "$client_name" > /dev/null 2>&1
        # Dictionary update is async — wait briefly then re-fetch
        sleep 2
        dict_raw=$(hf_request GET "/dictionaries/${DICT_CODE}" 2>/dev/null)
        dict_entry=$(_dict_find "$client_name")
      fi

      if [ -n "$dict_entry" ]; then
        local dict_id
        dict_id=$(echo "$dict_entry" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
        # PUT requires position and account_division — pass them through from existing data
        hf_request PUT "/vacancies/${vid}" "{\"position\": \"${position}\", \"account_division\": ${division}, \"${CLIENT_FIELD_KEY}\": ${dict_id}}" > /dev/null 2>&1
        echo "${vid} | ${position} | ${division} | ${client_name} | → ${dict_id} | мигрировано"
      else
        echo "${vid} | ${position} | ${division} | ${client_name} | null | ошибка — не удалось найти в справочнике"
      fi
    else
      local dict_status="не найден → будет создан"
      if [ -n "$dict_entry" ]; then
        dict_status="найден"
      fi
      echo "${vid} | ${position} | ${division} | ${client_name} | null | нужна миграция (${dict_status})"
    fi
  done

  echo ""
  if [ "$mode" = "--dry-run" ]; then
    echo "=== DRY RUN — изменения не внесены ==="
    echo "Для применения: scripts/huntflow.sh migrate-clients --apply"
  else
    echo "=== Миграция завершена ==="
  fi
}

# --- State migration ---
# Reads JSON from $TMPDIR/vacancy-states.json, sets HF vacancy states based on Notion status

cmd_migrate_states() {
  local mode="${1:---dry-run}"
  local json_file="${TMPDIR:-/tmp/claude}/vacancy-states.json"

  if [ ! -f "$json_file" ]; then
    echo "Ошибка: файл $json_file не найден. Сначала создайте его через Claude Code." >&2
    exit 1
  fi

  echo "=== Миграция состояний вакансий ==="
  echo ""
  echo "ID | Позиция | Notion статус | Текущее HF | Целевое HF | Статус"
  echo "---|---------|--------------|------------|-----------|-------"

  local updated=0
  local skipped=0

  set +e
  # Parse JSON entries using python3 for reliability
  python3 -c "
import json, sys
with open('$json_file') as f:
    for v in json.load(f):
        print(f\"{v['huntflow_id']}|{v['position']}|{v.get('notion_status','')}|{v['target_hf_state']}|{v['match_type']}\")
" | while IFS='|' read -r hf_id position notion_status target_state match_type; do
    [ -z "$hf_id" ] && continue

    # Get current HF state
    local current_state
    current_state=$(hf_request GET "/vacancies/${hf_id}" 2>/dev/null | grep -o '"state":"[^"]*"' | sed 's/"state":"//;s/"//') || current_state="UNKNOWN"

    # Skip no_match entries
    if [ "$match_type" = "no_match" ]; then
      echo "${hf_id} | ${position} | ${notion_status} | ${current_state} | — | пропущено (нет матча)"
      continue
    fi

    # Skip if already in target state
    if [ "$current_state" = "$target_state" ]; then
      echo "${hf_id} | ${position} | ${notion_status} | ${current_state} | ${target_state} | уже верно"
      skipped=$((skipped + 1))
      continue
    fi

    if [ "$mode" = "--apply" ]; then
      # Get current vacancy data for required fields
      local vdata
      vdata=$(hf_request GET "/vacancies/${hf_id}" 2>/dev/null) || { echo "${hf_id} | ${position} | ОШИБКА чтения"; continue; }
      local safe_position
      safe_position=$(echo "$vdata" | grep -o '"position":"[^"]*"' | sed 's/"position":"//;s/"//' | sed 's/"/\\"/g')
      local division
      division=$(echo "$vdata" | grep -o '"account_division":[0-9]*' | sed 's/"account_division"://')
      local client_field
      client_field=$(echo "$vdata" | grep -o '"N6zxOoJFHT4o9du_TFbCk":[^,}]*' | sed 's/"N6zxOoJFHT4o9du_TFbCk"://' || echo "null")
      [ -z "$client_field" ] && client_field="null"

      local result
      result=$(hf_request PUT "/vacancies/${hf_id}" "{\"position\": \"${safe_position}\", \"account_division\": ${division}, \"N6zxOoJFHT4o9du_TFbCk\": ${client_field}, \"state\": \"${target_state}\"}" 2>/dev/null) || true
      if [ -n "$result" ]; then
        echo "${hf_id} | ${position} | ${notion_status} | ${current_state} | → ${target_state} | обновлено"
        updated=$((updated + 1))
      else
        echo "${hf_id} | ${position} | ${notion_status} | ${current_state} | → ${target_state} | ОШИБКА"
      fi
    else
      echo "${hf_id} | ${position} | ${notion_status} | ${current_state} | → ${target_state} | нужно обновить"
    fi
  done
  set -e

  echo ""
  if [ "$mode" = "--dry-run" ]; then
    echo "=== DRY RUN — изменения не внесены ==="
    echo "Для применения: scripts/huntflow.sh migrate-states --apply"
  else
    echo "=== Миграция завершена ==="
  fi
}

# Generic endpoint for discovery/debugging
cmd_raw() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  hf_request "$method" "$endpoint" "$data"
}

# --- Main ---

usage() {
  cat <<'EOF'
Luna Stack — Huntflow API wrapper

Использование: scripts/huntflow.sh <команда> [аргументы]

Команды:
  vacancy-create <json> [external|internal] Создать вакансию (default: external)
  vacancy-get <vacancy_id>                 Получить данные вакансии
  vacancy-list [--mine] [--opened]         Список вакансий
  vacancy-update <vacancy_id> <json>       Обновить вакансию
  applicants-list <vacancy_id>             Список кандидатов по вакансии
  applicant-get <applicant_id>             Полный профиль кандидата
  applicant-add <json>                     Добавить кандидата
  applicant-move <applicant_id> <vacancy_id> <status_id>  Переместить кандидата
  dict-clients                             Список клиентов из справочника
  dict-client-add <name>                   Добавить клиента в справочник
  dict-client-find <name>                  Найти клиента в справочнике по имени
  migrate-clients [--dry-run|--apply]      Миграция клиентов в справочник
  migrate-states [--dry-run|--apply]       Миграция состояний вакансий по данным из Notion
  members                                  Список пользователей организации
  member-find <name>                       Найти пользователя по имени → вернуть ID
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
  applicant-get)    cmd_applicant_get "$@" ;;
  applicant-add)    cmd_applicant_add "$@" ;;
  applicant-move)   cmd_applicant_move "$@" ;;
  dict-clients)     cmd_dict_clients ;;
  dict-client-add)  cmd_dict_client_add "$@" ;;
  dict-client-find) cmd_dict_client_find "$@" ;;
  migrate-clients)  cmd_migrate_clients "$@" ;;
  migrate-states)   cmd_migrate_states "$@" ;;
  members)          cmd_members ;;
  member-find)      cmd_member_find "$@" ;;
  raw)              cmd_raw "$@" ;;
  *)
    echo "Неизвестная команда: $SUBCOMMAND" >&2
    usage
    exit 1
    ;;
esac
