---
name: summary
description: |
  Generate a structured candidate summary after a screening call.
  Reads vacancy criteria from Notion, applies assessment methodology,
  produces a compact summary ready to send to the client via Telegram.
  Use when: "саммари", "summary", "оформить кандидата", "после скрининга".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance — especially the sections on candidate packaging and client communication.

# /summary — Саммари кандидата после скрининга

## Pre-check

Verify session has an active vacancy context.
If not: ask the recruiter which vacancy this summary is for.

If no vacancy context, search the Vacancies database:
```
mcp__claude_ai_Notion__notion-search
  query: "<vacancy name from recruiter>"
  data_source_url: "collection://32ef9167-2e00-8102-ba94-000b387a05bb"
```
Fetch the full vacancy card. Extract: must-have, nice-to-have, red/green flags, compensation range, client preferences, position details.

## Step 1: Load Assessment Methodology

Fetch the assessment methodology from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080beb984cabb8a2655c9"
```
Read the evaluation framework, scoring criteria, and assessment structure.

## Step 2: Get Candidate Information

Use AskUserQuestion:
- question: «Как передашь информацию о кандидате?»
- header: "Формат"
- options:
  - "Вставлю текст (Рекомендуется)" — recruiter will paste screening transcript, notes, or summary
  - "Расскажу своими словами" — recruiter will describe the candidate verbally
  - "Загружу файл" — recruiter will share a file with notes

Wait for the recruiter to provide the candidate information.

Then ask:
- question: «Как зовут кандидата?»
- header: "Имя"
- Let recruiter type the name (free text)

## Step 3: Generate Summary

Based on the vacancy criteria, assessment methodology, and candidate information, generate a structured summary.

**Format — compact, ready to copy-paste into Telegram:**

```
[Имя Фамилия] — [Позиция]

Сильные стороны:
• [strength 1 — tied to specific vacancy requirement]
• [strength 2]
• [strength 3]

Возможные риски:
• [risk 1 — with context/mitigation if applicable]
• [risk 2]

Оценка:
[Assessment based on the Notion methodology — use the framework from the fetched page. Score or grade as defined in the methodology.]

Must-have: [X из Y выполнено]
[List which must-haves are met/not met, briefly]

Рекомендация: [Показать клиенту / Обсудить / Не показывать]
[1-2 sentences explaining why]
```

**Rules for the summary:**
- Write in Russian
- Keep it compact — the recruiter will copy this into a Telegram message to the client
- Strengths must be tied to THIS vacancy's requirements, not generic qualities
- Risks must be honest — follow ETHOS.md: "лучше показать ограничения, чем получить недоверие"
- Use the assessment methodology scoring exactly as defined in Notion
- If information is insufficient for a proper assessment — explicitly note which areas need clarification

## Step 4: Review

Show the summary to the recruiter.

Use AskUserQuestion:
- question: «Саммари готово. Проверь и скажи, что поправить.»
- options:
  - "Всё верно (Рекомендуется)" — proceed to save
  - "Поправить" — ask what to change
  - "Переделать" — regenerate with different emphasis

Iterate until confirmed.

## Step 5: Save

Use AskUserQuestion:
- question: «Сохранить саммари в карточку вакансии в Notion?»
- options:
  - "Сохранить (Рекомендуется)" — save as a comment on the vacancy page
  - "Не сохранять" — keep in chat only

If saving:
```
mcp__claude_ai_Notion__notion-create-comment
  page_id: "<vacancy page ID>"
  rich_text: [{ text: { content: "Саммари после скрининга: <candidate name>\n\n<summary text>" } }]
```

## Step 6: Next Steps

Use AskUserQuestion:
- question: «Что дальше?»
- options:
  - "Оформить ещё одного кандидата" — loop back to Step 2
  - "Подготовить кандидата к интервью" — suggest reading the prep guide
  - "Отправить апдейт клиенту" — suggest /client-update
