---
name: weekly-sync
description: |
  Create weekly sync records for all active vacancies. Queries the Vacancies
  database for Active status, checks for existing records in the current
  target week, and creates only missing ones. Deduplication built in.
  Use when: "weekly sync", "синк", "еженедельный синк", "создать синки",
  "понедельничный синк", "weekly-sync".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /weekly-sync — Создание записей для еженедельного синка

This skill creates sync records in the «Еженедельные синки» database for all active vacancies. It is an admin/CEO utility — it does NOT require session binding to a specific vacancy.

## Override: Session Binding

This skill does NOT require an active vacancy context. Skip the session binding check from preamble.md. Any user with access can run this skill.

## Override: Safety Rule 2

This skill creates pages in the «Еженедельные синки» database. This is explicitly allowed — it is not a schema modification.

## Step 1: Load Config

```bash
cat ~/.luna-stack/config.yaml
```

Extract `name` for greeting. If config is missing, proceed anyway — this skill does not require recruiter-specific context.

## Step 2: Calculate Target Week

Determine today's day of week and calculate the target Monday and Sunday.

**Rule:** if the skill is run from Saturday through the following Friday, it targets the same Monday:
- Saturday → Monday = today + 2 days
- Sunday → Monday = today + 1 day
- Monday → Monday = today
- Tuesday → Monday = today - 1 day
- Wednesday → Monday = today - 2 days
- Thursday → Monday = today - 3 days
- Friday → Monday = today - 4 days

Target Sunday = target Monday + 6 days.

Calculate the ISO week number (W##) from the target Monday.

Show the recruiter:

«Целевая неделя: [DD.MM] – [DD.MM] (W[##])»

## Step 3: Query Active Vacancies

Query ALL vacancies from the Notion database:

```
mcp__claude_ai_Notion__notion-query-database-view
  view_url: "https://www.notion.so/32ef91672e0081af9a31dec4b6a3542f?v=32ef91672e008142b159000c00bbb0df"
```

Filter client-side for `"Статус": "Active"` only.

For each active vacancy, extract:
- Vacancy page URL
- Vacancy title (field «Вакансия»)
- Client page URL (field «Клиент» — JSON array, take first element)
- Recruiter page URL (field «Рекрутер» — JSON array, take first element)

If no active vacancies found, inform the user and stop:

«Активных вакансий не найдено. Записи не созданы.»

## Step 4: Query Existing Sync Records

Query existing sync records from the «Еженедельные синки» database:

```
mcp__claude_ai_Notion__notion-query-database-view
  view_url: "https://www.notion.so/91fad0f8a69446bcac7ee526a5523095?v=33df91672e0081428910000cd35c7abd"
```

Filter client-side: keep only records where `"date:Неделя (пн):start"` matches the target Monday date (ISO format `YYYY-MM-DD`).

Build a set of existing vacancy URLs from these records (field «Вакансия» — JSON array, take first element).

## Step 5: Deduplicate

Compare the active vacancies list (Step 3) against existing sync records (Step 4).

A record already exists if the vacancy URL matches. Only keep vacancies that do NOT have a sync record for the target week.

If all records already exist, inform the user and stop:

«Все записи на неделю W[##] уже созданы. Дубликатов не добавлено.»

## Step 6: Show Plan and Confirm

Show the user what will be created:

«**Создаю записи на W[##] ([DD.MM] – [DD.MM]):**

| Вакансия | Рекрутер |
|----------|----------|
| [vacancy title] | [recruiter name or URL] |
| ... | ... |

Всего: [N] новых записей (уже существует: [M])»

Use AskUserQuestion:
- question: as above
- options:
  - «Создать (Рекомендуется)» — proceed
  - «Отмена» — stop

If «Отмена» → stop.

## Step 7: Create Records

Create all missing records in a SINGLE `notion-create-pages` call:

```
mcp__claude_ai_Notion__notion-create-pages
  parent: { type: "data_source_id", data_source_id: "4c4aea05-80b3-45db-b977-91120cd30625" }
  pages: [
    {
      properties: {
        "Запись": "<Vacancy Title> — W<##>",
        "Вакансия": "[\"<vacancy page URL>\"]",
        "Клиент": "[\"<client page URL>\"]",
        "Рекрутер": "[\"<recruiter page URL>\"]",
        "date:Неделя (пн):start": "<target Monday YYYY-MM-DD>",
        "date:Неделя (пн):end": "<target Sunday YYYY-MM-DD>",
        "date:Неделя (пн):is_datetime": 0
      }
    },
    ...
  ]
```

## Step 8: Confirm

After successful creation, show:

«Готово! Создано [N] записей на W[##].

Рекрутерам нужно заполнить план/факт до понедельничного синка.

→ [Открыть таблицу синков](https://www.notion.so/91fad0f8a69446bcac7ee526a5523095)»
