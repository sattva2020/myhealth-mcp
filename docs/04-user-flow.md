# 04 — User Flow

**Документ:** MyHealth-Europe — користувацькі сценарії і journey-mapи
**Версія:** 0.1
**Дата:** 12 травня 2026
**Власник:** Руслан Грибан
**Призначення:** опис того, як реальний громадянин ЄС взаємодіє з системою від першого знайомства до повсякденного використання.

---

## TL;DR (для комісії)

Користувач проходить через п'ять фаз: (A) знайомство і встановлення, (B) перший імпорт даних, (C) підключення AI-агента і налаштування довіри, (D) повсякденне використання, (E) обслуговування / міграція / відмова. Кожна фаза спроектована так, щоб користувач завжди розумів, де лежать його дані, хто до них має доступ і як це відкликати. Ключова дизайн-принципова рамка — **«No surprises»**: кожен раз, коли щось переходить trust boundary, користувач явно дозволяє це, і має змогу пізніше переглянути історію.

Найскладніший виклик у UX — пояснити неспеціалісту різницю між локальним AI-агентом (Claude Desktop, Llama локально) і cloud-AI (Claude API, OpenAI). UI робить це через колірний кодинг (зелений / жовтий) і явні попередження «ці дані підуть на сервер X».

---

## 1. Personas (детальніше, ніж у PRD)

### Persona A — Анна, IT-аналітикиня, expat у Берліні (34)
- **Технічна підкованість:** висока (може використати Docker).
- **Мотивація:** має 5 років української медичної історії + 3 роки німецької. Хоче спитати англомовного AI про «коли я востаннє робила пап-смір», бо в німецькій клініці запитують, а вона не пам'ятає.
- **Перепони:** не довіряє Apple Health (бо Apple). Не довіряє Google. Хоче control.

### Persona B — Йоганн, пенсіонер, Мюнхен ↔ Аліканте (71)
- **Технічна підкованість:** низька (smartphone, базовий ПК).
- **Мотивація:** має DE-призначення (5 препаратів) і ES-призначення (3 препарати). Боїться взаємодій. Лікар у Мюнхені не бачить іспанських даних.
- **Перепони:** не встановить Docker. Потребує simple-installer. Може потребувати допомоги онуки.

### Persona C — Ольга, медсестра з Естонії з хронічним станом (42)
- **Технічна підкованість:** середня (активна Digilugu-користувачка).
- **Мотивація:** хоче запитати AI про свій стан конфіденційно. Не хоче, щоб запити йшли в cloud. Цікавиться Llama локально.
- **Перепони:** обмежений вибір локальних моделей з медичною компетенцією.

### Persona D — Дмитро, біженець з Харкова у Варшаві (28)
- **Технічна підкованість:** середня.
- **Мотивація:** має UA-історію (eHealth Україна), починає польську (IKP). Не говорить польською вільно. Хоче AI, що допоможе зрозуміти польські лабораторні результати у контексті його UA-історії.
- **Перепони:** немає польського ID-карту → обмежений доступ до IKP.

---

## 2. Фаза A — знайомство і встановлення

### A.1. Touchpoint: користувач знаходить проект

Шляхи:
- Hacker News / r/selfhosted / r/privacy пост.
- EU digital rights newsletter (EFF EU, EDRi).
- Українська/естонська/польська медіа про health-tech.
- Через HealBot.pro (reference deployment) → користувач дізнається про upstream.
- Через DG SANTE EHDS implementation pages (якщо стане reference tool).

### A.2. Touchpoint: landing page myhealth-europe.eu

Що бачить:
- 1-екранний value proposition: «твоя медична історія, твої AI-помічники, твої правила».
- 3 use case у форматі коротких історій (на основі персон).
- Чесне попередження: «це інструмент для самостійного хостингу. Технічного рівня — як налаштувати домашній роутер».
- Кнопки: «Download for laptop», «Run on home server (Docker)», «Source on GitHub».
- Лінк на детальну документацію.

### A.3. Touchpoint: установка

Три шляхи, від найпростішого до advanced:

