---
name: screening
description: |
  Evaluate a candidate against vacancy criteria using Luna Pastel's
  assessment methodology from Notion. Produces a structured assessment
  with recommendation.
  Use when: "скрининг", "screening", "оценить кандидата", "подходит ли кандидат".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /screening — Оценка кандидата

## Pre-check

Verify session has an active vacancy context.
If not: «Сначала набери /vacancy, чтобы выбрать вакансию.»

## Step 1: Load Criteria

1. Fetch the vacancy card from Notion — extract:
   - Must-have requirements
   - Nice-to-have requirements
   - Red flags
   - Green flags
   - Compensation range
   - Any specific notes

2. Fetch the screening/assessment methodology from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080d2a7eafc2819c79f7b"
```
Navigate to the assessment methodology section (методика оценки).

## Step 2: Get Candidate Info

Use AskUserQuestion:
- question: «Расскажи о кандидате. Можешь вставить резюме, заметки после звонка, или описать своими словами.»
- header: "Кандидат"
- options:
  - "Вставлю текст" — recruiter will paste resume/notes in the next message
  - "Опишу устно" — recruiter will describe the candidate

Wait for the recruiter to provide candidate information.

## Step 3: Evaluate

Assess the candidate against the vacancy criteria. For each criterion:

### Must-have ✅/❌
| Критерий | Оценка | Комментарий |
|----------|--------|-------------|
| [requirement] | ✅ / ❌ / ❓ (нет данных) | [brief note] |

### Nice-to-have ➕/➖
| Критерий | Оценка | Комментарий |
|----------|--------|-------------|
| [requirement] | ➕ / ➖ / ❓ | [brief note] |

### Red flags 🚩
List any detected red flags from the methodology.

### Green flags 🟢
List any positive signals.

### Зарплатные ожидания
Compare candidate expectations (if known) with the vacancy range.

## Step 4: Recommendation

Provide a clear recommendation:

**Рекомендация: [Продолжить / Обсудить / Отклонить]**

- **Продолжить** — candidate meets must-haves, no critical red flags
- **Обсудить** — some concerns but worth discussing further (specify what to clarify)
- **Отклонить** — critical must-have gaps or clear red flags (specify which)

Always explain the reasoning.

## Step 5: Next Steps

Use AskUserQuestion:
- question: «Как поступим с этим кандидатом?»
- options based on recommendation:
  - If Продолжить: "Подготовить к интервью (Рекомендуется)" / "Оценить другого кандидата"
  - If Обсудить: "Уточнить на скрининге (Рекомендуется)" / "Отклонить" / "Оценить другого"
  - If Отклонить: "Оценить другого кандидата (Рекомендуется)" / "Пересмотреть решение"
