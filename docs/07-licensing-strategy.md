# 07 — Licensing Strategy

**Документ:** MyHealth-Europe — стратегія відкритих ліцензій
**Версія:** 0.1
**Дата:** 12 травня 2026
**Власник:** Руслан Грибан

---

## TL;DR

Проект використовує **split-licensing model**: ядро системи (MCP-сервер, FHIR-адаптери, consent gateway, UI client) — під **Apache 2.0** (максимальне прийняття, downstream-комерційні форки дозволені); reference cross-border navigation agent — під **AGPL 3.0** (заохочує open-source у наслідувачах reference-аплікації); документація і replication kit — під **CC BY-SA 4.0**; sample data — **CC0**.

Логіка: ядро повинно бути «дешевим» для прийняття будь-ким (національний e-health орган, госпіталь, стартап) — звідси Apache. Reference-агент — це демо, ілюстрація патерну; якщо хтось будує власний клінічний агент на ньому, ми хочемо, щоб результат залишився відкритим — звідси AGPL. Цей split — стандартний для open commons проектів і узгоджений з NLnet expectations.

Питання Apache vs AGPL для ядра було відкрите у грантовому драфті (розділ 13, пункт 5); цей документ закриває його у бік split-моделі з obґрунтованням.

---

## 1. Принципи вибору ліцензій

Кожна ліцензія у проекті обирається проти конкретного оптимізаційного критерію.

### 1.1. Для ядра — пріоритет «максимальне прийняття»

**Цільові вживачі ядра:**
- Національні e-health агентства, які захочуть локалізувати або форкнути для своєї країни.
- Комерційні health-tech компанії, які побудують managed-hosting сервіс поверх ядра.
- Дослідницькі команди, які хочуть інтегрувати у свої pipeline-и.
- Госпіталі і клініки, які можуть захотіти deployment у controlled environment.
- Open-source contributors і forks.

**Обмеження для всіх цих груп:** будь-який copyleft (GPL, AGPL) у ядрі — створює юридичний бар'єр для комерційного прийняття. Госпіталь з custom EHR не зможе інтегрувати, бо їхній EHR став би derivative work під GPL.

**Висновок:** ядро — **Apache 2.0** (permissive copyleft-free + patent grant).

### 1.2. Для reference-агента — пріоритет «open-source у downstream»

**Цільові вживачі reference-агента:**
- Розробники, які хочуть зрозуміти патерн і побудувати свій агент.
- Pилотні deployments у конкретних кейсах (UA-EE, UA-PL, DE-ES, ...).
- Демонстраційні installations на community-events.

**Обмеження:** не хочемо, щоб хтось взяв наш reference cross-border navigation agent, додав до нього 10% коду і випустив як закритий комерційний продукт «cross-border health AI» — це підриває commons. Тому agent — це той самий випадок, що backend SaaS: користувач взаємодіє через мережу, без strong copyleft нічого не зобов'язує оприлюднити модифікації.

**Висновок:** reference-агент — **AGPL 3.0** (з її SaaS-фіксацією, тобто network-use trigger).

### 1.3. Для документації — пріоритет «share-alike»

**Висновок:** **CC BY-SA 4.0**. Стандарт для shareable docs у європейському commons-просторі.

### 1.4. Для sample data — пріоритет «нульове тертя»

**Висновок:** **CC0**. Синтетичні FHIR bundles не повинні мати жодних обмежень.

---

## 2. Компонент-ліцензійна матриця

| Компонент | Ліцензія | SPDX identifier | Файли |
|-----------|----------|-----------------|-------|
| MCP-сервер ядро | Apache License 2.0 | `Apache-2.0` | `/server/**/*.py` |
| FHIR-адаптери (UA, EE, Apple) | Apache 2.0 | `Apache-2.0` | `/adapters/**/*.py` |
| OAuth 2.1 consent gateway | Apache 2.0 | `Apache-2.0` | `/consent/**/*.py` |
| Local store і audit log | Apache 2.0 | `Apache-2.0` | `/store/**/*.py`, `/audit/**/*.py` |
| Reference UI client | Apache 2.0 | `Apache-2.0` | `/ui/**/*` |
| Reference cross-border navigation agent | GNU Affero GPL v3.0 | `AGPL-3.0-or-later` | `/agent/**/*.py` |
| Документація і replication kit | CC BY-SA 4.0 | `CC-BY-SA-4.0` | `/docs/**/*.md` |
| Sample / synthetic FHIR data | CC0 1.0 Universal | `CC0-1.0` | `/testdata/**/*` |
| Build scripts і CI | Apache 2.0 | `Apache-2.0` | `/.github/**/*`, `/scripts/**/*` |

