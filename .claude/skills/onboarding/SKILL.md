---
name: onboarding
description: |
  One-time setup for a new Luna Pastel team member. Identifies the recruiter
  in the Team database, saves Notion and Huntflow tokens to local config,
  explains model/permission setup, and introduces available commands.
  Use when: first time setup, "настройка", "онбординг".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /onboarding — Первоначальная настройка

This skill runs ONCE per recruiter to set up their Luna Stack environment.

## Flow

### Step 1: Greeting

Greet the recruiter in Russian. Briefly explain what Luna Stack is:

«Привет! Я — твой рекрутинговый ассистент Luna Stack. Помогаю с вакансиями, подготовкой к брифингам, ресёрчем, аутричем и скринингом кандидатов. Давай настроим всё за пару минут.»

### Step 2: Switch to Opus

Display as plain text (NOT AskUserQuestion):

«Переключи модель на Claude Opus 4.6:
→ В правом нижнем углу нажми на название текущей модели и выбери "Claude Opus 4.6"

Когда сделаешь — напиши "Готово" в поле "Type something else".»

Use AskUserQuestion:
- question: «Переключил модель?»
- header: "Модель"
- options:
  - "Готово" — placeholder; the recruiter confirms in "Type something else"

### Step 3: Enable sandbox

Display as plain text (NOT AskUserQuestion):

«Теперь настроим безопасную среду. Набери в чате (не в "Type something else", а прямо в поле ввода сообщения):

/sandbox

В появившемся меню выбери "Auto-allow" — это позволит мне работать без постоянных подтверждений, но только внутри безопасной песочницы. Я не смогу читать твои личные файлы, пароли или документы — только файлы проекта Luna Stack.

Когда сделаешь — напиши "Готово" в поле "Type something else".»

Use AskUserQuestion:
- question: «Включил sandbox?»
- header: "Песочница"
- options:
  - "Готово" — placeholder; the recruiter confirms in "Type something else"

### Step 4: Ask name

Use AskUserQuestion:
- question: «Как тебя зовут? Напиши имя и фамилию в поле "Type something else".»
- header: "Имя"
- options:
  - "Напишу имя" — placeholder; the recruiter will type their actual name in "Type something else"

Save the name for later. Do NOT search Notion yet — we need the Notion token first.

### Step 5: Notion token

Use AskUserQuestion:
- question: «Найди в 1Password запись "Notion Token" (или "Luna — [Твоё Имя]"), скопируй токен (начинается с ntn_) и вставь его в поле "Type something else".»
- header: "Notion"
- options:
  - "Вставлю токен" — placeholder; the recruiter will paste the token in "Type something else"

Validate: token should start with `ntn_` or `secret_`. If not, explain:
«Токен должен начинаться с ntn_ или secret_. Проверь, что скопировал правильное значение из 1Password.»

### Step 6: Save initial config

Create the config directory and write the config file with what we have so far:

```bash
mkdir -p ~/.luna-stack
```

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<name from Step 4>"
role: ""
specialization: []
notion_token: "<notion token from Step 5>"
huntflow_access_token: ""
huntflow_refresh_token: ""
auto_upgrade: false
EOF
```

This uses `tee` which is allowed by the permissions config. Do NOT use the Write tool or `cat >` redirection — they are not in the allow list.

### Step 7: Identify recruiter in Team database

Now that we have the Notion token saved, search the Team database.

**Important**: Use the recruiter's personal Notion token from config, NOT the built-in Claude Desktop Notion integration.

Try searching with the name from Step 4:
```
mcp__claude_ai_Notion__notion-search
  query: "<recruiter name>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

**If the name was in Cyrillic** — also try Latin transliteration:
- «Никита Шестаков» → try "Nikita Shestakov"
- «Анастасия» → try "Anastasia"
Tolerate 1-2 character differences (e.g., "Shestakov" vs "Shestacov").

