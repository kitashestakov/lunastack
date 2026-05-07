---
name: onboarding
description: |
  One-time setup for a new Luna Pastel team member. Identifies the recruiter
  in the Team database, saves Huntflow tokens to local config, explains
  model setup, and introduces available commands.
  Use when: first time setup, "настройка", "онбординг".
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /onboarding — Первоначальная настройка

This skill runs ONCE per recruiter to set up their Luna Stack environment.

**IMPORTANT: Do NOT use AskUserQuestion for steps that require free text input or external actions.** Only use AskUserQuestion for predefined-option choices (like «Это ты?» confirmation). For everything else — output plain text and wait for the user to type their response directly in the chat.

## Flow

### Step 1: Greeting

Greet the recruiter in Russian. Briefly explain what Luna Stack is and note that the security environment is pre-configured:

«Привет! Я — твой рекрутинговый ассистент Luna Stack. Помогаю с вакансиями, подготовкой к брифингам, ресерчем, аутричем и скринингом кандидатов.

Твоя рабочая среда уже настроена в безопасном режиме — я могу работать только с файлами проекта Luna Stack и не имею доступа к твоим личным файлам, паролям или документам.

Давай настроим всё за пару минут.»

### Step 2: Switch to Opus

Output as plain text, then STOP and wait for the user to reply:

«Переключи модель на Claude Opus 4.6:
→ В правом нижнем углу нажми на название текущей модели и выбери "Claude Opus 4.6"

Когда сделаешь — напиши «Готово».»

Wait for the user to type «Готово» (or any confirmation) in the chat input. Do NOT use AskUserQuestion.

### Step 3: Connect Notion

Output as plain text, then STOP and wait:

«Подключи Notion к Claude Desktop:
→ Открой настройки Claude Desktop (⌘ + ,)
→ Перейди в раздел "Connectors"
→ Найди Notion и нажми "Connect"
→ Выбери workspace Luna Pastel и подтверди доступ

Когда подключишь — напиши «Готово».»

Wait for confirmation. Do NOT use AskUserQuestion.

Note: Notion access uses the built-in Claude Desktop MCP connector (OAuth). No personal token needed — the connector handles auth.

### Step 3.5: Connect Google Calendar

Output as plain text, then STOP and wait:

«Подключи Google Calendar — нужно для скилла /meet (назначение звонков с автоматическим Meet и инвайтами):
→ Settings → Connectors → Google Calendar → Connect
→ Выбери свой рабочий аккаунт Luna Pastel
→ Подтверди разрешения (создание событий + чтение для проверки занятости)

Когда подключишь — напиши «Готово».»

Wait for the user to type «Готово». Do NOT use AskUserQuestion.

Note: Google Calendar access uses the built-in Claude Desktop MCP connector (OAuth). No personal token needed. Если у рекрутера нет рабочего Google аккаунта — пропускаем шаг, но `/meet` работать не будет до подключения.

### Step 4: Ask name

Output as plain text, then STOP and wait:

«Как тебя зовут? Напиши имя и фамилию.»

Wait for the user to type their name in the chat. Do NOT use AskUserQuestion. Save the name for the next step.

### Step 5: Identify recruiter in Team database

Search the Team database using Notion MCP tools:

