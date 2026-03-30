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

### Step 2: Identify the recruiter

Use AskUserQuestion to ask their name:
- question: «Как тебя зовут? (Имя и фамилия, как в Notion)»
- options: No predefined options — use a free-text question with header "Имя"

After getting the name, search the Team database:
```
mcp__claude_ai_Notion__notion-search
  query: "<recruiter name>"
  data_source_url: "collection://32ef9167-2e00-8158-ba59-000b70b0a852"
```

If found, fetch the full record and confirm:
- Show: name, role, specialization, email
- Ask: «Это ты? (Да/Нет)»

If NOT found, ask the recruiter to check the spelling or contact their team lead.

### Step 3: Notion token

Explain where to get the token:
«Теперь нужен Notion-токен. Найди его в 1Password: ищи "Luna — [Твоё Имя]", скопируй Internal Integration Token (начинается с ntn_).»

Use AskUserQuestion with free-text input for the token.

Validate: token should start with `ntn_` or `secret_`. If not, ask again.

### Step 4: Huntflow tokens

«Теперь токены Хантфлоу. Найди их в 1Password: ищи "Huntflow API".»

Ask for **access token** first:
«Скопируй Access Token (он же Bearer-токен для запросов).»
Use AskUserQuestion with free-text input.

Then ask for **refresh token**:
«Теперь скопируй Refresh Token (он нужен для автоматического обновления доступа).»
Use AskUserQuestion with free-text input.

Then ask for `huntflow_account_id`:
«И последнее — Account ID (числовой идентификатор аккаунта агентства).»
Use AskUserQuestion with free-text input.

### Step 5: Save config

Create the config directory and write the config file:

```bash
mkdir -p ~/.luna-stack
```

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
name: "<name from Team DB>"
role: "<role from Team DB>"
specialization: [<list from Team DB>]
notion_token: "<token>"
huntflow_access_token: "<access_token>"
huntflow_refresh_token: "<refresh_token>"
huntflow_account_id: "<account_id>"
auto_upgrade: false
EOF
```

This uses `tee` which is allowed by the permissions config. Do NOT use the Write tool or `cat >` redirection — they are not in the allow list.

### Step 6: Model setup

Explain in Russian with clear step-by-step:

«Важно: переключи модель на Claude Opus 4.6 для лучшего качества работы.

1. В левом нижнем углу Claude Desktop нажми на название текущей модели
2. Выбери "Claude Opus 4.6"

Это нужно сделать один раз — модель сохранится для всех будущих сессий.»

### Step 7: Bypass permissions

«Ещё одна настройка — разреши мне работать без постоянных запросов на подтверждение.

1. Открой настройки Claude Desktop (⌘ + ,)
2. Перейди в раздел "Code"
3. Включи "Allow bypass permissions mode"

Не переживай — я физически не могу ничего удалить: это заблокировано на уровне разрешений и Notion API. Эта настройка просто убирает лишние подтверждения при каждом действии.»

### Step 8: Introduce commands

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

### Step 9: Session naming

«После запуска /vacancy я попрошу тебя переименовать сессию в формате:

**[Клиент] — [Позиция] (месяц год)**

Например: TechCorp — Frontend Dev (март 2026)

Это помогает быстро находить нужную вакансию в списке сессий.

Чтобы вернуться к вакансии — найди её по имени сессии в левой панели.»

### Step 10: Finish

«Настройка завершена! Набери /vacancy, чтобы начать работу с первой вакансией.»
