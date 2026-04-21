---
name: horeca-crm-plan
description: |
  Plan next actions for all leads in the HoReCa CRM.
  Writes ONLY to two Claude-scoped columns: "🔸 Claude: Action" and "🔸 Claude: Message".
  Never touches other columns — Настя controls Stage / Next Action / Next Action Date / Notes herself.
  Generates ready-to-send messages in the client's language and Nastya's voice.
  Use when: "horeca crm plan", "запланируй crm", "что делать по лидам", "horeca-crm-plan".
user-invocable: true
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /horeca-crm-plan — Подсказки действий по CRM

## Purpose

Настя сама управляет своей воронкой: колонки `Next Action`, `Next Action Date`, `Stage`, `Notes` — ее территория и отражают ее решения. Скилл работает в **параллельных** Claude-колонках:

- `🔸 Claude: Action` — что бы Claude предложил делать дальше
- `🔸 Claude: Message` — готовое сообщение клиенту

Настя сравнивает свою версию с Claude-подсказкой и копирует в свои поля то, с чем согласна. Это second opinion, не замена ее решений.

Скилл проходит по ВСЕЙ таблице и для каждого лида заполняет/перезаписывает две Claude-колонки на основе полного контекста (Stage, Notes, комментарии, скриншоты, web-research).

## Product Context (ЧИТАТЬ ПЕРВЫМ)

### Что мы продаем HoReCa-клиентам

**Core offer:** AI-augmented full-service recruitment на **подписке**.
- **€5,000/month flat**, unlimited hires
- Все роли HoReCa: executive chef, sous, line cooks, FOH lead, servers, ops director, concierge, front desk, housekeeping supervisor, revenue manager, F&B director
- Dedicated recruiter, embedded в бренд клиента
- Pre-opening capability (первый shortlist в течение недели)
- Replacement guarantee: если человек ушел — заменяем без extra invoice
- Commit: один opening cycle (4-8 недель), дальше month-to-month

**Real-world proof:** Fresora (Vita Core SL, Barcelona) — 17 hires за 4 недели, два ресторана открыты одновременно. Это наш главный кейс, можно ссылаться.

### Позиционирование относительно основного Luna Pastel

- Luna Pastel — 10-летнее рекрутинговое агентство, **основной продукт — IT-рекрутинг** (Web3, Web/Mobile, Fintech, AI, Affiliate Marketing, C-Level Headhunting).
- **HoReCa — newest vertical, не основной бизнес.** Same proven system, applied to a new industry.
- В сообщениях HoReCa-клиентам IT-линию **НЕ упоминаем**. Это отдельный продукт с отдельной командой и подходом.
- Правильно: «Luna Pastel помогает отелям и ресторанам Испании с наймом». НЕ надо: «Luna Pastel — агентство для HoReCa» (ложь) или «у нас также есть IT-рекрутинг» (не релевантно клиенту).

### УТП (чем отличаемся от обычных HR-агентств в HoReCa)

1. **Subscription, не per-placement.** Обычный HR в HoReCa берет €3-8K за найм. Три найма = €24K+. У нас €5K/мес с unlimited hires.
2. **Aligned incentives.** Мы теряем деньги на bad hires (бесплатная замена), поэтому структурно заинтересованы в retention. У per-placement агентств incentive противоположный — текучка им выгодна.
3. **AI-augmented sourcing + живой recruiter.** Не software-only (как Harri/Workable), не enterprise-only AI (как Paradox), не просто job board. Полный цикл: sourcing → screening → placement → retention tracking.
4. **Pre-opening specialty.** Работаем с группами, где открытие нельзя сдвинуть на неделю.

### Кто такая Nastya

**Анастасия Щеголева (Nastya)** — Founder & CEO Luna Pastel. Пишет от первого лица как founder, не employee.
- Испанский: «Soy Nastya, founder de Luna Pastel»
- Русский: «Настя, founder Luna Pastel» или просто по имени в неформальном контакте

НЕ «представитель», «менеджер», «сотрудник».