**A.3.1. Native installer (для persona B — Йоганн)**
- Завантажує `MyHealth-Europe-Setup-1.0.exe` (Windows), `.dmg` (macOS), `.AppImage` (Linux).
- Інсталер robotic: passphrase setup → finish.
- Запускається у tray, browser auto-opens на `http://localhost:7777`.

**A.3.2. Docker compose (для persona A — Анна, persona C — Ольга)**
```bash
curl -O https://myhealth-europe.eu/docker-compose.yml
docker compose up -d
open http://localhost:7777
```

**A.3.3. From source (для downstream developers, audit)**
```bash
git clone https://github.com/myhealth-europe/myhealth-europe
cd myhealth-europe
just setup && just run
```

### A.4. Touchpoint: первинне налаштування (setup wizard)

Кроки у wizard:
1. **Welcome screen** — пояснення, що зараз буде, на мові інтерфейсу (за замовчуванням — locale системи; явний switcher).
2. **Privacy explainer** — на ½ екрану пояснення, що жодні дані не виходять без явного дозволу; лінк на детальний `03-data-flow.md`.
3. **Passphrase setup** — мінімум 12 символів, perfect-passphrase suggestion (4-6 random words); попередження «ми НЕ зможемо відновити — це по дизайну».
4. **Recovery file** — wizard пропонує згенерувати recovery file (зашифрованим резервом ключа), користувач сам кладе його у безпечне місце (USB, banking sealed envelope, password manager).
5. **Locale** — мова інтерфейсу, мова medical records (можуть бути різні).
6. **First import** — пропонує одразу імпортувати; або skip.

---

## 3. Фаза B — перший імпорт даних

### B.1. Користувач обирає джерело

UI показує список підтримуваних джерел з flag-ами і коротким описом:
- 🇺🇦 eHealth Україна — «експорт з helsi.me або кабінету пацієнта НСЗУ»
- 🇪🇪 Estonia Digilugu — «експорт з digilugu.ee → My Data»
- 🍎 Apple Health — «Settings → Health → Export All»
- (більше — фаза 2)

Біля кожного — кнопка «How to export from here» з step-by-step screenshots.

### B.2. Користувач отримує файл

Залежно від persona:

**Persona A (Анна, для UA):**
1. Йде на helsi.me, авторизується BankID або Дія.
2. У кабінеті → Мої дані → Завантажити медичну історію → отримує `medical-history.json`.

**Persona C (Ольга, для EE):**
1. Йде на digilugu.ee, авторизується Mobile-ID.
2. Minu andmed → Eksport → `digilugu-export.json`.

**Persona D (Дмитро, для UA, працює без польського ID):**
1. Аналогічно Анні для UA-частини.
2. Для польської частини — Дмитро отримує тимчасовий PESEL через CUW і пізніше пробує IKP (фаза 2).

### B.3. Імпорт у MyHealth-Europe

```
UI → Import data → drag-and-drop файлу
   ↓
Detect: «це схоже на digilugu-export.json. Імпортувати як EE? [Yes/No/Manual]»
   ↓
Validation: «245 records valid, 0 errors, 2 warnings (legacy CDA → FHIR conversion)»
   ↓
Show summary table:
   ┌──────────────────┬───────┬──────────────────┐
   │ Resource type    │ Count │ Date range       │
   ├──────────────────┼───────┼──────────────────┤
   │ Observation      │ 156   │ 2018-03 – 2026-04│
   │ Condition        │ 23    │ 2019-01 – 2024-11│
   │ MedicationRequest│ 47    │ 2020-06 – 2026-05│
   │ Encounter        │ 19    │ 2018-03 – 2026-04│
   └──────────────────┴───────┴──────────────────┘
   ↓
[Import] → progress bar → done
```

### B.4. Що користувач робить далі

UI пропонує наступні кроки:
- «Імпортувати ще одне джерело» (для persona A — Анна, тепер імпортує DE ePA).
- «Подивитися мої records».
- «Підключити AI-агента» (наступна фаза).

---

## 4. Фаза C — підключення AI-агента і налаштування довіри

### C.1. Користувач обирає агента

UI показує матрицю варіантів з колір-кодингом:

