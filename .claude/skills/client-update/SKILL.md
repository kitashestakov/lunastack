---
name: client-update
description: |
  Generate a progress update message for the client. Pulls pipeline data
  from Huntflow, follows Luna's client communication guide from Notion,
  produces a compact message ready to copy into Telegram.
  Use when: "апдейт клиенту", "client-update", "статус клиенту", "отчет клиенту".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance — especially client communication principles.

# /client-update — Апдейт клиенту

## Pre-check

Verify session has an active vacancy context.
If not: ask the recruiter which vacancy this update is for and query the Vacancies database:
```
mcp__claude_ai_Notion__notion-query-database-view
  view_url: "https://www.notion.so/32ef91672e0081af9a31dec4b6a3542f?v=32ef91672e008142b159000c00bbb0df"
```
Let the recruiter pick the vacancy from the list.

## Step 1: Load Context

1. Fetch the vacancy card from Notion — extract status, SLA, client name, position, dates.

2. Get Huntflow ID from the vacancy card, then pull pipeline data:
```bash
scripts/huntflow.sh vacancy-get <huntflow_id>
scripts/huntflow.sh applicants-list <huntflow_id>
```
Extract: total candidates, candidates per stage, new candidates added recently, any pending feedback.

3. Fetch the client communication guide from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "22af91672e008066a527e362b02160bc"
```
Read the structure and tone for status updates (Monday/Friday format, expected sections).

## Step 2: Ask for Additional Context

Use AskUserQuestion:
- question: «Есть что-то, что нужно добавить в апдейт? Например: запланированные интервью, задержки, наблюдения по рынку, запрос фидбека.»
- header: "Контекст"
- options:
  - "Сгенерируй по данным (Рекомендуется)" — use only Notion + Huntflow data
  - "Добавлю комментарий" — recruiter will add context manually

If recruiter adds context, incorporate it into the message.

## Step 3: Generate Update

Generate a client update message following the Notion guide format and ETHOS.md tone.

**Structure (5–10 sentences max):**

```
[Client name], добрый день!

Апдейт по позиции [Position]:

🔹 [Pipeline summary: N candidates total, X on screening, Y on interview, etc.]
🔹 [Specific actions: who's scheduled, what's pending]
🔹 [Market observations if relevant: response rate, candidate quality, competition]

[If there are blockers or risks — state them directly with data]
[If feedback is needed from the client — ask explicitly]

Следующие шаги: [concrete plan for the next period]

[Closing — appropriate to day: "Хорошей недели!" for Monday, "Отличных выходных!" for Friday]
```

**Rules:**
- Concise: 5–10 sentences, no filler
- Specific: numbers, names, dates — not "всё идет хорошо"
- Honest: if pipeline is weak or response rate is low — say so with data
- Actionable: always include next steps
- Follow ETHOS.md: proactive, partner-like tone, not a status report from a vendor
- If there are problems (low response, no suitable candidates, stalled feedback) — name them and propose solutions
- Use structural emoji (🔹, ⚠️) sparingly for readability

## Step 4: Review

Show the message to the recruiter.

Use AskUserQuestion:
- question: «Апдейт готов. Проверь и скажи, что поправить.»
- options:
  - "Всё верно, беру (Рекомендуется)" — done
  - "Поправить" — ask what to change
  - "Сделать короче" — condense further
  - "Добавить деталей" — expand specific sections

Iterate until confirmed.

Final message should be presented as a clean block, ready to copy-paste into the client's Telegram chat.

## Step 5: Save (Optional)

Use AskUserQuestion:
- question: «Сохранить апдейт в карточку вакансии?»
- options:
  - "Сохранить (Рекомендуется)"
  - "Не сохранять"

If saving:
```
mcp__claude_ai_Notion__notion-create-comment
  page_id: "<vacancy page ID>"
  rich_text: [{ text: { content: "Апдейт клиенту [date]:\n\n<message text>" } }]
```