### Ideal Customer Profile

- **P1 (highest pain):** QSR / fast-food chains 5+ локаций, full-service restaurant groups 5+ локаций
- **P2:** Hotel chains (mid-to-upscale), 50-200 staff per property
- **P3:** Contract catering (enterprise)
- В CRM также попадают independent groups 2-4 локации и single-location — им продаем тот же продукт, подстраивая позиционирование под меньший масштаб
- Партнеры/агенты в CRM — это не прямые клиенты, а источники referral'ов или co-selling

### Что НЕЛЬЗЯ писать в сообщениях

- **Никогда не цитируй investor-pitch цифры** (TAM €12-15B, €6M ARR, 75-80% gross margin, LTV/CAC, unit economics). Это для инвесторов, не для клиентов.
- **Никогда не упоминай IT-рекрутинг** как часть Luna Pastel в HoReCa outreach.
- **Не обещай точные метрики**, которых клиент не выводил сам («сократим ваш turnover на 50%» → звучит как брошюра).
- **Не пиши «уникальное предложение»** или «лучшие на рынке» — говори конкретикой: «€5K в месяц, все роли, замены включены».

### Почему voice отличается от основного Luna Pastel ETHOS

Основной `ETHOS.md` Luna Pastel предписывает формальный tone: «вы», без смайликов, 80-120 слов в первом касании. Это откалибровано под IT C-level и senior engineers.

В HoReCa tone осознанно **теплее и casual**:
- На «ты» с owner'ами ресторанов — они сами так пишут
- 1 emoji допустим, `))` редко — это мессенджер, не LinkedIn
- Короче (2-5 предложений) — рестораторы заняты сервисом, не читают длинное
- Voice Насти как founder, а не Luna Pastel corporate

Это не нарушение ETHOS, а его осознанная адаптация под другой рынок. Если лид — GM крупной сети отелей, возвращайся ближе к формальному ETHOS. Если owner семейного ресторана — полный casual.

## Write Scope (CRITICAL)

**Скилл пишет ТОЛЬКО в эти два столбца:**
- `🔸 Claude: Action` (text)
- `🔸 Claude: Message` (text)

**Никогда не трогает:**
- `Next Action` — Настина колонка, отражает ее план
- `Next Action Date` — Настин календарь
- `Stage`, `Notes`, `Category`, `Source`, `Company Name`, `Contact Name`, `Contact details`, `1st message sent` — source-of-truth данные

**В Claude-колонках разрешено:**
- Заполнять пустые ячейки
- **Перезаписывать** существующие, если новый анализ дает лучший результат (это ок, это и есть работа скилла — актуализировать подсказки)

Это инвариант скилла. Если при формировании payload для `notion-update-page` в properties попадает что-либо кроме `🔸 Claude: Action` и `🔸 Claude: Message` — это баг, останавливайся и не вызывай update.

## Step 1: Fetch CRM

Query the HoReCa CRM database view "Все лиды":

```
notion-query-database-view: view://33bf9167-2e00-805d-ac05-000cb6fb546c
```

## Step 2: Analyze Each Lead

For each lead, determine:

### 2a. Language

Determine communication language from Contact Name, Notes, Contact details:
- Russian names (Юлианна, Кира, Евгения, Yana) or Russian text in Notes → **Russian**
- Spanish/Catalan names, Spanish contact details, .es domains → **Spanish**
- English names, international context → **English**
- If unclear → **Spanish** (safest default for Spain-based business)

### 2b. Client Typology

From Category, Company Name, Notes, Contact Name:
- **Hotel GM / Chain director** → formal, structured, data-driven messaging
- **Restaurant owner / small group** → warm, direct, personal
- **Partner / Referral source** → collegial, value-exchange framing
- **Agent** → professional, opportunity-focused
- **Cafe / small venue** → casual, friendly, short messages

### 2c. Stage-Appropriate Action Type

