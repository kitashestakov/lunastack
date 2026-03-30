---
name: admin-audit
description: |
  Admin-only. Audit synchronization between Notion content and Luna Stack
  skill files. Validates dynamic Notion references, compares static content
  against source pages, reports divergences, and offers to fix them.
  Use when: "аудит", "audit", "синхронизация", "проверить Notion".
---

# /admin-audit — Аудит синхронизации Notion и Luna Stack

## Step 0: Permission Check

Before anything else, verify the user has push access to the repository:

```bash
git push --dry-run 2>&1
```

If the command returns an error (permission denied, no remote configured, authentication failed, etc.) — **stop immediately**. Display:

«Эта команда доступна только администраторам Luna Stack. Если тебе нужно что-то обновить — обратись к администратору.»

Do not show technical error details. Do not proceed to Step 1.

If the dry-run succeeds — proceed.

## Step 1: Inventory

Read all project files that reference Notion or contain hardcoded Notion-derived content:

- `ETHOS.md`
- `CLAUDE.md`
- `lib/preamble.md`
- All `SKILL.md` files in `.claude/skills/*/`

For each file, compile two lists:

### Dynamic references
Notion page IDs that the skill fetches at runtime via MCP tools (e.g. `mcp__claude_ai_Notion__notion-fetch` calls with hardcoded IDs). These auto-update when the Notion page changes, so they only need existence validation.

Pattern to look for:
- `id: "<page_id>"` in MCP tool calls
- `data_source_url: "collection://<id>"` in search calls
- Direct page IDs in fetch instructions

### Static content
Text, principles, field names, stage names, status lists, or workflows that were derived from Notion but are hardcoded in the file. These do NOT auto-update and can drift.

Examples:
- Vacancy statuses list in CLAUDE.md
- SLA zones in CLAUDE.md
- Communication principles in ETHOS.md
- Stage sequences and completion criteria in SKILL.md files
- Database field names referenced in skills

## Step 2: Validate Dynamic References

For each unique Notion page ID or data source ID found in Step 1:

```
mcp__claude_ai_Notion__notion-fetch
  id: "<page_id or collection://id>"
```

Check:
- Page exists and is accessible → OK
- Page returns error, is deleted, or moved → flag as **error**
- Page title changed significantly → flag as **warning** (the reference may be stale)

## Step 3: Compare Static Content

For each piece of static content identified in Step 1, fetch the corresponding Notion source and compare key elements.

### ETHOS.md
Source pages: mission/vision, client communication principles, candidate communication principles, outreach norms, objection handling, candidate packaging, anti-patterns.

Fetch the parent knowledge page and navigate to source sections:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080d2a7eafc2819c79f7b"
```

Compare:
- Tone of voice rules
- Outreach structure and anti-patterns
- Client communication principles
- Candidate handling rules (rejections, objections, packaging)

### CLAUDE.md
Source: Vacancies database schema, Team database schema.

```
mcp__claude_ai_Notion__notion-fetch
  id: "collection://32ef9167-2e00-8102-ba94-000b387a05bb"
```

Compare:
- Vacancy status options (the hardcoded list vs database schema)
- SLA zone options
- Database field names referenced anywhere in skills
- Knowledge page IDs (do they still point to the right pages?)

### Individual SKILL.md files
For skills that reference specific Notion stage guides (briefing, screening, outreach, etc.), fetch the corresponding stage page and compare:
- Step sequences
- Trigger conditions
- Completion criteria
- Any hardcoded text that mirrors Notion content

## Step 4: Report

Output a structured report in Russian:

```
## Результаты аудита

**✅ Синхронизировано:**
- [file] ↔ [Notion page/section] — совпадает

**⚠️ Требует внимания:**
- [file]: [what diverges] — [suggested action]

**❌ Ошибки:**
- [file]: ссылка на [page ID] — страница не найдена / недоступна
```

Group items by severity: errors first, then warnings, then OK items.

## Step 5: Fix

For each item in the "Требует внимания" section, use AskUserQuestion:

- question: «В [file] содержимое расходится с Notion. [Конкретное описание расхождения]. Обновить файл?»
- header: "Аудит"
- options:
  - label: "Обновить (Рекомендуется)"
    description: "Приведу файл в соответствие с текущим содержимым Notion"
  - label: "Пропустить"
    description: "Оставить как есть — возможно, расхождение намеренное"

If the user approves — make the edit. Show the diff before applying.

If all items are skipped or there are no warnings — skip to Step 6.

## Step 6: Commit

If any files were changed, use AskUserQuestion:

- question: «Внесены изменения в [N] файл(ов). Закоммитить и запушить?»
- header: "Коммит"
- options:
  - label: "Закоммитить и запушить (Рекомендуется)"
    description: "Создам коммит с описанием всех изменений"
  - label: "Только закоммитить"
    description: "Коммит без пуша — запушишь позже"
  - label: "Не коммитить"
    description: "Изменения останутся незакоммиченными"

Commit message format:
```
sync: update [files] to match current Notion content

- [brief description of each change]
```