| Агент | Де живе | Куди йдуть дані | Trust level |
|-------|---------|-----------------|-------------|
| Claude Desktop (local install) | Локальний процес | Anthropic API (cloud) | 🟡 жовтий |
| OpenAI ChatGPT Desktop | Локальний процес | OpenAI API (cloud) | 🟡 жовтий |
| Llama (Ollama локально) | Локальний процес | Нікуди | 🟢 зелений |
| EU-hosted Mistral | Локальний клієнт | Mistral EU servers | 🟡 жовтий (EU) |
| Custom MCP-client | Per-config | Per-config | ⚪ невідомо |

Біля кожного — пояснення доступною мовою. Жовтий ≠ погано — це означає «ти свідомо ділишся з cloud».

### C.2. Підключення Claude Desktop (приклад для persona A)

1. У Claude Desktop → Settings → MCP Servers → Add server.
2. Або копіює-paste з MyHealth-Europe UI («Click to copy Claude config»).
3. Конфіг:
   ```json
   {
     "mcpServers": {
       "myhealth-europe": {
         "command": "myhealth",
         "args": ["mcp-server", "--stdio"]
       }
     }
   }
   ```
4. Перезапускає Claude Desktop.
5. Тепер у Claude доступні tools `get_observations`, `get_medications`, etc.

### C.3. Перша AI-сесія — flow згоди

```
[Анна у Claude:] «Я не пам'ятаю, коли мені робили пап-смір. Можеш знайти?»

[Claude:] (хоче викликати get_observations(category=exam, code=pap-smear))
          Запит permission через MCP → MyHealth-Europe consent gateway

[UI MyHealth-Europe (notification):]
   ┌────────────────────────────────────────────────────────┐
   │ Claude Desktop запитує:                                │
   │                                                         │
   │ Читання: Observations                                  │
   │ Category: examination                                  │
   │ Filter: pap-smear, all dates                          │
   │                                                         │
   │ Trust level: 🟡 cloud (дані підуть на anthropic.com)  │
   │                                                         │
   │ [Дозволити на 5 хв] [На 1 год] [На 24 год] [Ні]      │
   │                                                         │
   │ ☐ Запам'ятати цей вибір для подібних запитів          │
   └────────────────────────────────────────────────────────┘

[Анна натискає "На 5 хв"]

[Claude отримує token → читає 2 results → формує відповідь]
[Claude:] «Останній пап-смір — 2024-09-12, у клініці X у Берліні.
           Попередній — 2023-03-15 у Києві. Згідно з ESGO рекомендаціями,
           наступний — 2027-09 (3 роки інтервал для нормальних результатів).»

[Анна — у UI MyHealth-Europe:]
   Audit log shows: READ at 14:32, scope=examination:pap-smear,
   agent=claude-desktop, count=2, token expires 14:37
```

### C.4. Налаштування «персистентних» дозволів

Для повторних запитів користувач може налаштувати persistent grant:
- Scope: medication list (без psych meds)
- TTL: 30 днів
- Agent: Llama local
- Conditions: тільки на цьому пристрої

Це робиться у UI → Sessions → New persistent grant.

---

## 5. Фаза D — повсякденне використання

### D.1. Use case: routine question
Анна → Claude → «Який мій останній HbA1c?» → consent prompt (бо новий scope) → дозвіл 1 год → відповідь.

### D.2. Use case: cross-border continuity (для persona B — Йоганн)
Йоганн перед поїздкою до Аліканте:
1. Імпортує свої німецькі ePA дані.
2. Запитує: «Підготуй summary для іспанського лікаря іспанською».
3. Агент → запит scope `read:all` на 30 хв → Йоганн дозволяє → агент генерує PDF.
4. Йоганн друкує PDF, везе з собою.

### D.3. Use case: меdication reconciliation
Йоганн:
1. Імпортує обидва набори (DE + ES).
2. Запитує: «Чи є взаємодії між моїми DE і ES призначеннями?»
3. Агент → query medications → call drug interaction DB → відповідь.

### D.4. Use case: privacy-conscious offline
Ольга:
1. Запускає Llama локально (Ollama).
2. Підключає до MyHealth-Europe.
3. Запитує — все відбувається offline. Audit log показує `agent=ollama-local`, trust=🟢.

