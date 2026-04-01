---
name: research
description: |
  Deep research on a company, market, competitors, and salary benchmarks.
  Replaces the old ChatGPT-based research workflow. Produces a structured
  report and optionally saves it to the vacancy card in Notion.
  Use when: "ресерч", "research", "исследование", "узнай про компанию".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /research — Deep Research

## Pre-check

Check if the session has an active vacancy context.
- If YES: use the vacancy's company and position as the default research subject.
- If NO: ask the recruiter what to research (company name, topic, etc.). This skill can work standalone.

## Step 1: Define Research Scope

If there's a vacancy context, fetch the vacancy card for existing info.

Use AskUserQuestion:
- question: «Что исследуем? Могу сфокусироваться на конкретных аспектах.»
- options:
  - "Полный ресерч (Рекомендуется)" — company + market + salaries + competitors
  - "Компания" — only company deep-dive
  - "Зарплаты и рынок" — salary benchmarks and market analysis
  - "Конкуренты" — competitor analysis for talent

## Step 2: Research

Run targeted WebSearch queries based on the chosen scope. For full research:

**Company research:**
- Company overview, products, tech stack
- Recent news, funding, growth trajectory
- Glassdoor/similar reviews, company culture
- Key people (founders, hiring managers if findable)

**Market research:**
- Industry trends relevant to the position
- Demand for this role type in the market
- Geographic considerations

**Salary benchmarks:**
- Salary ranges for the position (by geography, experience level)
- Compensation trends in the industry
- Stock/equity practices if relevant

**Competitor analysis:**
- Companies hiring for similar roles
- How competing offers typically look
- Unique selling points of this opportunity vs alternatives

## Step 3: Compile Report

Structure the report in Russian:

### 🏢 Компания
[Company overview, key facts, recent developments]

### 📊 Рынок и тренды
[Industry trends, demand for the role, geographic context]

### 💰 Зарплаты
[Salary ranges with sources, compensation structure norms]

### 🏆 Конкуренты за таланты
[Who else is hiring, how offers compare]

### 💡 Выводы и рекомендации
[Key takeaways for the recruiter: positioning, risks, opportunities]

## Step 4: Save

Present the report to the recruiter.

Use AskUserQuestion:
- question: «Ресерч готов. Сохранить в карточку вакансии?»
- options:
  - "Сохранить (Рекомендуется)"
  - "Не сохранять"

If saving and there's a vacancy context, update the vacancy card in Notion with the research report.
