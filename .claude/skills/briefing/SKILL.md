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

3. Fetch the briefing preparation guide from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2e2f91672e0080dab243e176cbe88eb7"
```
Navigate to Stage 1 (Подготовка к брифингу) content. Read the specific guidelines for what to prepare.

## Step 2: Research

Run multiple web searches to gather context:

1. **Company info**: search for company name, what they do, size, funding, recent news
2. **Position context**: search for similar roles in the market, typical requirements, salary ranges
3. **Industry/market**: search for trends in the company's industry relevant to the role

Use WebSearch for each query. Compile findings.

## Step 3: Generate Briefing Prep

Create a structured document with these sections:

### О компании
- Краткое описание, размер, индустрия
- Последние новости и события
- Культура и ценности (если нашлось)

### Позиция на рынке
- Типичные требования для аналогичных ролей
- Зарплатная вилка по рынку
- Конкуренция за кандидатов (высокая/средняя/низкая)

### Вопросы для клиента
Generate 10-15 targeted questions based on:
- The Notion briefing guide structure
- Gaps in the vacancy card (missing info)
- Industry-specific considerations
- Red/green flags to clarify

Group questions by category:
- О позиции (must-have, nice-to-have, задачи, команда)
- О процессе (этапы, сроки, принятие решений)
- О кандидате (профиль, soft skills, red flags)
- О компенсации (вилка, бонусы, условия)

### Рекомендации
- Key points to emphasize during the briefing
- Potential concerns or risks to address

## Step 4: Review and Save

Show the full briefing prep to the recruiter.

Use AskUserQuestion:
- question: «Подготовка к брифингу готова. Сохранить в карточку вакансии в Notion?»
- options:
  - "Сохранить (Рекомендуется)" — save to vacancy card comments/content
  - "Отредактировать" — ask what to change
  - "Не сохранять" — keep in chat only

If saving, use `mcp__claude_ai_Notion__notion-update-page` to add the briefing prep to the vacancy card content.

## Step 5: Next Steps

After saving, suggest:
- «После брифинга вернись в эту сессию и обнови карточку вакансии с результатами встречи. Могу помочь с /research для углубленного анализа или /outreach для первых сообщений кандидатам.»