---

## 3. Обґрунтування split: Apache 2.0 для ядра, AGPL 3.0 для агента

### 3.1. Чому НЕ повний Apache 2.0

Якби ми поклали ВСЕ під Apache 2.0:
- Перевага: максимальне прийняття у всі downstream-кейси.
- Недолік: хтось бере наш cross-border navigation agent, обертає його у GUI, додає підписку «$10/міс», і випускає як `MyHealthMonster.app` без жодного зобов'язання поділитися кодом. Це створює тиск на власне ядро («чого ми відкриваємо, якщо хтось монетизує наш агент?»).

### 3.2. Чому НЕ повний AGPL 3.0

Якби ми поклали ВСЕ під AGPL 3.0:
- Перевага: усі downstream-форки лишаються відкритими.
- Недолік: жодна комерційна health-tech компанія не торкнеться ядра. Жоден національний e-health не зможе інтегрувати, бо їхня система буде «used over network» з ядра → AGPL trigger → їм треба відкривати свою інфраструктуру. Це commons-killer для серйозних deployments.

### 3.3. Чому split працює

- **Ядро — Apache 2.0** — кожен може брати, інтегрувати, монетизувати. Це reference implementation MCP-серверу health-даних. Чим більше прийняття — тим стандарт стає де-факто.
- **Reference агент — AGPL 3.0** — це не stadnard, це демо. Хочеш свій агент — будуй свій. Хочеш форкнути наш — окей, але результат лишається відкритим, бо це частина commons.

Це той самий патерн, який використовують Mastodon (AGPL для server) + ActivityPub (open standard, permissive), Element/Matrix (Apache для libraries, AGPL для server), Bluesky (Apache для libraries, MIT для server — інший вибір, але та сама ідея split).

### 3.4. Альтернатива: dual licensing

Не використовуємо. Dual licensing (Apache + комерційний) це бізнес-модель MongoDB-стилю, яка вимагає CLA від контриб'юторів — а CLA значно знижує contributor accessibility. Для FSTP-фінансованого commons-проекту ця складність невиправдана.

---

## 4. Contributor License Agreement (CLA)

**Не використовуємо CLA.** Замість того — Developer Certificate of Origin (DCO).

**Чому:**
- CLA вимагає юридичної reviewу і registration кожного contributor-а.
- DCO (sign-off у commit message: `Signed-off-by: ...`) — мінімальне, юридично-достатнє.
- DCO використовується Linux kernel, Docker, Git, Chromium, etc. — це стандарт у Apache 2.0-based проектах.

DCO file (`DCO.md`) у репозиторії і pre-commit hook, що перевіряє sign-off.

---

## 5. Третя сторона: dependencies

### 5.1. Acceptable inbound licenses (для dependencies):

- Apache 2.0
- BSD (2-clause, 3-clause)
- MIT
- ISC
- MPL 2.0 (file-level copyleft, OK для libraries)
- LGPL 2.1+/3.0+ (тільки dynamic linking)
- CC0
- Python Software Foundation License
- Unlicense

### 5.2. NOT acceptable (incompatible з Apache 2.0):

- GPL 2.0 (без classpath exception)
- GPL 3.0 (без exception)
- AGPL 3.0 (бо ми хочемо ядро лишити permissive)
- Custom non-OSI licenses
- "Source available" non-FOSS licenses (Elastic, Confluent, BSL)
- SSPL

### 5.3. Process

- `pip-licenses` (Python) або еквів. у CI.
- Lock file checked у repo.
- New dependency PR блокується, якщо ліцензія не у allowlist.

---

## 6. Downstream guidance

Цей розділ — для людей, які хочуть форкнути або інтегрувати MyHealth-Europe.

### 6.1. Сценарій: «Я хочу зробити свою країну»

- Бери Apache 2.0 ядро, форкни.
- Напиши свій FHIR-адаптер у `/adapters/your_country/`.
- Контриб'юй адаптер upstream через PR (заохочуємо).
- Або тримай свою власну версію — Apache 2.0 не зобов'язує до upstream.

