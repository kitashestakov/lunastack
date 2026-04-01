---
name: outreach
description: |
  Compose personalized outreach messages for candidates. Reads vacancy
  description and tone-of-voice guide from Notion, generates channel-specific
  messages (LinkedIn, Telegram, email).
  Use when: "аутрич", "outreach", "сообщение кандидату", "написать кандидату".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance — this is especially critical for outreach.

# /outreach — Сообщения кандидатам

## Pre-check

Verify session has an active vacancy context.
If not: «Сначала набери /vacancy, чтобы выбрать вакансию.»

## Step 1: Load Context

1. Fetch the vacancy card from Notion — extract position, company, key requirements, selling points.

2. Fetch the outreach norms directly from Notion:
```
mcp__claude_ai_Notion__notion-fetch
  id: "2eaf91672e0080199eb5d4f974cc6f5a"
```
Read tone, structure, CDI-based personalization levels, follow-up cadence, channel guidelines, and anti-patterns.

## Step 2: Gather Candidate Context

Use AskUserQuestion:
- question: «Расскажи о кандидате: имя, текущая роль, что зацепило в профиле?»
- header: "Кандидат"
- options:
  - "Общее сообщение (Рекомендуется)" — generate a template that can be personalized
  - "Под конкретного кандидата" — recruiter provides details for a specific person

If specific candidate: ask for name, current role, what caught attention in their profile, channel (LinkedIn/Telegram/email).

## Step 3: Generate Messages

Based on ETHOS.md principles and the Notion outreach guide:

**Anti-patterns to avoid:**
- «У меня есть интересное предложение»
- «Уникальная возможность»
- Generic flattery without substance
- Walls of text

**Must include:**
- Specific reason why THIS person fits THIS role
- One concrete detail about the company/role that's genuinely interesting
- Clear ask (call, chat, etc.)
- Respect for their time

Generate messages for each requested channel:

### LinkedIn
- 300 characters max for connection request, 2000 for InMail
- Professional but not stiff
- Hook in the first line

### Telegram
- Shorter, more casual tone
- 3-5 sentences max
- Direct and respectful

### Email
- Subject line that doesn't look like spam
- Structured: hook → role → why them → ask
- Under 150 words

## Step 4: Review

Show all generated messages to the recruiter.

Use AskUserQuestion:
- question: «Вот варианты сообщений. Что-то поправить?»
- options:
  - "Всё отлично, беру" — done
  - "Поправить тон" — ask what to adjust
  - "Другой акцент" — ask what to emphasize differently
  - "Еще варианты" — generate alternatives

Iterate until the recruiter is satisfied.
