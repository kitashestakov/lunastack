---
name: vacancy-card
description: |
  Draft external vacancy description (for candidates) and internal position
  profile (requirements, bottlenecks, red/green flags). Reads the vacancy
  formatting guide from Notion, follows ETHOS tone of voice. Saves both
  documents to the vacancy card in Notion after recruiter approval.
  Use when: "оформление вакансии", "vacancy-card", "описание вакансии",
  "внешнее описание", "внутреннее описание", "оформить вакансию".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance — this is critical for the external description.

# /vacancy-card — Оформление описаний вакансии

## Pre-check

Verify session has an active vacancy context.
If not: «Сначала набери /vacancy, чтобы выбрать вакансию.»

## Step 1: Load Vacancy Data

1. Fetch the vacancy card from Notion — extract: position, company, requirements, CDI (Critical Decision Items), SLA zone, salary range, conditions, comments.

2. Check if `/research` results exist in the vacancy card (look for a research report section in page content).
   - If research results exist: use them as input for descriptions.
   - If NO research results:

   Use AskUserQuestion:
   - question: «В карточке вакансии нет результатов ресерча. Ресерч — основа для качественного описания: данные о компании, рынке и конкурентах помогут сделать текст убедительнее. Запустить /research сначала?»
   - header: "Ресерч"
   - options:
     - label: "Запустить /research (Рекомендуется)"
       description: "Соберу данные о компании, рынке и зарплатах — это займет пару минут"
     - label: "Продолжить без ресерча"
       description: "Оформлю описания на основе того, что есть в карточке"

   If recruiter chooses research: read `.claude/skills/research/SKILL.md` and execute the /research flow, then return here.

## Step 2: Load Formatting Guide

Fetch the vacancy formatting guide from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e008025a2fbf9cb878d5d8e"
```

If the page has content — follow its structure, rules, and format strictly.
If the page is blank — use the default structure defined in Steps 3 and 4 below.

<!-- TODO: fill Notion page 2eaf91672e008025a2fbf9cb878d5d8e with formatting guidelines -->

## Step 3: Generate External Description

Compose the external vacancy description — a text ready to send to candidates via Telegram or LinkedIn.

**Structure:**
1. **Компания** — 2-3 предложения: чем занимается, масштаб, что интересного (use research data if available)
2. **Позиция** — название, уровень, команда
3. **Задачи** — 4-6 ключевых задач, конкретно и без воды
4. **Требования** — must-have навыки и опыт (from vacancy card requirements + CDI)
5. **Условия** — формат работы, зарплатная вилка (если раскрывается), бонусы, benefits

**Tone of voice rules (from ETHOS.md):**
- Вежливо, конструктивно, уверенно — без корпоративного шаблонного языка
- Конкретика вместо абстракций: «стек: Python, FastAPI, PostgreSQL» вместо «современные технологии»
- Не продавать — информировать. Кандидат должен понять, подходит ли ему позиция
- 80-150 слов — коротко и по делу
- Эмодзи допустимы точечно для структурирования (🔹, 📍), не для украшения

**Anti-patterns to avoid:**
- «Уникальная возможность», «динамично развивающаяся компания», «молодой дружный коллектив»
- Размытые требования: «опыт работы с базами данных» без указания конкретных технологий
- Перечисление 15+ требований — кандидат не дочитает

Present the external description to the recruiter.

## Step 4: Review External Description

Use AskUserQuestion:
- question: «Внешнее описание готово. Проверь — оно пойдет кандидатам в Telegram/LinkedIn. Что-то поправить?»
- header: "Внешнее описание"
- options:
  - label: "Всё отлично (Рекомендуется)"
    description: "Переходим к внутреннему описанию"
  - label: "Поправить тон"
    description: "Скажи, что изменить — сделаю формальнее/неформальнее"
  - label: "Другой акцент"
    description: "Скажи, на чем сфокусироваться — задачи, стек, условия"
  - label: "Переписать"
    description: "Сгенерирую новый вариант с нуля"

Iterate until the recruiter is satisfied.

## Step 5: Generate Internal Description

Compose the internal position profile — a detailed document for the recruiting team.

**Structure:**

### 📋 Профиль позиции
- **Позиция:** [название]
- **Компания / клиент:** [название]
- **Грейд:** [junior / middle / senior / lead]
- **Локация / формат:** [офис / гибрид / удаленно, город]
- **Вилка:** [диапазон]

### ✅ Must-have (обязательные требования)
- [Требование 1 — конкретно, с указанием уровня/стажа/технологий]
- [Требование 2]
- ...

### ➕ Nice-to-have (желательные)
- [Требование 1]
- ...

### 🔑 Bottlenecks (ключевые навыки — на чем отсеивается большинство)
- [Навык/компетенция 1 — почему это bottleneck]
- [Навык/компетенция 2]

### 🟢 Green flags (сигналы сильного кандидата)
- [Сигнал 1]
- ...

### 🔴 Red flags (сигналы, что кандидат не подойдет)
- [Сигнал 1]
- ...

### 💬 Комментарии
- [Особенности процесса, пожелания клиента, нюансы позиции]
- [Что важно знать при скрининге]

**Rules:**
- Bottlenecks — самые важные: это то, что отличает подходящего кандидата от неподходящего. Выделяй 2-4 ключевых.
- Green/red flags должны быть конкретными и проверяемыми на скрининге, а не абстрактными («мотивирован» — плохо, «ушел с прошлого места из-за потолка роста и ищет лидерскую роль» — хорошо)
- Must-have vs nice-to-have: если сомневаешься — спроси рекрутера

## Step 6: Review Internal Description

Use AskUserQuestion:
- question: «Внутреннее описание готово. Проверь — это рабочий документ для скрининга и оценки кандидатов. Что-то поправить?»
- header: "Внутреннее описание"
- options:
  - label: "Всё отлично (Рекомендуется)"
    description: "Оба документа готовы — переходим к сохранению"
  - label: "Поправить требования"
    description: "Скажи, что перенести из must в nice-to-have или наоборот"
  - label: "Дополнить flags/bottlenecks"
    description: "Добавлю или изменю сигналы и ключевые навыки"
  - label: "Переписать"
    description: "Сгенерирую новый вариант с нуля"

Iterate until the recruiter is satisfied.

## Step 7: Save to Notion

Use AskUserQuestion:
- question: «Оба документа согласованы. Сохранить в карточку вакансии в Notion?»
- header: "Сохранение"
- options:
  - label: "Сохранить (Рекомендуется)"
    description: "Добавлю оба описания в карточку вакансии"
  - label: "Не сохранять"
    description: "Документы останутся только в этом чате"

If saving:
1. Update the vacancy page content in Notion — append both descriptions as separate sections:
   - Section «Внешнее описание (для кандидатов)»
   - Section «Внутреннее описание (профиль позиции)»

2. Confirm: «Описания сохранены в карточку вакансии ✓»

## Step 8: Next Steps

«Следующий шаг: согласуй внешнее описание с клиентом — отправь ему в чат. После апрува запусти /outreach, чтобы составить первое касание для кандидатов.»
