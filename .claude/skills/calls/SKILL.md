---
name: calls
description: |
  Access tldv call recordings — list past meetings, fetch transcripts and AI
  highlights, save transcripts to vacancy cards in Notion. Auto-detects which
  vacancy a call belongs to and offers to attach. Used both standalone and as
  a sub-step inside /briefing, /screening, /summary, /vacancy.
  Hard security invariant: only meetings where the recruiter's email is in
  the participants list are ever surfaced.
  Use when: "звонок", "созвон", "transcript", "транскрибт", "саммари звонка",
  "calls", "запись звонка", "tldv", "созвоны".
user-invocable: true
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /calls — Записи звонков из tldv

## Pre-check 0: Token + email migration (для текущих рекрутеров)

`/calls` — новая фича. Рекрутеры, которые уже прошли `/onboarding` ДО появления tldv-интеграции, не имеют в `~/.luna-stack/config.yaml` полей `tldv_api_token` и `email`. Скилл сам делает миграцию при первом запуске.

```bash
cat ~/.luna-stack/config.yaml
```

Проверь два поля: `tldv_api_token` и `email`.

### Если `tldv_api_token` отсутствует или пустой

Выведи как plain text (НЕ AskUserQuestion):

```
Один раз настрою доступ к tldv. Открой 1Password, найди запись "tldv Token", скопируй токен и вставь сюда.
```

Wait for user to paste the token. Это free-text input.

### Если `email` отсутствует или пустой

Email подставляется автоматически из Notion-базы «Команда» — там у каждого рекрутера есть поле `Email` (тип email).

1. Прочитай `notion_page_url` из config (это URL карточки рекрутера в Team-базе, сохранённый при `/onboarding`).
2. Загрузи страницу:

   ```
   mcp__claude_ai_Notion__notion-fetch
     id: "<notion_page_url из config>"
   ```

3. Из `properties.Email` возьми значение.

Если в Notion-Команда у рекрутера email пустой — выведи как plain text:

```
В твоей карточке в Notion-Команде не заполнено поле «Email». Добавь его (тот email, на который приходят инвайты в tldv-звонки) и снова запусти /calls. Без email я не смогу определить какие звонки твои.
```

Stop. Не предлагай альтернатив. Email должен быть в Notion как single source of truth (security инвариант).

### Сохрани оба значения в config

Используй `tee` (как в /onboarding) для перезаписи конфига:

```bash
tee ~/.luna-stack/config.yaml <<'EOF'
<existing keys preserved>
tldv_api_token: "<token from user>"
email: "<email from Notion>"
EOF
```

Сохрани все существующие ключи (имя, роль, Huntflow токены и т.д.). Просто добавь два новых.

После миграции — продолжай обычный flow без анонса. Sales rep не должен ждать «готово» — переходи сразу к Step 1.

## Pre-check: Quick verify

```bash
scripts/tldv.sh whoami
```

Должен вернуть email и обрезанный токен. Если падает — токен битый, попроси заново (вернись в Pre-check 0).

## Step 1: What action

AskUserQuestion:

- question: «Что делаешь?»
- header: «Звонок»
- options:
  - "Сохранить транскрибт в текущую вакансию (Рекомендуется)" — если есть session-binding, иначе пропусти эту опцию
  - "Саммари последнего звонка" — fast path для после-встречи рефлексии
  - "Список последних звонков" — выбор из меню
  - "Найти конкретный звонок" — поиск по названию

Если есть session-binding (в этой сессии активна вакансия), первая опция дефолтная и явно упоминает имя вакансии: «Сохранить транскрибт в [Client] — [Position]».

## Step 2: Get list

Используй ВСЕГДА `meeting-list-mine` (не raw `meeting-list`):

```bash
scripts/tldv.sh meeting-list-mine --limit 20
```

Это возвращает только встречи, где email рекрутера в `invitees` / `participants` / `attendees`. Фильтр зашит в обвязке — Claude его не обходит.

