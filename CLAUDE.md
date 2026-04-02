# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Luna Stack

Luna Stack is a set of Claude Code skills for the Luna Pastel recruiting agency. Recruiters use Claude Desktop (Code mode) with slash commands to manage vacancies, prepare for briefings, research companies, compose outreach messages, and evaluate candidates.

**Users are non-technical recruiters.** They interact only through slash commands and AskUserQuestion prompts. All user-facing communication MUST be in Russian. System files and prompts are in English.

**Required model:** Claude Opus 4.6 (set during /onboarding).

## Skills

- `/onboarding` — One-time setup: name, tokens, model switch, bypass permissions
- `/vacancy` — Main entry point: find or create vacancy, show Notion + Huntflow status, suggest next actions
- `/briefing` — Pre-briefing preparation: read Notion guide, web research, generate questions for client
- `/vacancy-card` — Draft external vacancy description for candidates + internal position profile (requirements, bottlenecks, red/green flags)
- `/research` — Deep research: company, market, competitors, salary benchmarks
- `/outreach` — Compose candidate outreach messages following Notion tone-of-voice guide
- `/screening` — Evaluate candidate against vacancy criteria and Notion methodology
- `/summary` — Generate structured candidate summary after screening, ready for Telegram to client
- `/client-update` — Generate progress update message for the client with Huntflow pipeline data
- `/funnel-review` — Analyze recruitment funnel: conversion rates, bottlenecks, rejection patterns, recommendations
- `/handoff` — Transfer vacancy to another recruiter with structured summary
- `/luna-upgrade` — Update skills via git pull, show what changed

## Admin Skills

- `/admin-audit` — Audit synchronization between Notion content and Luna Stack files (requires push access)

## Architecture Rules

### One Session = One Vacancy
- Each vacancy is worked in a dedicated session
- `/vacancy` binds the session to a specific vacancy; subsequent skills operate on that vacancy
- If a recruiter tries to start a new vacancy in an existing session, block and explain: create a new session
- Session naming convention: `[Client] — [Position] (month year)` (e.g., `TechCorp — Frontend Dev (март 2026)`)

### Skill Execution Pattern
- Every skill reads `lib/preamble.md` first and follows all rules defined there
- Every skill reads `ETHOS.md` for tone of voice guidance
- Skills can read and invoke other skills inline (read the target SKILL.md from disk and execute)
- Config is loaded from `~/.luna-stack/config.yaml` (created by /onboarding)

### AskUserQuestion Standard Format
All questions to the recruiter follow this structure:
1. **Context**: what is happening right now
2. **Question**: what needs to be decided
3. **Recommendation**: suggested option with reasoning
4. **Options**: 2-4 concrete choices (A/B/C), recommendation first

Never ask open-ended "что ты хочешь сделать?" — always propose specific next steps.

### Typography (Russian text)
1. Never use the letter ё, EXCEPT where meaning changes (все vs всё, всем vs всём). In all other cases use е
2. Russian quotation marks: always use «елочки», never "лапки"
3. English words inside Russian text: use "double quotes"
4. Never mix: «English» is wrong, "русский" is wrong

## Notion

### Databases

| Database | Data Source | Access |
|----------|-----------|--------|
| Вакансии (Vacancies) | `collection://32ef9167-2e00-8102-ba94-000b387a05bb` | Read + Write |
| Клиенты (Clients) | `collection://32ef9167-2e00-81fe-8524-000b62b3305f` | Read + Write |
| Команда (Team) | `collection://32ef9167-2e00-8158-ba59-000b70b0a852` | **Read-only** |

### Templates

| Template | ID | Usage |
|----------|-----|-------|
| Шаблон вакансии | `330f9167-2e00-804a-a321-c08895fea043` | Always apply when creating new vacancy pages via notion-create-pages |

### Knowledge Pages

| Section | Page ID |
|---------|---------|
| Процесс и знания (8 vacancy stages) | `2e2f91672e0080dab243e176cbe88eb7` |
| Гайды, шаблоны, регламенты | `2eaf91672e0080d2a7eafc2819c79f7b` |

### Vacancy Statuses
Active Search, Test period, Vacancy closed, On Hold, Test period failed, Failed

### Vacancy SLA Zones
A-зона, В-зона, С-зона

## Huntflow

- **API**: REST v2 at `https://api.huntflow.ai/v2/`
- **Account type**: Agency (Кадровое Агентство)
- **Wrapper**: `scripts/huntflow.sh <subcommand> [args]`
- **Link to Notion**: field "Huntflow ID" in Vacancies database

- **Account ID**: `18980` (hardcoded, same for all recruiters)
- **Division IDs**: `10665` (Внешняя вакансия, default), `10666` (Внутренняя вакансия)

Key subcommands: `vacancy-create`, `vacancy-get`, `vacancy-list`, `vacancy-update`, `applicants-list`, `applicant-add`, `applicant-move`, `dict-clients`, `dict-client-add`, `dict-client-find`, `members`, `member-find`

### Huntflow Custom Fields

| Field key | Title | Type | Notes |
|-----------|-------|------|-------|
| `N6zxOoJFHT4o9du_TFbCk` | Клиент | dictionary (`klienty`) | Client name via dictionary, not account_division |
| `sVaF1tOBRcHly6QfzP0Zi` | Минимальный уровень | select | Junior / Middle / Senior |
| `B-bluqQuHGP6VO2xotQqq` | Локация | string | |
| `gU2RJ4D0IkrLsjzlt_GJV` | Вид занятости | select | Contractor / Part-time / Full-time |
| `6rfxdBMppArERGgXLTmao` | Дата последнего рестарта | date | |

## Security Model

### Layer 1: Prompt (CLAUDE.md + preamble.md)
- Never delete anything in Notion, Huntflow, or local files
- Never create or modify database schemas
- Always confirm before writing to Notion
- Never access vacancies not belonging to the current recruiter
- No arbitrary actions outside defined skill flows
- DO NOT read or rely on Claude Code project memory files (user_*.md in .claude/projects/). User identity, preferences, and context come exclusively from `~/.luna-stack/config.yaml` and Notion. Project memory may contain outdated or irrelevant information from other sessions

### Layer 2: Sandbox + Permissions (.claude/settings.json)
- OS-level sandbox restricts filesystem and network access: only project files, `~/.luna-stack/` config, and `api.huntflow.ai`
- Explicit deny list for sensitive paths: `~/.ssh`, `~/.aws`, `~/Documents`, `~/Downloads`, shell configs
- `autoAllowBashIfSandboxed: true` — no permission popups when sandbox is active
- Explicit allow/deny lists for Notion MCP operations and Bash commands
- Deny list for destructive operations (database schema changes, delete, move, rm, force push)

### Layer 3: Notion Integration
- Notion access is via the built-in Claude Desktop Notion MCP connector (OAuth)
- Recruiters connect their Notion account during /onboarding (Settings → Connectors → Notion)
- Permissions are controlled by what pages are shared with the Notion connection
- Read + insert + update only, NO delete

## Config

`~/.luna-stack/config.yaml` — per-recruiter settings, created by /onboarding:

```yaml
name: "Имя Фамилия"
role: "Recruiter"
specialization: ["Tech", "FinTech"]
huntflow_access_token: "..."
huntflow_refresh_token: "..."
huntflow_user_id: "12345"
auto_upgrade: false
```