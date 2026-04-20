---
name: crm-plan
description: |
  Plan next actions for all leads in the HoReCa CRM.
  Fills empty or overdue Next Action Date / Next Action / Next Action Message.
  Generates ready-to-send messages in the client's language and Nastya's voice.
  Use when: "crm plan", "запланируй crm", "что делать по лидам", "crm-plan".
user-invocable: true
---

Read the file `lib/preamble.md` and follow all rules defined there.
Read the file `ETHOS.md` for tone of voice guidance.

# /crm-plan — Планирование действий по CRM

## Purpose

CEO не должна думать, что писать и когда. Она открывает CRM и видит готовый план на сегодня с сообщениями. Этот скилл заполняет пустые и просроченные Next Action поля по всей CRM-таблице.

## Safety Rule (CRITICAL)

**НИКОГДА не перезаписывай Next Action Date, если дата уже стоит и >= сегодня.**

Скилл обновляет ТОЛЬКО лиды, где:
- `Next Action Date` пустой, ИЛИ
- `Next Action Date` строго в прошлом (просрочено)

Если у лида стоит дата сегодня или в будущем — НЕ ТРОГАЙ. CEO или менеджер поставили её вручную.

## Step 1: Fetch CRM

Query the HoReCa CRM database view "Все лиды":

```
notion-query-database-view: view://33bf9167-2e00-805d-ac05-000cb6fb546c
```

## Step 2: Classify Each Lead

For each lead, determine:

### 2a. Needs update?

- `Next Action Date` is empty → YES
- `Next Action Date` < today → YES (overdue)
- `Next Action Date` >= today → SKIP (already planned)

### 2b. Language

Determine communication language from Contact Name, Notes, Contact details:
- Russian names (Юлианна, Кира, Евгения, Yana) or Russian text in Notes → **Russian**
- Spanish/Catalan names, Spanish contact details, .es domains → **Spanish**
- English names, international context → **English**
- If unclear → **Spanish** (safest default for Spain-based business)

### 2c. Client Typology

From Category, Company Name, Notes, Contact Name:
- **Hotel GM / Chain director** → formal, structured, data-driven messaging
- **Restaurant owner / small group** → warm, direct, personal
- **Partner / Referral source** → collegial, value-exchange framing
- **Agent** → professional, opportunity-focused
- **Cafe / small venue** → casual, friendly, short messages

### 2d. Stage-Appropriate Action

| Stage | Default Action Type | Timing |
|---|---|---|
| Cold (1st message sent) | Follow-up #1 | 5-7 days after 1st message |
| Cold (no 1st message) | First touch | Today or tomorrow |
| Replied | Continue conversation / propose meeting | 1-2 days |
| Meeting Planned | Send reminder day before | Day before meeting |
| Meeting held | Follow-up with next steps | 1-2 days after meeting |
| Proposal | Push to decision / address objections | 3-5 days |
| Won | Onboarding / delivery kickoff | 1-2 days |

## Step 3: Generate Next Actions

For each lead that needs update, generate:

### Next Action (what to do)
Short action description in Russian. Examples:
- «Follow-up в Instagram»
- «Отправить предложение по email»
- «Напомнить о встрече»
- «Позвонить, уточнить решение»

### Next Action Date
Based on Stage timing table above. Rules:
- Never set on weekends (Saturday/Sunday)
- Distribute across the week (don't pile 15 follow-ups on Monday)
- If lead has been Cold with no reply for 14+ days → set date 1 week out (low priority)
- Overdue leads → set to today or tomorrow

### Next Action Message
Ready-to-copy message in the client's language.

**VOICE RULES (STRICT):**

1. **No AI-slop.** No "надеюсь, у вас все хорошо", no "хотел бы уточнить", no "в рамках нашего сотрудничества". Write like a human.

2. **No em-dashes (—).** Only hyphens (-) where grammatically needed. Em-dash is the #1 AI marker in Russian.

3. **No letter ё.** Always use е: еще, все, ведет, объем. Exception: where meaning changes (все vs всё).

4. **Nastya's voice.** Warm, direct, energetic. She writes like she talks in a messenger:
   - Can use `)` or `))` sparingly (1-2 per message MAX, not every sentence)
   - Can use ONE emoji per message where natural (🙌 ☕ 👋), not more
   - Short sentences. No complex subordinate clauses.
   - Asks concrete questions, not vague "как дела"
   - Gets to the point in the first sentence

5. **No selling bullshit.** No "уникальное предложение", no "выгодные условия", no "мы лучшие на рынке". Nastya talks about THEIR problem, not our product.

6. **Context-aware.** If Notes say "возражение - партнер против" — the message must address THAT, not generic follow-up. If the lead replied with a specific question — answer it.

7. **Short.** Follow-up messages: 2-4 sentences. First touch: 3-5 sentences. Proposal push: 3-4 sentences.

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

For each lead that needs update, use the Notion page update tool:

```
notion-update-page:
  url: [lead's Notion URL]
  properties:
    Next Action Date: [calculated date]
    Next Action: [action description]
    Next Action Message: [ready-to-send message]
```

## Step 5: Report

After updating all leads, produce a summary in Russian:

```
📋 CRM Plan — [today's date]

Обновлено: X лидов из Y

На сегодня:
- [Company] — [Action] — [Stage]
- [Company] — [Action] — [Stage]

На завтра:
- ...

На этой неделе:
- ...

Не тронуто (уже запланировано): Z лидов
```

## Notes

- This skill does NOT require session binding to a vacancy. It operates on the CRM sales database, not the Vacancies recruitment database.
- If the CRM has more than 50 leads, process them in batches and update progressively.
- Read comments inside each Notion page for additional context ONLY for leads that are Replied or above (to save API calls). Cold leads get generic timing without page-level research.