**If found** — fetch the full record, confirm with the recruiter:
- Show: name, role, specialization, email
- Use AskUserQuestion:
  - question: «Нашла тебя в базе: [Name], [Role], [Specialization]. Это ты?»
  - header: "Подтверждение"
  - options:
    - "Да, это я"
    - "Нет, это не я"

Note: do NOT add "(Рекомендуется)" — this is a factual confirmation, not a recommendation.

**If NOT found after transliteration** — fetch ALL active team members from the Team database and show as options:
```
mcp__claude_ai_Notion__notion-search
  query: "Active"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

Use AskUserQuestion:
- question: «Не нашла тебя по имени. Выбери себя из списка:»
- options: list each active team member as an option (up to 4) — the recruiter picks themselves from the list

Do NOT search outside the Team database. Do NOT fall back to workspace-wide search.

### Step 8: Huntflow tokens

Ask for **access token**:

Use AskUserQuestion:
- question: «Найди в 1Password запись "Huntflow Access Token", скопируй токен и вставь в поле "Type something else".»
- header: "Huntflow"
- options:
  - "Вставлю токен" — placeholder; the recruiter will paste the token in "Type something else"

Then ask for **refresh token**:

Use AskUserQuestion:
- question: «Теперь найди в 1Password запись "Huntflow Refresh Token", скопируй и вставь в поле "Type something else".»
- header: "Refresh"
- options:
  - "Вставлю токен" — placeholder; the recruiter will paste the token in "Type something else"

### Step 9: Detect Huntflow user ID

Automatically detect the recruiter's Huntflow user ID using the tokens just collected.

First, save a temporary config so huntflow.sh can authenticate:
```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<confirmed name from Team DB>"
role: "<role from Team DB>"
specialization: [<list from Team DB>]
notion_token: "<notion token>"
huntflow_access_token: "<access token from Step 8>"
huntflow_refresh_token: "<refresh token from Step 8>"
huntflow_user_id: ""
auto_upgrade: false
EOF
```

Then call:
```bash
scripts/huntflow.sh me
```

Extract the `id` field from the response — this is the recruiter's Huntflow user ID. Save it to config:
```bash
# Update huntflow_user_id in config with the detected value
```

If the call fails, ask the recruiter to provide their Huntflow user ID manually.

### Step 10: Save final config

Write the complete config file with all collected data including `huntflow_user_id`:

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<confirmed name from Team DB>"
role: "<role from Team DB>"
specialization: [<list from Team DB>]
notion_token: "<notion token>"
huntflow_access_token: "<access token from Step 8>"
huntflow_refresh_token: "<refresh token from Step 8>"
huntflow_user_id: "<user ID from Step 9>"
auto_upgrade: false
EOF
```

Note: `huntflow_account_id` is not stored in config — it is hardcoded in `scripts/huntflow.sh` and `CLAUDE.md`.

### Step 11: Introduce commands

Show available skills:

«Готово! Вот твои команды:

• `/vacancy` — начать работу с вакансией (главная команда)
• `/briefing` — подготовка к брифингу с клиентом
• `/vacancy-card` — оформить описание вакансии для кандидатов и внутренний профиль позиции
• `/research` — глубокий ресёрч по компании, рынку, зарплатам
• `/outreach` — составить сообщение кандидату
• `/screening` — оценить кандидата по критериям вакансии
• `/summary` — оформить саммари кандидата после скрининга
• `/client-update` — сгенерировать апдейт клиенту по прогрессу
• `/funnel-review` — анализ воронки: конверсии, узкие места, рекомендации
• `/handoff` — передать вакансию другому рекрутеру
• `/luna-upgrade` — обновить Luna Stack

**Главное правило:** одна сессия = одна вакансия. Для каждой вакансии создавай новую сессию (нажми + в левом верхнем углу).»

### Step 12: Finish

«Настройка завершена! Для начала работы с первой вакансией нажми "New session" в верхнем левом углу и набери /vacancy.»
