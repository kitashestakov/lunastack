---
name: funnel-review
description: |
  Analyze the recruitment funnel for a vacancy: conversion rates,
  bottlenecks, rejection patterns. Compare against Notion benchmarks,
  produce actionable recommendations. Can trigger /outreach or /client-update.
  Use when: "ревью воронки", "funnel-review", "нет откликов", "много отказов",
  "почему не отвечают", "проанализировать воронку".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /funnel-review — Ревью воронки

## Pre-check

Verify session has an active vacancy context.
If not: ask the recruiter which vacancy to analyze and query the Vacancies database:
```
mcp__claude_ai_Notion__notion-query-database-view
  view_url: "https://www.notion.so/32ef91672e0081af9a31dec4b6a3542f?v=32ef91672e008142b159000c00bbb0df"
```
Let the recruiter pick the vacancy from the list.

## Step 1: Load Data

1. Fetch the vacancy card from Notion — extract status, SLA zone, CDI, start date, requirements.

2. Get Huntflow ID, then pull full pipeline data:
```bash
scripts/huntflow.sh vacancy-get <huntflow_id>
scripts/huntflow.sh applicants-list <huntflow_id>
```
Extract: all candidates, their current statuses, dates of status changes, rejection reasons (if available).

3. Fetch the search strategy guide from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080d7aae8fd8403d8c672"
```

4. Fetch the outreach norms from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080199eb5d4f974cc6f5a"
```
Extract: benchmark conversion rates by CDI level, outreach volume norms, follow-up standards.

## Step 2: Calculate Metrics

Compute conversion rates for each funnel stage:

| Этап | Кандидатов | Конверсия | Норма (по CDI) | Статус |
|------|-----------|-----------|---------------|--------|
| Outreach отправлено | [N] | — | — | — |
| Ответили | [N] | [X%] | [benchmark]% | ✅/⚠️/🔴 |
| Скрининг проведен | [N] | [X%] | [benchmark]% | ✅/⚠️/🔴 |
| Показано клиенту | [N] | [X%] | — | — |
| Интервью с клиентом | [N] | [X%] | — | — |
| Оффер | [N] | [X%] | — | — |

Status indicators:
- ✅ — at or above benchmark
- ⚠️ — below benchmark but within tolerance (e.g., 1 week into search)
- 🔴 — significantly below benchmark or persistent pattern

Also analyze:
- **Time in pipeline**: how long candidates stay at each stage (delays = risk)
- **Rejection patterns**: group rejections by reason if available (stack mismatch, grade, salary, soft skills, culture)
- **Outreach volume**: compare actual outreach volume against norms for this CDI level
- **Follow-up compliance**: are follow-ups being sent per the standard cadence?

## Step 3: Identify Bottleneck

Determine where the primary bottleneck is:

**Low response rate (outreach → reply):**
- Message quality issue? (generic, too long, wrong channel)
- Targeting issue? (wrong profile, wrong seniority)
- Timing issue? (sent at wrong times)
- Volume issue? (not enough outreach for CDI level)

**Low screening conversion (reply → screening):**
- Candidate loses interest between reply and call?
- Too slow to schedule?
- Compensation mismatch revealed early?

**Low client conversion (screening → client interview):**
- Candidate quality not matching expectations?
- Packaging issue? (how candidates are presented)
- Profile mismatch? (must-haves unclear or shifting)

**High rejection at interview:**
- Pattern in rejection reasons? (same reason = systemic issue)
- Prep quality? (candidates not prepared for client format)
- Profile drift? (client expectations changed since briefing)

## Step 4: Report

Present the analysis to the recruiter as a structured report:

---

**Ревью воронки: [Client] — [Position]**
Период: [start date] — сегодня ([N] дней)

**Метрики:**
[Table from Step 2]

**Узкое место:** [which stage]

**Почему:**
• [hypothesis 1 with supporting data]
• [hypothesis 2 with supporting data]

**Паттерны отказов:** [if applicable]
• [reason 1]: [N] кандидатов ([X]%)
• [reason 2]: [N] кандидатов ([X]%)

**Рекомендации:**
1. [Specific, actionable recommendation]
2. [Specific, actionable recommendation]
3. [Specific, actionable recommendation]

---

## Step 5: Next Actions

Use AskUserQuestion:
- question: «Вот анализ воронки. Что делаем?»
- options (show relevant ones based on the bottleneck):
  - "Обновить текст outreach" — if bottleneck is response rate. Read `.claude/skills/outreach/SKILL.md` and execute the outreach skill inline.
  - "Подготовить апдейт клиенту с корректировкой" — if profile/expectations need adjusting. Read `.claude/skills/client-update/SKILL.md` and execute it inline, pre-filling context with the funnel review findings.
  - "Скорректировать стратегию поиска" — discuss strategy changes with the recruiter
  - "Принять к сведению" — no immediate action, recruiter will act on recommendations manually

If the recruiter chooses to trigger /outreach or /client-update:
- Read the respective SKILL.md from disk
- Execute it inline, passing the funnel review context (bottleneck, recommendations) so the generated output is informed by the analysis