### D.5. Use case: новий лікар у Польщі
Дмитро:
1. Імпортує UA-історію.
2. Перед першим візитом до польського терапевта генерує PDF з основними діагнозами/призначеннями польською мовою.
3. Розпечатує. Приносить.

### D.6. Recurring touchpoints
- Періодичний re-import (раз на квартал — нові записи з джерела).
- Перегляд audit-log (раз на місяць — хто читав).
- Revoke стейлих grants (UI помічає grants старші 90 днів і пропонує revoke).

---

## 6. Фаза E — обслуговування, міграція, відмова

### E.1. Backup
```bash
myhealth backup --out ~/Documents/myhealth-backup-2026-05-12.enc
```
або UI → Settings → Backup → запрошує куди зберегти. Backup encrypted з тим самим ключем; recoverable тільки з passphrase + recovery file.

### E.2. Перенесення на новий пристрій
1. На новому пристрої — install + setup wizard.
2. На step "Initial passphrase" — обрати "Restore from backup".
3. Завантажити backup file + ввести passphrase + recovery file.
4. Дані відновлено, агенти треба переналаштувати (consent grants per-device для security).

### E.3. Видалення даних
- UI → Settings → Danger zone → Delete all data.
- Confirmation з typing «DELETE EVERYTHING».
- Дані soft-deleted на 30 днів (recoverable).
- Через 30 днів — hard delete + аудит-запис.

### E.4. Експорт всього для іншого тулу
```bash
myhealth export --format fhir-bundle --out ~/my-data-bundle.json
```
Стандартний FHIR R4 bundle, переноситься у будь-який FHIR-сумісний сервіс. Це GDPR Art. 20 portability.

### E.5. Відмова від проекту (offboarding)
- Користувач експортує дані як у E.4.
- Видаляє приложення.
- Все. Жодних залишків на проектному боці (бо їх не було).

### E.6. Що, якщо користувач втратив passphrase
- Якщо є recovery file — використовує його для unlock.
- Якщо немає recovery file — дані втрачено. По дизайну. Це попереджено у setup wizard у трьох місцях.
- Альтернатива: re-import з джерел (дані-то лежать у первинних джерелах).

---

## 7. Перехресні стани і edge cases

| Сценарій | Поведінка |
|----------|-----------|
| Користувач імпортує файл з invalid FHIR | Партіально імпортуються валідні, інші у quarantine з вказанням причини |
| Імпорт того ж файлу двічі | Idempotent — не дублюється |
| Користувач хоче імпортувати «з другої країни» | Кожне джерело — окремий import; usepole не путаются |
| Дві instance на одному ПК (наприклад, для сімейних членів) | Підтримується через `--config` flag з різними passphrase; isolated stores |
| Дитячі дані (батько імпортує дітей) | Out of scope у фазі 1; явне попередження «використовуйте окремий інстанс per person» |
| Smartphone-only користувач | Out of scope у фазі 1 (mobile-нативний клієнт — фаза 2). Можна через mobile browser до self-hosted на NAS |
| AI-агент проситъ забагато scope | Consent UI явно вказує, скільки даних попадуть; користувач може вручну urіti scope |
| Аудит-лог переповнюється | Rotation за TTL (default: 2 роки); експорт перед rotation як CSV |

---

## 8. Метрики UX (для validation у M6)

| Метрика | Як міряємо | Цільове |
|---------|-----------|---------|
| Time-to-first-import | Від install до перший імпорт | <15 хв медіана у n=10 user test |
| Consent comprehension | Чи розуміє користувач, що дає згоду | ≥80% правильних відповідей у follow-up інтерв'ю |
| Trust-level differentiation | Чи розрізняє local-vs-cloud AI | ≥80% у follow-up |
| Task success | Чи можуть завершити «знайди останній HbA1c» | ≥80% без допомоги |
| SUS score (System Usability Scale) | Стандартний SUS-опитник | ≥70 (above average) |

---

*Дивись: [03-data-flow.md](03-data-flow.md) для технічної деталізації того, що рухається; [06-architecture.md](06-architecture.md) для компонентів, які реалізують ці flow.*