Если опция была «Найти конкретный звонок»:
```bash
scripts/tldv.sh meeting-list-mine --query "<keyword from user>"
```

Парсе ответ. Поля каждой встречи (могут отличаться в зависимости от tldv API):
- `id` — meeting ID
- `name` / `title` — название встречи
- `happenedAt` / `startedAt` / `created` — дата (ISO)
- `invitees[].email` — участники

## Step 3: Choose meeting

Покажи список через AskUserQuestion (топ-4):

- question: «Какой звонок?»
- header: «Звонок»
- options: формат `"[date DD.MM] · [meeting name] · [N участников]"`

Если встреч больше 4 — добавь пятой опцией «Других звонков нет в показанных» и при выборе — повтори с большим `--limit` или попроси уточнить query.

Если совсем 0 встреч — сообщи: «Не нашла звонков с твоим участием за последние [N]. Проверь, что email в `~/.luna-stack/config.yaml` совпадает с тем, на который ты получаешь tldv-инвайты.»

## Step 4: What to do with this call

AskUserQuestion:

- question: «Что с этим звонком?»
- header: «Действие»
- options:
  - "Сохранить в текущую вакансию (Рекомендуется)" — если session-binding активен
  - "Показать саммари" — highlights в чате
  - "Показать транскрибт целиком" — полный текст в чате (длинно, иногда лучше файл)
  - "Сохранить транскрибт в файл" — `~/.luna-stack/transcripts/<id>.txt` для копирования
  - "Привязать к другой вакансии" — выбор вакансии вручную

## Step 5: Execute

### 5a. Саммари

```bash
scripts/tldv.sh meeting-highlights <meeting_id>
```

Распарси ответ (highlights / summary / topics — смотри что вернул tldv) и покажи в чате как структурированный markdown. Группируй: ключевые темы, договорённости, действия.

Если tldv не вернул highlights (некоторые звонки могут быть без AI-саммари) — fallback: возьми транскрибт через `meeting-transcript`, и сгенерируй саммари сам по правилам:

- 2-4 предложения общего вектора
- bullets ключевых фактов (бюджет, имена, сроки, договорённости)
- секция follow-up

На русском, типография по preamble.

### 5b. Транскрибт целиком

```bash
scripts/tldv.sh meeting-transcript <meeting_id>
```

Покажи в чате. Если ответ длинный (>200 строк) — предложи альтернативу: «Транскрибт большой ([N] строк). Хочешь сохраню в файл?»

### 5c. Сохранить транскрибт в файл

```bash
mkdir -p ~/.luna-stack/transcripts
scripts/tldv.sh meeting-transcript <meeting_id> > ~/.luna-stack/transcripts/<meeting_id>.txt
```

Покажи путь и количество строк.

### 5d. Сохранить в текущую вакансию (главный сценарий)

Это сложный сценарий — см. Step 6.

## Step 6: Save transcript to vacancy in Notion

### 6a. Auto-link с вакансией

Если session-binding активен — используй текущую вакансию.

Если session-binding отсутствует — попробуй определить вакансию автоматически:

1. **Из названия встречи** — есть ли в `name` имя клиента (можно проверить через Notion-Клиенты) или название позиции?
2. **Из participants** — email участников: совпадает ли домен с активным клиентом?
3. **Из даты** — встреча в окне ±7 дней от open vacancy этого рекрутера?

Если ≥2 сигнала — предложи через AskUserQuestion:

- question: «Похоже, это встреча по [Client] — [Position]. Привязать?»
- header: «Привязка»
- options:
  - "Да, привязать (Рекомендуется)"
  - "Нет, выбрать другую"

Если «Нет» или авто не сработало — покажи список активных вакансий рекрутера (запрос через `notion-query-database-view` на vacancy view, фильтр по recruiter из config) и AskUserQuestion с топ-4.

### 6b. Тип транскрибта (брифинг или другое касание)

AskUserQuestion:

- question: «Это транскрибт брифинга с клиентом?»
- header: «Тип»
- options:
  - "Да, брифинг (Рекомендуется)" — сохранить в существующую sub-page «Транскрибт брифинга» внутри вакансии
  - "Нет, другое касание" — создать новую sub-page внутри вакансии с названием `Транскрибт · DD.MM.YYYY · [meeting name]`

### 6c. Получи транскрибт и highlights

```bash
scripts/tldv.sh meeting-transcript <meeting_id>
scripts/tldv.sh meeting-highlights <meeting_id>
```

### 6d. Запиши в Notion

**Вариант 1 — в «Транскрибт брифинга»:**

1. Найди sub-page «Транскрибт брифинга» внутри вакансии (через `notion-fetch` главной страницы, ищи child page с этим title).
2. Запиши через `notion-update-page` с `command: replace_content`:

   ```
   page_id: "<sub-page id>"
   new_str: |
     **Звонок DD.MM.YYYY · [meeting name]**

     **Саммари:**
     [highlights output, рендеренный markdown]

     **Транскрибт:**
     [full transcript]

     ---
     *Источник: tldv (meeting ID: [id])*
   ```

**Вариант 2 — новая sub-page:**

```
mcp__claude_ai_Notion__notion-create-pages
  parent: { type: "page_id", page_id: "<vacancy page id>" }
  pages: [{
    properties: { title: "Транскрибт · DD.MM.YYYY · <meeting name>" },
    icon: "📞",
    content: <тот же markdown что в варианте 1>
  }]
```

### 6e. Подтверди в чате

«Готово. Транскрибт сохранён в [Client] — [Position] → [Транскрибт брифинга / новая страница]. Ссылка: <Notion URL>.»

## Step 7: Next

AskUserQuestion:

- question: «Что дальше?»
- header: «Дальше»
- options:
  - "Закончить" — выход
  - "Ещё один звонок" — вернись в Step 1
  - "Сделать саммари кандидата на основе этого звонка" — предложи запустить `/summary` (только если транскрибт скрининг-звонка)

## Notes

- **Hard invariant**: всегда `meeting-list-mine`, никогда `meeting-list`. Если ты пишешь команду без `-mine` — это баг.
- **Email source of truth**: Notion-Команда. Если рекрутер хочет сменить email для tldv — менять в Notion, потом удалить `email:` из `~/.luna-stack/config.yaml` и запустить `/calls` — миграция подхватит новое значение из Notion.
- **Token rotation**: если токен в 1Password обновили — рекрутеру надо удалить `tldv_api_token:` из config (или попросить администратора Luna Stack обновить), и при следующем `/calls` вставить новый.
- **Cache**: транскрибты не кешируются скиллом локально, кроме случая «сохранить в файл» (Step 5c). Каждый запрос — свежий вызов tldv API. Это нормально, объёмы небольшие.
- **API shape variations**: `tldv.sh meeting-list-mine` использует **схемо-независимый substring-фильтр** — ищет email рекрутера в JSON-представлении каждой встречи, независимо от того в каком поле tldv его хранит (`invitees[].email` / `participants[].address` / `attendees[].user.email` / etc.). Если в сводке `/meetings` участников нет (только metadata), скрипт автоматически делает enrichment-fallback: refetch каждой встречи через `/meetings/{id}` и применяет тот же фильтр к детальному ответу. На 50 встречах enrichment добавляет ~5-10 секунд, но только если pass-1 на summary не нашёл совпадений.

- **Hard scoping note**: общий tldv-токен (`ba@lunapastel.io` в нашем случае) видит ВСЕ командные звонки — потому что `ba@` добавлен в каждый. Поэтому мы не полагаемся на token-owner-based scoping (это было бы лазейкой), а явно фильтруем по email рекрутера в данных встречи. Если рекрутера в участниках нет — встреча не показывается.

- **Diagnostics**: если `meeting-list-mine` возвращает странные результаты (например, чужие звонки или, наоборот, не показывает ваши), используй `scripts/tldv.sh meeting-list-raw --limit 5` чтобы посмотреть сырой ответ tldv API и понять структуру. Эта команда не фильтрует — только для дебага.