| Stage | Default Action Type | Timing context (для формулировки Action/Message) |
|---|---|---|
| Cold (1st message sent) | Follow-up #1 | ~5-7 дней после 1st message |
| Cold (no 1st message) | First touch | в ближайшие дни |
| Replied | Continue conversation / propose meeting | быстро, 1-2 дня |
| Meeting Planned | Send reminder day before | за день до встречи |
| Meeting held | Follow-up with next steps | 1-2 дня после встречи |
| Proposal | Push to decision / address objections | 3-5 дней |
| Won | Onboarding / delivery kickoff | 1-2 дня |

Эта таблица нужна ТОЛЬКО чтобы правильно выбрать TYPE действия и встроить timing-контекст в текст. Мы не ставим дату в CRM — это поле Насти.

### 2d. Deep Research (обязательно для КАЖДОГО лида)

**НЕ экономь на API-вызовах.** Настя готова ждать дольше ради качества — цель, чтобы каждое сообщение звучало от человека, который реально понимает, кто перед ним, а не от бота, клепающего шаблон по Stage.

**1. Комментарии Notion.** Читай все комментарии на странице лида — и для холодных тоже. Настя часто оставляет там контекст, которого нет в Notes («был на встрече Horeca Expo», «знакомы через Катю», «писала в IG — не ответил»).

```
notion-get-comments: [page_id]
```

**2. Содержимое страницы.** `notion-fetch` возвращает child blocks (callouts, toggles, свободные заметки) — читай их, там часто лежат транскрипты звонков и детали встреч.

**3. Скриншоты и изображения.** Если на странице или в комментарии есть image:
1. Возьми URL из результата `notion-fetch`
2. Скачай: `curl -L -o /tmp/lead-img.jpg "<image_url>"`
3. Открой через Read: `Read /tmp/lead-img.jpg` — картинка придёт визуально
4. Проанализируй что на ней (скриншот переписки, визитка, меню, пост IG, фото заведения) и используй контекст в `🔸 Claude: Message`

Если на скриншоте переписка — конкретно процитируй/сошлись на то, что клиент написал. Если меню или интерьер — упомяни концепцию.

**4. Web-research.** Когда есть зацепка — гугли:
- Сайт компании из Contact details / Notes → `WebFetch` главной: концепция, локации, позиционирование, текущие вакансии на сайте
- Название ресторана/отеля → `WebSearch "[название] Barcelona"` (или другой город) — свежие новости, открытия, награды, смена шефа
- Instagram handle → `WebFetch` профиля, чтобы понять стиль, частоту постов, есть ли сейчас активная коммуникация про найм
- Партнёр/агент → поиск по «имя + компания», чтобы понимать его бизнес-контекст

Используй находки в сообщении естественно: «видела, что вы открываете вторую точку в Грасии» работает в 10 раз лучше, чем generic follow-up.

## Step 3: Generate Claude-Column Values

### 🔸 Claude: Action

Short action description in Russian. **ТОЛЬКО РУССКИЙ ЯЗЫК** — никогда не пиши сюда на английском, даже если лид англоязычный. Это поле видит Настя для навигации по своему CRM.

Examples (правильно):
- «Follow-up в Instagram»
- «Отправить предложение по email»
- «Напомнить о встрече»
- «Позвонить, уточнить решение»
- «Запланировать встречу»

Examples (НЕПРАВИЛЬНО, никогда не пиши так):
- «Follow-up reminder»
- «Meeting reminder»
- «Send proposal»
- «Schedule meeting»

### 🔸 Claude: Message

Full ready-to-send message. **Пиши целиком, 2-5 предложений, копипаст-ready для Telegram/WhatsApp/Instagram/email.** Не короткий label, не tag.

**VOICE RULES (STRICT):**

1. **No AI-slop.** No "надеюсь, у вас все хорошо", no "хотел бы уточнить", no "в рамках нашего сотрудничества". Write like a human.

2. **No em-dashes.** Only hyphens where grammatically needed. Em-dash is the #1 AI marker in Russian.

3. **No letter ё.** Always use е: еще, все, ведет, объем. Exception: where meaning changes (все vs всё).

