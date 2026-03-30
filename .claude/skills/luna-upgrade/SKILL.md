---
name: luna-upgrade
description: |
  Update Luna Stack skills via git pull. Shows what changed.
  Supports auto-upgrade via config flag.
  Use when: "обновить", "upgrade", "обновление", "luna-upgrade".
---

Read the file `lib/preamble.md` and follow all rules defined there.

# /luna-upgrade — Обновление Luna Stack

## Step 1: Check Config

```bash
cat ~/.luna-stack/config.yaml
```

Check if `auto_upgrade: true` is set.

## Step 2: Check Current State

```bash
git status
git log --oneline -1
```

Show current version (latest commit) to the recruiter.

## Step 3: Pull Updates

If `auto_upgrade: true`, proceed without asking. Otherwise:

Use AskUserQuestion:
- question: «Проверить и установить обновления Luna Stack?»
- options:
  - "Обновить (Рекомендуется)"
  - "Не сейчас"

If approved:

```bash
git pull
```

## Step 4: Show Changes

```bash
git log --oneline -10
```

Parse the output and summarize in Russian what changed. Focus on user-visible changes:
- New skills
- Changed skill behavior
- Bug fixes

Example:
«**Обновления установлены:**
• Добавлен новый skill /screening
• Улучшена подготовка к брифингу — больше вопросов по компенсации
• Исправлена ошибка в /vacancy при создании новой карточки»

If nothing changed:
«Luna Stack уже обновлён до последней версии.»

## Auto-upgrade at Session Start

This skill can be invoked silently at session start when `auto_upgrade: true` in config.
In that case, only show output if there were actual changes. If already up to date, say nothing.
