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

If YES and it's the SAME vacancy, show the current status (skip to Step 3).

## Step 1: Load Config

```bash
cat ~/.luna-stack/config.yaml
```

Extract recruiter name, specialization, huntflow_user_id.

## Step 2: Identify the Vacancy

Use AskUserQuestion:
- question: «С какой вакансией работаем? Напиши название клиента и позицию.»
- header: "Вакансия"
- Let the recruiter type freely (use 2 placeholder options, but the recruiter will type their answer in "Type something else")

Parse the response to extract: client name, position title.

## Step 3: Find vacancy

### Step 3a: Fetch recruiter's active vacancies

First, get ALL active vacancies for this recruiter in one query. The recruiter's Team DB page URL is needed — look it up from config name if not already known:

```
mcp__claude_ai_Notion__notion-search
  query: "<recruiter name from config>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

Then fetch the Vacancies data source to get the recruiter's vacancies:

```
mcp__claude_ai_Notion__notion-fetch
  id: "collection://32ef9167-2e00-8102-ba94-000b387a05bb"
```

This returns the database schema. Use the recruiter's Team DB page URL to query vacancies where «Рекрутер» matches and «Статус» is active.

The recruiter typically has 3-10 active vacancies. This one query replaces all the old multi-pass search + per-result verification logic.

### Step 3b: Match user's input

Take the client name + position from Step 2 and fuzzy-match against the results from Step 3a:

- Match against «Вакансия» title (contains position name)
- Match against «Клиент» relation (contains client name)
- Try both exact match and transliteration (кириллица ↔ латиница):
  - «Бринго» → "Bringo"
  - «ТехКорп» → "TechCorp"
  - "Finbase" → «Финбейс»

**If one match found** — proceed to "If vacancy FOUND" below.

**If multiple matches found** — show them via AskUserQuestion and ask the recruiter to pick.

**If no match found** — show ALL active vacancies from Step 3a via AskUserQuestion:
- question: «Не нашла вакансию по запросу «[original query]». Вот твои активные вакансии — есть ли нужная среди них?»
- options: list each vacancy as an option (up to 4) + «Создать новую вакансию»

If the recruiter picks an existing vacancy, proceed to "If vacancy FOUND" below.
If «Создать новую» — proceed to "If vacancy NOT FOUND" below.

### If vacancy FOUND:

1. Fetch the full vacancy card:
```
mcp__claude_ai_Notion__notion-fetch
  id: "<vacancy page URL or ID from search results>"
```

2. Extract from Notion card:
   - Status, SLA zone, Type (External/Internal)
   - Client (relation), Recruiter (relation)
   - Dates: start date, end date, close date
   - Financial: salary, fee, payments
   - Huntflow ID
   - Comments, conditions

3. If Huntflow ID exists, get pipeline data:
```bash
scripts/huntflow.sh vacancy-get <huntflow_id>
scripts/huntflow.sh applicants-list <huntflow_id>
```
   From vacancy-get response, read client name from custom field `N6zxOoJFHT4o9du_TFbCk` (dictionary object with `id` and `name`).

4. Show combined summary to the recruiter:

«**[Client] — [Position]**

📋 **Notion:**
• Статус: [status]
• SLA: [zone]
• Рекрутер: [name]
• Дата начала ИС: [date]

📊 **Хантфлоу (воронка):**
• Новые: [N]
• Скрининг: [N]
• Интервью с клиентом: [N]
• Оффер: [N]
• Всего кандидатов: [N]»

5. Determine the current stage and suggest relevant next actions using AskUserQuestion:

Map status to stage and offer contextual options:
- **Active Search**: suggest `/vacancy-card`, `/outreach`, `/research`, `/screening`, `/briefing`
- **Test period**: suggest `/client-update`, `/handoff`
- **On Hold**: suggest resuming search, `/client-update`
- **Vacancy closed / Failed / Test period failed**: inform that vacancy is closed, suggest `/handoff` if needed
- **Any active stage**: always offer «Обновить данные» and «Посмотреть гайд по этапу»

### If vacancy NOT FOUND:

1. Confirm with the recruiter:
   «Вакансия [Client] — [Position] не найдена. Создаем новую?»
   Options: "Создать (Рекомендуется)" / "Поискать еще раз" / "Отмена"

2. **Find or create Client in Notion** using fuzzy strategy:

**Pass 1 — exact query:**
```
mcp__claude_ai_Notion__notion-search
  query: "<client name>"
  data_source_url: "collection://32ef9167-2e00-81fe-8524-000b62b3305f"
```

**Pass 2 — transliteration (if Pass 1 returned no results):**
Try Latin/Cyrillic transliteration of the client name and search again.

**Pass 3 — show existing clients (if Pass 2 returned no results):**
Search with a broader query (first word of the client name, or partial match) and show results to the recruiter:
- question: «Клиент "[client name]" не найден. Возможно, он записан иначе. Вот похожие — есть ли нужный?»
- options: up to 4 matching clients + "Создать нового клиента"

If client not found and recruiter confirms — create it in Notion.

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
      "Рекрутер": "<recruiter relation ID>"
    }
  }]
```
Note: do NOT pass `content` — the template «Шаблон вакансии» provides the standard page structure. Template application is asynchronous — the page is created immediately but template content appears shortly after.

5. **Create vacancy in Huntflow** with client dictionary field and fill quotas:

Determine vacancy type from the Notion "Тип" field:
- If "External" (or not set) → pass `external` (default, uses Внешняя вакансия division)
- If "Internal" → pass `internal` (uses Внутренняя вакансия division)

```bash
scripts/huntflow.sh vacancy-create '{"position": "<Position>", "fill_quotas": [{"applicants_to_hire": 1}], "N6zxOoJFHT4o9du_TFbCk": <dict_client_id>}' external
```
Note: `N6zxOoJFHT4o9du_TFbCk` is the custom field key for "Клиент" (dictionary type). The value is the dictionary entry `id` (integer). The second argument (`external`/`internal`) sets the division automatically.

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

8. **Look up recruiter in Team database** to set the relation:
```
mcp__claude_ai_Notion__notion-search
  query: "<recruiter name from config>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```
   Check if recruiter's specialization matches the vacancy domain. If mismatch, warn:
   «Твоя специализация — [spec], а эта вакансия выглядит как [domain]. Всё верно?»

## Step 4: Session Naming

After the vacancy is identified/created, display as plain text (NOT via AskUserQuestion):

«Переименуй эту сессию. Напиши в чат (не в "Type something else", а прямо в поле ввода сообщения):

/rename [Client] — [Position] (месяц год)

Например: /rename TechCorp — Frontend Dev (март 2026)»

Wait for the recruiter to type the /rename command. Do not proceed until they confirm or skip.

## Step 5: Next Actions

Use AskUserQuestion to offer the most relevant next step based on the vacancy stage. Always include the recommendation with reasoning.

Remember: from this point on, this session is bound to this vacancy. Store the vacancy context (client, position, Notion page ID, Huntflow ID) in your conversation memory.
