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

Используй ВСЕГДА `meeting-list-mine` (не `meeting-list-raw` — последняя только для дебага и не фильтрует):

```bash
scripts/tldv.sh meeting-list-mine --limit 20
```

Это возвращает массив встреч, отфильтрованных так, что `.organizer.email == config.email` ИЛИ `.invitees[].email == config.email`. Фильтр зашит в shell-обвязке точечным jq-путём — Claude его не обходит.

Если опция была «Найти конкретный звонок»:
```bash
scripts/tldv.sh meeting-list-mine --query "<keyword from user>"
```

Параметр `--query` уходит на сторону tldv как server-side substring-фильтр по названию встречи.

**Точная структура каждого элемента ответа** (verified against live tldv API):

```json
{
  "id": "69eb857634346b00137b0b0e",
  "name": "Andrew Romanyuk | Head of Online Sales at Neginski",
  "happenedAt": "Tue Apr 28 2026 16:22:49 GMT+0000 (Coordinated Universal Time)",
  "duration": 1053.146,
  "invitees": [
    {"name": "Alex Rocket", "email": "alexrocket@lunapastel.io"},
    {"name": "Andrew Romanyuk", "email": "eandreyr@gmail.com"}
  ],
  "organizer": {"name": "Alex Rocket", "email": "alexrocket@lunapastel.io"},
  "url": "https://tldv.io/app/meetings/69eb857634346b00137b0b0e",
  "extraProperties": {"conferenceId": "..."}
}
```

Заметки про поля:
- `happenedAt` в list-эндпоинте — JS Date string, не ISO 8601. Для отображения возьми первые 16 символов (`Tue Apr 28 16:22`) или используй `url` чтобы открыть встречу в tldv UI с нормальным интерфейсом.
- `duration` в секундах (float). При отображении конвертируй в минуты: `(duration / 60 | floor)` мин.
- `organizer` — всегда object (проверено на 228 встречах в боевой базе).
- `invitees` — всегда array, может быть пустым.

## Step 3: Choose meeting

Покажи список через AskUserQuestion (топ-4):

- question: «Какой звонок?»
- header: «Звонок»
- options: формат `"[DD.MM HH:MM] · [meeting name] · [N мин]"` где время — substring из `happenedAt`, минуты — `duration / 60`

Если встреч больше 4 — добавь пятой опцией «Других звонков нет в показанных» и при выборе — повтори с большим `--limit` или попроси уточнить query.

Если совсем 0 встреч — сообщи: «Не нашла звонков с твоим участием за последние ~300 встреч в tldv. Проверь, что email в `~/.luna-stack/config.yaml` совпадает с тем, на который ты получаешь tldv-инвайты (поле `email`). Текущий: запусти `scripts/tldv.sh whoami` чтобы посмотреть.»

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

### Сначала: проверь 403 (free-plan organizer)

Эндпоинты `meeting-transcript` и `meeting-highlights` возвращают HTTP 403 с body вида `{"name":"ForbiddenError","message":"This meeting was organized by a Free user and cannot be accessed via API."}`, если organizer встречи на бесплатном плане tldv. Скилл должен проверить это **первым** перед парсингом:

```bash
result=$(scripts/tldv.sh meeting-highlights <id>)
if echo "$result" | jq -e '.name == "ForbiddenError"' >/dev/null 2>&1; then
  # Cообщи пользователю и предложи альтернативу
fi
```

При 403 сообщи в чате:

«Встреча "[name]" была организована аккаунтом на бесплатном плане tldv ([organizer.email]) — API не отдаёт по ней транскрипт и саммари. Можно открыть встречу в браузере: [url] — там запись и AI-саммари доступны через UI.»

И предложи через AskUserQuestion: «Что дальше?» с опциями «Открыть в tldv UI» (просто покажи URL), «Выбрать другую встречу» (вернись в Step 3), «Ввести саммари вручную» (запроси текст у рекрутера).

### 5a. Саммари

```bash
scripts/tldv.sh meeting-highlights <meeting_id>
```

**Точная структура ответа:**

