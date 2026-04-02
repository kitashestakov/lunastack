---
name: briefing
description: |
  Pre-briefing preparation for a client meeting. Reads the briefing guide
  from Notion, runs web research on the company and position, generates
  structured questions for the client, saves results to the vacancy card.
  Use when: "брифинг", "подготовка к брифингу", "briefing", "встреча с клиентом".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /briefing — Подготовка к брифингу

## Pre-check

Verify that the session has an active vacancy context (client + position + Notion page ID).
If not: «Сначала набери /vacancy, чтобы выбрать или создать вакансию.»

## Step 1: Load Context

1. Read the recruiter's config:
```bash
cat ~/.luna-stack/config.yaml
```

2. Fetch the vacancy card from Notion to get company name, position, current status, any existing notes.

3. Fetch the briefing guide from Notion — this defines the structure for all question preparation:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2f7f91672e0080caa7f2c0fbc6afe0dd"
```
Read the full guide. Use its 8-block structure to organize questions and preparation materials. This ensures future guide updates auto-propagate.

Also fetch the stage guide for additional context:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2e2f91672e0080318d36c9c1d39680b4"
```

## Step 2: Research

Run multiple web searches to gather context:

1. **Company info**: search for company name, what they do, size, funding, recent news
2. **Position context**: search for similar roles in the market, typical requirements, salary ranges
3. **Industry/market**: search for trends in the company's industry relevant to the role

Use WebSearch for each query. Compile findings.

## Step 3: Generate Briefing Prep

Create a structured document. Use the 8 blocks from the Notion briefing guide as the organizing framework:

### О компании (Блок 2 из гайда: Компания и контекст)
- Краткое описание, размер, индустрия
- Последние новости и события
- Культура и ценности (если нашлось)

### Позиция на рынке
- Типичные требования для аналогичных ролей
- Зарплатная вилка по рынку
- Конкуренция за кандидатов (высокая/средняя/низкая)

### Вопросы для клиента
Generate 10-15 targeted questions based on the Notion briefing guide structure, gaps in the vacancy card, industry context, and red/green flags.

**Group questions by the 8 blocks from the Notion guide:**
1. Открытие — формат, участники, кто принимает решение
2. Компания и контекст — продукт, стадия, цели, почему нанимают сейчас
3. Роль и функционал — задачи на 90 дней, зоны ответственности, подчинение
4. Компетенции и скоринг — must-have навыки, уровни, минимальные пороги
5. Портрет и антипортрет — компании-доноры, red flags, предыдущий опыт найма
6. Финансы и KPI — вилка, бонусы, KPI с порогами, критерии ИС
7. Процесс и сроки — этапы интервью, тестовое, SLA по фидбеку, дедлайн
8. Продажа ценности — USP компании для кандидатов, перспективы роста

### Шаблон скоринг-таблицы компетенций
Based on Block 4 of the Notion briefing guide, prepare a blank scoring table template for the recruiter to fill during the briefing:

```
| Компетенция | Категория | Ожидаемый уровень (1-10) | Минимум | Комментарий |
|-------------|-----------|-------------------------|---------|-------------|
| [из ресерча] | Ключевая / Основная / Дополнительная | — | — | — |
```

Pre-fill competency names based on the research findings and vacancy card, but leave levels blank — the recruiter fills them during the briefing with the client. Include 5-8 suggested competencies.

### Рекомендации
- Key points to emphasize during the briefing
- Potential concerns or risks to address
- Suggested pристрелочный кандидат strategy (from Notion guide)

## Step 4: Review and Save

Show the full briefing prep to the recruiter.

Use AskUserQuestion:
- question: «Подготовка к брифингу готова. Сохранить в карточку вакансии в Notion?»
- options:
  - "Сохранить (Рекомендуется)" — save to vacancy sub-pages
  - "Отредактировать" — ask what to change
  - "Не сохранять" — keep in chat only

### Saving to Notion sub-pages

The vacancy template contains dedicated sub-pages for briefing output. **Do NOT use hardcoded page IDs** — each vacancy has its own instances with different IDs.

**Finding sub-pages:**
1. Fetch the vacancy page content:
```
mcp__claude_ai_Notion__notion-fetch
  id: "<vacancy page URL or ID>"
```
2. Look for child pages by title in the content section:
   - «Чеклист брифинга» — for the briefing checklist (questions + preparation)
   - «Скоринг-таблица» — for the competency scoring table
   - «Транскрибт брифинга» — for the briefing transcript (filled after the meeting)
3. Get the URL/ID of each found sub-page.

**Saving content:**
- **Чеклист брифинга**: save the questions for the client (Step 3 output: all 8 blocks of questions + recommendations) using `notion-update-page` with `command: "replace_content"`.
- **Скоринг-таблица**: save the blank scoring table template (Step 3 output: competency table with pre-filled names, empty levels) using `notion-update-page` with `command: "replace_content"`.
- **Транскрибт брифинга**: leave empty — the recruiter fills it during/after the meeting.

If a sub-page is not found by title, warn the recruiter: «Не нашла страницу «[name]» в карточке вакансии. Возможно, шаблон был изменен.»

## Step 5: Next Steps

After saving, suggest:
- «После брифинга вернись в эту сессию — заполни транскрипт и скоринг-таблицу по результатам встречи. Могу помочь с /research для углубленного анализа или /outreach для первых сообщений кандидатам.»
