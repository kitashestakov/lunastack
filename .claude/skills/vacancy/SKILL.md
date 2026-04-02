---
name: vacancy
description: |
  Main entry point for working with a vacancy. Finds or creates a vacancy
  in Notion and Huntflow, shows combined status, suggests next actions
  based on the current stage. Binds the session to this vacancy.
  Use when: "вакансия", "vacancy", starting work on a position.
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /vacancy — Работа с вакансией

This is the main skill. It binds the session to a vacancy and serves as the starting point for all other skills.

## Pre-check: Session Binding

Before anything else, check if this conversation already has a vacancy context (a previously identified client + position + Notion page ID).

If YES and the recruiter is trying to work with a DIFFERENT vacancy:
- DO NOT proceed
- Explain: «Эта сессия уже привязана к вакансии [Client] — [Position]. Чтобы начать работу с другой вакансией, создай новую сессию (нажми +) и набери /vacancy.»

If YES and it's the SAME vacancy, show the current status (skip to "If vacancy FOUND").

## Step 1: Load Config

```bash
cat ~/.luna-stack/config.yaml
```

Extract: `name`, `specialization`, `huntflow_user_id`, `notion_page_url` (recruiter's Team DB page URL).

If `notion_page_url` is missing, look up the recruiter in the Team database using `mcp__claude_ai_Notion__notion-fetch` on the Team data source, then search the results by name. Save the found page URL for use in Step 3.

## Step 2: Choose action

Use AskUserQuestion:
- question: «Что делаем?»
- header: "Вакансия"
- options:
  - "Продолжить работу по вакансии" — find an existing vacancy
  - "Создать новую вакансию" — create from scratch

If «Продолжить» → go to Step 3.
If «Создать» → go to "If vacancy NOT FOUND".

## Step 3: Find existing vacancy

Query ALL vacancies from the Notion database in ONE call using `mcp__claude_ai_Notion__notion-query-database-view`:

```
mcp__claude_ai_Notion__notion-query-database-view
  view_url: "https://www.notion.so/32ef91672e0081af9a31dec4b6a3542f?v=32ef91672e008142b159000c00bbb0df"
```

This returns all rows from the Vacancies database default view with their properties.

**Filter the results client-side:**
1. Check each row's «Рекрутер» field — it contains a JSON array of page URLs like `["https://www.notion.so/32ef91672e0080339149caaf8c965932"]`. Match against the recruiter's `notion_page_url` from config.
2. Check «Статус» — keep only "Active Search" and "Test period" (the two active statuses).

**Do NOT use `notion-search` for finding vacancies.** The query-database-view returns structured data with all properties, no need to fetch individual pages.

Show the filtered list via AskUserQuestion:
- question: «Вот твои активные вакансии. Выбери нужную:»
- options: list each active vacancy (up to 4, format: "[Вакансия title] — [Статус]") + «Нет в списке»

If the recruiter picks a vacancy → proceed to "If vacancy FOUND".
If «Нет в списке» → ask for client name and position (plain text, wait for input), then fuzzy-match against ALL results from the query (including closed ones, using transliteration кириллица ↔ латиница). If still not found → proceed to "If vacancy NOT FOUND".

### If vacancy FOUND:

1. Fetch the full vacancy card:
```
mcp__claude_ai_Notion__notion-fetch
  id: "<vacancy page URL or ID>"
```

2. Extract from Notion card:
   - Status, SLA zone, Type (External/Internal)
   - Client (relation), Recruiter (relation)
   - Dates: start date, end date, close date
   - Financial: salary, fee, payments
   - Huntflow ID
   - Comments, conditions

3. **Check content sub-pages.** The fetched vacancy page may contain child pages in its content section. Look for these sub-pages by title and fetch each to check if it has content:
   - «Чеклист брифинга» — briefing checklist
   - «Скоринг-таблица» — competency scoring table
   - «Описание вакансии и профиля» — internal description + candidate profile
   - Inside «Публичная вакансия» callout: page with «русском» in title (RU), page with «английском» in title (EN)

   Record the status of each:
   - exists + has content → «заполнено ✅»
   - exists + blank → «не заполнено ⚠️»
   - does not exist → «отсутствует ⚠️»

4. **Get Huntflow funnel data.** If Huntflow ID exists in the vacancy card:
```bash
scripts/huntflow.sh vacancy-get <huntflow_id>
scripts/huntflow.sh applicants-list <huntflow_id>
```
   From vacancy-get response, read client name from custom field `N6zxOoJFHT4o9du_TFbCk`.
   From applicants-list response, count candidates by stage. **Only say «воронка пустая» if the response truly contains 0 candidates.** If there are candidates — show counts per stage.

   If Huntflow ID is missing from the Notion card → note «Huntflow ID не указан ⚠️» and skip funnel data.

5. **Show combined summary** to the recruiter:

«**[Client] — [Position]**

📋 **Notion:**
• Статус: [status]
• SLA: [zone]
• Рекрутер: [name]
• Дата начала ИС: [date]

📄 **Контент:**
• Чеклист брифинга: [заполнен ✅ / не заполнен ⚠️]
• Скоринг-таблица: [заполнена ✅ / не заполнена ⚠️]
• Описание вакансии и профиля: [заполнено ✅ / не заполнено ⚠️]
• Публичная вакансия (RU): [заполнена ✅ / не заполнена ⚠️]
• Публичная вакансия (EN): [заполнена ✅ / не заполнена ⚠️]

📊 **Хантфлоу (воронка):**
• Новые: [N]
• Скрининг: [N]
• Интервью с клиентом: [N]
• Оффер: [N]
• Всего кандидатов: [N]»

6. **Suggest next actions** using AskUserQuestion.

Build the options list based on what's actually needed:
- If «Чеклист брифинга» is not filled → suggest `/briefing`
- If «Описание вакансии и профиля» is not filled → suggest `/vacancy-card`
- If descriptions are already filled → do NOT suggest `/vacancy-card`
- If funnel is empty and status is "Active Search" → suggest `/outreach` as primary
- If funnel has candidates on screening → suggest `/screening` or `/summary`

Map status to contextual options:
- **Active Search**: `/outreach`, `/research`, `/screening`, `/briefing` (+ `/vacancy-card` only if descriptions missing, + `/briefing` only if checklist missing)
- **Test period**: `/client-update`, `/handoff`
- **On Hold**: resuming search, `/client-update`
- **Vacancy closed / Failed / Test period failed**: inform closed, suggest `/handoff` if needed
- **Any active stage**: always offer «Обновить данные» and «Посмотреть гайд по этапу»

### If vacancy NOT FOUND:

1. Ask for client name and position (plain text, wait for input):

«Напиши название клиента и позицию для новой вакансии.»

2. **Find or create Client in Notion:**

Search the Clients database by name:
```
mcp__claude_ai_Notion__notion-search
  query: "<client name>"
  data_source_url: "collection://32ef9167-2e00-81fe-8524-000b62b3305f"
```

If not found — try transliteration (кириллица ↔ латиница) and search again. If still not found — show existing clients and ask the recruiter to pick or create new.

Note: `notion-search` is appropriate here — this is a one-off text search for a specific client name, not the vacancy listing flow.

3. **Find or create Client in Huntflow dictionary:**
```bash
scripts/huntflow.sh dict-client-find "<Client Name>"
```
If found — save the dictionary value `id` for use in Step 5.
If not found — add to dictionary:
```bash
scripts/huntflow.sh dict-client-add "<Client Name>"
```
Then find again to get the ID:
```bash
scripts/huntflow.sh dict-client-find "<Client Name>"
```

4. **Create vacancy in Notion** using the standard template:
```
mcp__claude_ai_Notion__notion-create-pages
  parent: { type: "data_source_id", data_source_id: "32ef9167-2e00-8102-ba94-000b387a05bb" }
  pages: [{
    template_id: "330f9167-2e00-804a-a321-c08895fea043",
    properties: {
      "Вакансия": "<Position> — <Client>",
      "Статус": "Active Search",
      "Тип": "External",
      "Рекрутер": "<recruiter Team DB page URL>"
    }
  }]
```
Note: do NOT pass `content` — the template «Шаблон вакансии» provides the standard page structure.

5. **Create vacancy in Huntflow** with client dictionary field and fill quotas:

Determine vacancy type from the Notion «Тип» field:
- If "External" (or not set) → pass `external` (default, uses Внешняя вакансия division)
- If "Internal" → pass `internal` (uses Внутренняя вакансия division)

```bash
scripts/huntflow.sh vacancy-create '{"position": "<Position>", "fill_quotas": [{"applicants_to_hire": 1}], "N6zxOoJFHT4o9du_TFbCk": <dict_client_id>}' external
```

6. **Assign recruiter to vacancy in Huntflow** (using `huntflow_user_id` from config):
```bash
scripts/huntflow.sh vacancy-update <new_vacancy_id> '{"coworkers": [<huntflow_user_id from config>]}'
```

7. **Write Huntflow ID back to Notion card:**
```
mcp__claude_ai_Notion__notion-update-page
  page_id: "<new page ID>"
  command: "update_properties"
  properties: { "Huntflow ID": <huntflow_vacancy_id> }
```

## Step 4: Next Actions

Use AskUserQuestion to offer the most relevant next step based on the vacancy stage. Always include the recommendation with reasoning.

Remember: from this point on, this session is bound to this vacancy. Store the vacancy context (client, position, Notion page ID, Huntflow ID) in your conversation memory.