```json
{
  "meetingId": "69eb857634346b00137b0b0e",
  "data": [
    {
      "text": "Компания Нигинский работает 6 лет с офисами в Москве и Дубае...",
      "startTime": 0,
      "source": "auto",
      "topic": {
        "title": "Описание позиции и компании",
        "summary": "No Summary"
      }
    },
    ...
  ]
}
```

Группируй `.data[]` по `.topic.title` и собери в markdown:

```
**Саммари звонка [meeting name] · [DD.MM HH:MM]**

### [topic.title 1]
- [data[].text если topic совпадает]
- [data[].text]

### [topic.title 2]
- [data[].text]
- ...
```

Если у `.topic.summary` есть содержательный текст (не "No Summary") — используй его как заголовок секции вместо `topic.title`.

Если `.data` пустой массив — звонок не получил AI highlights (бывает у коротких или без речи). Fallback: возьми транскрипт через `meeting-transcript` и сгенерируй саммари сам:
- 2-4 предложения общего вектора
- bullets ключевых фактов (бюджет, имена, сроки, договорённости)
- секция follow-up

На русском, типография по preamble.

### 5b. Транскрибт целиком

```bash
scripts/tldv.sh meeting-transcript <meeting_id>
```

**Точная структура ответа:**

```json
{
  "id": "transcript-id",
  "meetingId": "meeting-id",
  "data": [
    {
      "startTime": 0,
      "endTime": 147,
      "speaker": "Alexander Brezgin",
      "text": "Есть компания Нигинский, 6 лет..."
    },
    ...
  ]
}
```

Каждый элемент `.data[]` — реплика с `speaker`, `text`, и таймингом в секундах. На реальных встречах бывает ~100-200 сегментов.

Формат для показа в чате:

```
**Транскрибт [meeting name] · [DD.MM HH:MM]**

**[Speaker A]** ([0:00]):
[text]

**[Speaker B]** ([2:27]):
[text]
...
```

Где время в скобках — `startTime` секунд → `MM:SS` (или `HH:MM:SS` для длинных).

Если segments_count > 50 (длинный звонок) — предложи: «Транскрибт большой ([N] реплик, ~[M] минут). Хочешь покажу в чате целиком или сохраню в файл `~/.luna-stack/transcripts/[id].txt`?»

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
- **Filter implementation**: `tldv.sh meeting-list-mine` использует точечный jq-фильтр по двум конкретным путям:
  ```jq
  (.organizer.email == $email) or
  ((.invitees // []) | map(.email) | any(. == $email))
  ```
  Схема API verified против боевого endpoint (228 встреч, organizer всегда object, invitees всегда array). Никаких substring-эвристик — только exact match. False-positive невозможен.

- **Hard scoping note**: общий tldv-токен (`ba@lunapastel.io` в нашем случае) видит ВСЕ командные звонки — потому что `ba@` добавлен в каждый звонок. Поэтому мы не полагаемся на token-owner-based scoping (это было бы лазейкой), а явно фильтруем по email рекрутера в `.organizer.email` или `.invitees[].email`. Если рекрутера в одном из этих двух мест нет — встреча не показывается.

- **Pagination**: tldv API лимитирует `?limit=` максимум 100. Скрипт пагинирует до `--max-pages` (default 3) страниц по 100, набирая `--limit` (default 20) релевантных встреч. Этого хватает чтобы найти все недавние свои встречи в воркспейсах с ~300 встреч/неделю.

- **HTTP 403 на transcript/highlights**: tldv не отдаёт через API контент встреч, организованных пользователями на бесплатном плане. Тело: `{"name":"ForbiddenError","message":"This meeting was organized by a Free user and cannot be accessed via API."}`. Скилл проверяет это первым (см. Step 5) и направляет рекрутера в tldv UI по `.url`.

- **Diagnostics**: если `meeting-list-mine` возвращает странные результаты, используй `scripts/tldv.sh meeting-list-raw --limit 5` чтобы посмотреть сырой ответ tldv API без фильтра. Эта команда служебная — в скилле не использовать.
