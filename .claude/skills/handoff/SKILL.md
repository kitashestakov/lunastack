---
name: handoff
description: |
  Transfer a vacancy to another recruiter with a structured summary.
  Compiles all data from Notion and Huntflow into a handoff document.
  Use when: "передача", "handoff", "передать вакансию", "передать коллеге".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /handoff — Передача вакансии

## Pre-check

Verify session has an active vacancy context.
If not: «Сначала набери /vacancy, чтобы выбрать вакансию.»

## Step 1: Identify New Recruiter

Use AskUserQuestion:
- question: «Кому передаем вакансию?»
- header: "Рекрутер"
- Let the recruiter type the name

Search the Team database to verify the person exists and is active:
```
mcp__claude_ai_Notion__notion-search
  query: "<name>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

Confirm: show name, role, specialization. Warn if specialization mismatch.

## Step 2: Compile Handoff

Gather all information:

1. **From Notion** — fetch the full vacancy card:
   - Status, SLA, dates
   - Client details (fetch the related Client page)
   - All comments and notes on the vacancy card
   - Conditions, financial terms

2. **From Huntflow** — get pipeline status:
```bash
scripts/huntflow.sh vacancy-get <huntflow_id>
scripts/huntflow.sh applicants-list <huntflow_id>
```

3. Generate the handoff document:

---

### 📋 Передача вакансии: [Client] — [Position]

**От:** [current recruiter]
**Кому:** [new recruiter]
**Дата:** [today]

#### Сводка по вакансии
- Клиент: [client]
- Позиция: [position]
- Статус: [status]
- SLA: [zone]
- Тип: [external/internal]
- Дата начала ИС: [date]

#### Финансы
- Зарплата: [salary]
- Комиссия: [fee]
- Предоплата: [prepayment]

#### Воронка кандидатов (Хантфлоу)
| Этап | Кандидатов |
|------|-----------|
| [stage] | [count] |
| ... | ... |
| **Всего** | **[total]** |

#### Ключевой контекст
- [Important notes from vacancy card comments]
- [Client preferences, communication style]
- [Any red flags or concerns]
- [What's been tried, what worked/didn't]

#### Следующие шаги
- [What needs to happen next based on current stage]
- [Any pending actions or deadlines]

---

## Step 3: Review and Approve

Show the handoff document to the recruiter.

Use AskUserQuestion:
- question: «Сводка для передачи готова. Хочешь что-то добавить или изменить?»
- options:
  - "Всё верно, сохранить (Рекомендуется)"
  - "Добавить комментарий" — ask what to add
  - "Отредактировать" — ask what to change

## Step 4: Save

If approved, save the handoff document as a comment on the vacancy card in Notion:
```
mcp__claude_ai_Notion__notion-create-comment
  page_id: "<vacancy page ID>"
  rich_text: [{ text: { content: "<handoff document>" } }]
```

Optionally update the Recruiter relation on the vacancy card to the new recruiter.

## Step 5: Done

«Передача оформлена и сохранена в карточке вакансии. [New recruiter] сможет увидеть всю информацию в Notion. Данные из чата передавать не нужно — всё в карточке.»