### 6.2. Сценарій: «Я хочу зробити SaaS навколо цього»

- Якщо беруть ядро (Apache 2.0) — нема перешкод. Можна побудувати managed-hosting, додати власні UI, монетизувати.
- Якщо беруть reference-агент (AGPL) — повинні розкрити свої модифікації і виставити користувачам source code link.

### 6.3. Сценарій: «Я хочу інтегрувати у наш hospital EHR»

- Apache 2.0 дозволяє повну інтеграцію без зобов'язання відкривати EHR.
- AGPL trigger тільки якщо ви використовуєте *наш reference agent code*; якщо ви будуєте власний клінічний інструмент над ядром — AGPL не зачіпається.

### 6.4. Сценарій: «Я хочу опублікувати наукову статтю»

- Документація CC BY-SA 4.0 — цитуйте з attribution.
- Sample data CC0 — нічого не зобов'язує.
- Бажано — посилання на проект і MoU з NLnet (для citation).

---

## 7. Trademark policy

**Цей розділ — placeholder, фіналізація з юристом на M3.**

Робоча версія:
- «MyHealth-Europe» — потенційний trademark (фінальне рішення — після Q4 2026, юр. консультація).
- Якщо trademark — то policy у стилі Mozilla: вільне використання для community-versions з no-confusion-test; комерційні використання вимагають окремої ліцензії.
- Сам логотип/branding — CC BY-SA 4.0.

Цей пункт — НЕ блокер для open-source ліцензування. Trademark і copyright — окремі.

---

## 8. EU дотичні нюанси

### 8.1. EUPL 1.2 — чому не вона

European Union Public License — рекомендований ЄС вибір для projects, що отримують EU funding. Однак:
- EUPL — copyleft (слабкіший за AGPL, але є).
- Менш популярна у глобальній OSS-екосистемі — менший пул contributors.
- Для NGI-фінансованого commons-проекту Apache 2.0 — преcedented і прийнятий ([NLnet portfolio](https://nlnet.nl/project/) має багато Apache-проектів).
- EUPL — добрий вибір для public-sector-only проектів; ми ширші.

Якщо NLnet висловить preference на EUPL — змінюємо. До того — Apache.

### 8.2. GDPR і licensing

Ліцензія не звільняє від GDPR. Downstream-впроваджувачі, які приймають PHI у production, лишаються data controllers. Документація явно це фіксує (`docs/deployment/gdpr-checklist.md` — створюємо на M9).

### 8.3. EHDS і licensing

EHDS не вимагає конкретної ліцензії, але recommends open-source для tooling. Apache 2.0 + AGPL 3.0 split вписується.

---

## 9. License headers і metadata

### 9.1. Header у кожному source file

```python
# SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
# SPDX-License-Identifier: Apache-2.0
```

Для AGPL-агента:
```python
# SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
```

### 9.2. Repo-level

- `LICENSE` (Apache 2.0 текст у корені).
- `LICENSES/` директорія з повними текстами усіх ліцензій (Apache 2.0, AGPL 3.0, CC BY-SA 4.0, CC0 1.0).
- `REUSE.toml` для REUSE.software compliance.

### 9.3. REUSE compliance

Project дотримується [REUSE Specification 3.0](https://reuse.software/spec/). CI перевіряє через `reuse lint`. Це стандарт для прозорої licensing у OSS, рекомендований FSFE і прийнятий багатьма EU-фінансованими проектами.

---

## 10. Sign-off на стратегію

Цей документ потребує підтвердження:

- [ ] Грибан Р. (project lead) — primary decision.
- [ ] Сураєв О. — peer review.
- [ ] Мирошников Д. — BD-аспект (комерційний adoption через permissive ядро).
- [ ] Тетяна Грибан — приймає до відома.
- [ ] (опційно) Незалежний юрист OSS-ліцензій — review перед v1.0.
- [ ] NLnet contact — informational notice після MoU.

---

*Дивись: [`../../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../../NGI-CommonsFund-13-DRAFT-2026-05-08.md) розділ 9 для оригінального license-планування у грантовому драфті; [01-business-requirements.md](01-business-requirements.md) для бізнес-контексту.*