4. **Nastya's voice.** Warm, direct, energetic. She writes like she talks in a messenger:
   - Can use `)` or `))` sparingly (1-2 per message MAX, not every sentence)
   - Can use ONE emoji per message where natural, not more
   - Short sentences. No complex subordinate clauses.
   - Asks concrete questions, not vague "как дела"
   - Gets to the point in the first sentence

5. **No selling bullshit.** No "уникальное предложение", no "выгодные условия", no "мы лучшие на рынке". Nastya talks about THEIR problem, not our product.

6. **Context-aware.** If Notes say "возражение - партнер против" — the message must address THAT, not generic follow-up. If the lead replied with a specific question — answer it.

7. **Short.** Follow-up: 2-4 sentences. First touch: 3-5 sentences. Proposal push: 3-4 sentences.

8. **Spanish messages** follow the same principles: natural, warm, direct. No "Estimado/a", no "Le escribo para...". Use "Hola [Name]," and get to the point. Tu/usted based on typology.

### Examples of GOOD messages:

**Russian, restaurant owner, follow-up after meeting:**
> Юлианна, привет! Как решили с партнером? Если удобно, давай я с ним познакомлюсь на короткой встрече, 15 мин. Напиши, когда ему ок 🙌

**Russian, partner, checking in:**
> Женя, привет! Как у тебя дела? Мы тут разогнались по хорике, есть пара интересных историй. Давай на неделе созвонимся?

**Spanish, hotel GM, proposal follow-up:**
> Hola Eugeni, quería ver si ya tienes la lista de posiciones. En cuanto la tenga, te preparo un plan de búsqueda con plazos concretos. ¿Te viene bien una llamada corta esta semana?

**Spanish, cold first touch via Instagram:**
> Hola! Soy Nastya, founder de Luna Pastel. Ayudamos a restaurantes con la contratación de equipo. Vi que tenéis un concepto muy chulo. ¿Buscáis personal ahora o tenéis todo cubierto?

### Examples of BAD messages (never generate these):

> Здравствуйте! Надеюсь, у вас все хорошо. Хотела бы уточнить, есть ли у вас потребность в наших услугах по подбору персонала. Мы предлагаем уникальную подписочную модель...

> Estimado Sr. Gonzalez, le escribo en nombre de Luna Pastel para ofrecerle nuestros servicios de reclutamiento especializado en el sector hostelería...

## Step 4: Update Notion

For each lead, write ONLY to the two Claude-columns:

```
notion-update-page:
  url: [lead's Notion URL]
  properties:
    "🔸 Claude: Action":  "<short Russian action>"
    "🔸 Claude: Message": "<full ready-to-send message in lead's language>"
```

**Invariant.** Никогда не включай в `properties` другие ключи. Если скрипт/промпт хочет записать `Next Action`, `Next Action Date`, `Stage`, `Notes` или любое другое поле — это баг, останавливайся и сообщай об этом в отчете вместо записи.

## Step 5: Report

After processing all leads, produce a summary in Russian:

```
📋 CRM Plan — [today's date]

Всего лидов: Y
Обновлено Claude-колонок: X

По лидам:
- [Company] ([Stage]) — Action: «...» | Message: готово
- [Company] ([Stage]) — Action: «...» | Message: готово
- ...
```

Group by Company. Сообщения в отчет НЕ вставляй целиком (они в Notion) — достаточно пометки «готово/обновлено».

## Notes

- This skill does NOT require session binding to a vacancy. It operates on the CRM sales database, not the Vacancies recruitment database.
- If the CRM has more than 50 leads, process them in batches and update progressively.
- **Качество важнее скорости и стоимости API.** Для КАЖДОГО лида (включая Cold) выполняй полный Deep Research из Step 2d: комментарии, child blocks страницы, image attachments, web-research. Не пропускай этапы ради экономии вызовов.
- **Контроль воронки — у Насти.** Скилл никогда не касается `Next Action`, `Next Action Date`, `Stage`, `Notes` и других Настиных полей. Claude-колонки — это second opinion, не команды.