```
mcp__claude_ai_Notion__notion-search
  query: "<recruiter name>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

**If the name was in Cyrillic** — also try Latin transliteration:
- «Никита Шестаков» → try "Nikita Shestakov"
- «Анастасия» → try "Anastasia"
Tolerate 1-2 character differences (e.g., "Shestakov" vs "Shestacov").

**If found** — fetch the full record, confirm with the recruiter. Use AskUserQuestion HERE (predefined options):
- question: «Нашла тебя в базе: [Name], [Role], [Specialization]. Это ты?»
- header: "Подтверждение"
- options:
  - "Да, это я"
  - "Нет, это не я"

Note: do NOT add «(Рекомендуется)» — this is a factual confirmation.

**If NOT found after transliteration** — fetch ALL active team members and show as options. Use AskUserQuestion HERE (predefined list):
- question: «Не нашла тебя по имени. Выбери себя из списка:»
- options: list each active team member as an option (up to 4)

Do NOT search outside the Team database. Do NOT fall back to workspace-wide search.

### Step 6: Huntflow tokens

Output as plain text, then STOP and wait for each token:

«Теперь подключим Хантфлоу. Найди в 1Password запись "Huntflow Access Token", скопируй токен и вставь его сюда.»

Wait for the user to paste the access token in the chat. Do NOT use AskUserQuestion.

Then:

«Теперь найди в 1Password запись "Huntflow Refresh Token", скопируй и вставь сюда.»

Wait for the user to paste the refresh token. Do NOT use AskUserQuestion.

### Step 6.5: tldv token + email

tldv — это сервис записи звонков. У нас один общий токен, токен живёт в 1Password. Email рекрутера нужен, чтобы скилл `/calls` показывал ему только те звонки, где он был участником (security-инвариант: общий токен в теории даёт доступ ко всем встречам, но Luna Stack никогда не показывает чужие).

Output as plain text, then STOP and wait:

«Теперь подключим tldv (записи звонков). Найди в 1Password запись "tldv Token", скопируй и вставь сюда.»

Wait for user to paste the tldv token.

**Email подставляется автоматически из карточки в Team-базе.** Из Step 5 у нас уже есть полная Team-DB запись рекрутера — оттуда поле `Email` (тип email) и идёт. Не спрашивай у рекрутера повторно.

Если в Team-карточке email пустой — выведи как plain text:

«У тебя в Notion-Команде не заполнено поле Email. Это нужно для `/calls` (фильтр звонков по участникам). Зайди в свою карточку, добавь email (тот, на который приходят инвайты в tldv), потом снова запусти /onboarding. Без этого `/calls` работать не будет.»

И прерви onboarding на этом шаге. Не двигайся дальше — это исправляется один раз и быстро.

### Step 7: Detect Huntflow user ID

Save a temporary config so huntflow.sh can authenticate:

```bash
mkdir -p ~/.luna-stack
```

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<confirmed name from Team DB>"
role: "<role from Team DB>"
specialization: [<list from Team DB>]
notion_page_url: "<recruiter's Team DB page URL, e.g. https://www.notion.so/32ef91672e0080339149caaf8c965932>"
email: "<email from Team DB Email property>"
huntflow_access_token: "<access token from Step 6>"
huntflow_refresh_token: "<refresh token from Step 6>"
huntflow_user_id: ""
tldv_api_token: "<tldv token from Step 6.5>"
auto_upgrade: false
EOF
```

The `notion_page_url` is the recruiter's page URL from the Team database — used by /vacancy to filter vacancies by recruiter. The `email` field is the source-of-truth for tldv participant filtering — see /calls.

This uses `tee` which is allowed by the permissions config. Do NOT use the Write tool or `cat >` redirection.

Then auto-detect the recruiter's Huntflow user ID using their English name from the Team DB:

```bash
scripts/huntflow.sh member-find "<English name from Team DB>"
```

This searches the Huntflow organization members by name and returns the user ID.

If found — save to config silently (no questions to the recruiter).
If not found — warn: «Не удалось найти тебя в списке пользователей Хантфлоу. Обратись к администратору Luna Stack.» Continue without huntflow_user_id — it can be added later.

### Step 8: Save final config

Write the complete config file with all collected data:

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<confirmed name from Team DB>"
role: "<role from Team DB>"
specialization: [<list from Team DB>]
notion_page_url: "<recruiter's Team DB page URL>"
email: "<email from Team DB>"
huntflow_access_token: "<access token from Step 6>"
huntflow_refresh_token: "<refresh token from Step 6>"
huntflow_user_id: "<user ID from Step 7>"
tldv_api_token: "<tldv token from Step 6.5>"
auto_upgrade: false
EOF
```

### Step 9: Introduce commands

Show available skills:

«Готово! Вот твои команды:

• `/vacancy` — начать работу с вакансией (главная команда)
• `/briefing` — подготовка к брифингу с клиентом
• `/vacancy-card` — оформить описание вакансии для кандидатов и внутренний профиль позиции
• `/research` — глубокий ресерч по компании, рынку, зарплатам
• `/outreach` — составить сообщение кандидату
• `/screening` — оценить кандидата по критериям вакансии
• `/summary` — оформить саммари кандидата после скрининга
• `/client-update` — сгенерировать апдейт клиенту по прогрессу
• `/calls` — записи звонков из tldv: транскрибты, саммари, сохранение в карточку вакансии
• `/meet` — назначить звонок: создаёт ивент в Google Calendar с инвайтом, Meet ссылкой, ноутейкером (название выбрано так, потому что `/schedule` зарезервирован встроенным скиллом Claude Code)
• `/funnel-review` — анализ воронки: конверсии, узкие места, рекомендации
• `/handoff` — передать вакансию другому рекрутеру
• `/luna-upgrade` — обновить Luna Stack
• `/weekly-sync` — создать записи для еженедельного синка по всем активным вакансиям

**Главное правило:** одна сессия = одна вакансия. Для каждой вакансии создавай новую сессию (нажми + в левом верхнем углу).»

### Step 10: Finish

«Настройка завершена! Для начала работы с первой вакансией нажми "New session" в верхнем левом углу и набери /vacancy.»
