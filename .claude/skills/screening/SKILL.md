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

Verify session has an active vacancy context (client + position + Notion page ID + Huntflow ID).
If not: «Сначала набери /vacancy, чтобы выбрать вакансию.»

## Step 1: Load Criteria

1. Fetch the vacancy card from Notion — extract:
   - Must-have requirements
   - Nice-to-have requirements
   - Red flags
   - Green flags
   - Compensation range
   - Any specific notes

2. Fetch the assessment methodology directly from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080beb984cabb8a2655c9"
```
Read the evaluation framework: criteria categories, scoring format, and recommendation structure.

## Step 2: Choose Candidate Source

Use AskUserQuestion:
- question: «Как получим данные о кандидате?»
- header: "Скрининг"
- options:
  - label: "Выбрать из воронки в Хантфлоу (Рекомендуется)"
    description: "Покажу список кандидатов по этой вакансии — выбери нужного"
  - label: "Приложить резюме или описание"
    description: "Вставь текст резюме, заметки или прикрепи файл"

### Option A: Select from Huntflow funnel

1. Fetch candidates for this vacancy:
```bash
scripts/huntflow.sh applicants-list <huntflow_id>
```

2. Parse the response — extract candidate list with: name, current stage, and applicant ID.

3. Show candidates via AskUserQuestion:
   - question: «Вот кандидаты по этой вакансии. Кого оцениваем?»
   - options: list candidates (up to 6, format: "[Name] — [Stage]") + «Нет в списке»

   If «Нет в списке» → fall through to Option B.

4. After the recruiter picks a candidate, fetch full profile:
```bash
scripts/huntflow.sh applicant-get <applicant_id>
```

5. Display ALL available data from the profile:

«**Данные кандидата из Хантфлоу:**

👤 **[Name]**
• Позиция: [position]
• Компания: [company]
• Телефон: [phone]
• Email: [email]
• Соцсети: [social links]

📄 **Резюме:**
[resume text if available]

🏷 **Теги:** [tags if any]
📝 **Комментарии:** [comments if any]»

6. Ask for additional notes:

Output as plain text, then wait:

«Есть ли дополнительная информация по кандидату? Заметки после звонка, впечатления, детали, которых нет в Хантфлоу. Если нет — напиши «нет».»

Wait for the recruiter to type their response.

### Option B: Resume or description

Output as plain text, then wait:

«Вставь текст резюме, заметки после звонка, или опиши кандидата своими словами.»

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

### Soft skills 🧠
| Навык | Оценка | Комментарий |
|-------|--------|-------------|
| Коммуникация | ✅ / ⚠️ / ❓ | [brief note] |
| Ownership | ✅ / ⚠️ / ❓ | [brief note] |
| Структурность мышления | ✅ / ⚠️ / ❓ | [brief note] |

### Мотивация 🎯
- Причина смены работы: [reason]
- Что ищет в следующей роли: [goals]
- Таймлайн: [timeline]
- Стоп-факторы: [stop factors if any]

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
  - If Продолжить: "Подготовить к интервью (Рекомендуется)" / "Оформить саммари (/summary)" / "Оценить другого кандидата"
  - If Обсудить: "Уточнить на скрининге (Рекомендуется)" / "Отклонить" / "Оценить другого"
  - If Отклонить: "Оценить другого кандидата (Рекомендуется)" / "Пересмотреть решение"
