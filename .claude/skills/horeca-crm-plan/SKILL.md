---
name: horeca-crm-plan
description: |
  Plan next actions for all leads in the HoReCa CRM.
  Fills Next Action Date / Next Action / Next Action Message per lead.
  Generates ready-to-send messages in the client's language and Nastya's voice.
  Use when: "horeca crm plan", "запланируй crm", "что делать по лидам", "horeca-crm-plan".
user-invocable: true
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /horeca-crm-plan — Планирование действий по CRM

## Purpose

CEO не должна думать, что писать и когда. Она открывает CRM и видит по каждому лиду готовое сообщение и дату следующего контакта. Скилл проходит по ВСЕЙ таблице и заполняет поля Next Action / Next Action Message для каждого лида, плюс ставит оптимальную Next Action Date там, где она не задана вручную или просрочена.

## Safety Rule (CRITICAL)

**Next Action Date можно ставить или менять ТОЛЬКО если:**
- она пустая, ИЛИ
- она строго в прошлом (просрочено)

Если дата уже стоит и >= сегодня — это ручное решение CEO или менеджера, **не трогай ее**.

**Next Action и Next Action Message обновляются ВСЕГДА,** если они пустые или явно устарели (не соответствуют текущему Stage / последним Notes). Это касается даже лидов с будущей датой: мы не трогаем дату, но помогаем с содержанием.

## Processing Logic (per lead)

Для каждого лида вычисляем три поля независимо:

### Next Action Date

- Пустая → рассчитай оптимальную дату
- В прошлом → поставь на сегодня или ближайший разумный день
- Сегодня или в будущем → **НЕ ТРОГАЙ**

### Next Action

- Пустое → заполни
- Заполнено, но не соответствует текущему Stage (например, стадия Meeting held, а в Next Action «позвонить для первого контакта») → перепиши
- Заполнено и соответствует Stage → не трогай

### Next Action Message

- Пустое → сгенерируй
- Заполнено, но контекст изменился (новая Note, новый Stage) → перепиши
- Заполнено и актуально → не трогай

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

| Stage | Default Action Type | Optimal Timing (when date is empty/overdue) |
|---|---|---|
| Cold (1st message sent) | Follow-up #1 | 5-7 days after 1st message |
| Cold (no 1st message) | First touch | Today or tomorrow |
| Replied | Continue conversation / propose meeting | 1-2 days |
| Meeting Planned | Send reminder day before | Day before the meeting |
| Meeting held | Follow-up with next steps | 1-2 days after meeting |
| Proposal | Push to decision / address objections | 3-5 days |
| Won | Onboarding / delivery kickoff | 1-2 days |

**Timing rules (only when setting/updating the date):**
- Skip weekends (Saturday/Sunday) — shift to Monday
- If Cold without reply for 14+ days → 1 week out (low priority)
- If multiple leads end up on same day, that's fine — we don't artificially spread

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
4. Проанализируй что на ней (скриншот переписки, визитка, меню, пост IG, фото заведения) и используй контекст в Next Action Message

Если на скриншоте переписка — конкретно процитируй/сошлись на то, что клиент написал. Если меню или интерьер — упомяни концепцию.

**4. Web-research.** Когда есть зацепка — гугли:
- Сайт компании из Contact details / Notes → `WebFetch` главной: концепция, локации, позиционирование, текущие вакансии на сайте
- Название ресторана/отеля → `WebSearch "[название] Barcelona"` (или другой город) — свежие новости, открытия, награды, смена шефа
- Instagram handle → `WebFetch` профиля, чтобы понять стиль, частоту постов, есть ли сейчас активная коммуникация про найм
- Партнёр/агент → поиск по «имя + компания», чтобы понимать его бизнес-контекст

Используй находки в сообщении естественно: «видела, что вы открываете вторую точку в Грасии» работает в 10 раз лучше, чем generic follow-up.

## Step 3: Generate Fields

### Next Action

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

### Next Action Message

**Schema note:** `Next Action Message` is a `text` property. Write the full ready-to-send message directly into this field. Don't use a short label or tag — put the ENTIRE message (2-5 sentences, ready to copy-paste into Telegram/WhatsApp/Instagram).

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
> Hola! Soy Nastya de Luna Pastel, ayudamos a restaurantes con la contratación de equipo. Vi que tenéis un concepto muy chulo. ¿Buscáis personal ahora o tenéis todo cubierto?

### Examples of BAD messages (never generate these):

> Здравствуйте! Надеюсь, у вас все хорошо. Хотела бы уточнить, есть ли у вас потребность в наших услугах по подбору персонала. Мы предлагаем уникальную подписочную модель...

> Estimado Sr. Gonzalez, le escribo en nombre de Luna Pastel para ofrecerle nuestros servicios de reclutamiento especializado en el sector hostelería...

## Step 4: Update Notion

For each lead, apply updates per the Processing Logic above. Only write the fields that actually changed:

```
notion-update-page:
  url: [lead's Notion URL]
  properties:
    Next Action Date: [only if empty or was overdue]
    Next Action: [only if empty or stale]
    Next Action Message: [only if empty or stale]
```

## Step 5: Report

After processing all leads, produce a summary in Russian:

```
📋 CRM Plan — [today's date]

Всего лидов: Y
Обновлено: X

Изменения:
- [Company] ([Stage]) → дата: [...] | action: [...] | message: [обновлено/без изменений]
- ...

Даты не тронуты (запланировано вручную): Z лидов
```

Group by Company, show what changed per lead. Keep the report compact.

## Notes

- This skill does NOT require session binding to a vacancy. It operates on the CRM sales database, not the Vacancies recruitment database.
- If the CRM has more than 50 leads, process them in batches and update progressively.
- **Качество важнее скорости и стоимости API.** Для КАЖДОГО лида (включая Cold) выполняй полный Deep Research из Step 2d: комментарии, child blocks страницы, image attachments, web-research. Не пропускай этапы ради экономии вызовов.
