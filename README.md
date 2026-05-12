# MyHealth-Europe

**Open-source Model Context Protocol сервер для health-даних під контролем громадян ЄС.**

Apache 2.0 (ядро) / AGPL 3.0 (reference-агент). Self-hosted. Privacy-by-architecture, не privacy-by-policy.

---

## TL;DR (для команди, грантової комісії та зовнішніх читачів)

Сьогодні AI-асистент у сфері здоров'я живе всередині того, хто володіє твоїми даними — Apple, Google, Epic, національний e-health портал. Користувач не може взяти **свого** агента і направити його на **свої** записи на **своїх** умовах. MyHealth-Europe вирішує саме це: це програма, яку кожен громадянин ЄС запускає у себе (на ноутбуці, Raspberry Pi, домашньому NAS або self-hosted VPS), імпортує свої FHIR-записи з національних e-health систем, і через MCP-протокол надає будь-якому AI-агенту обмежений за scope і часом доступ до конкретних записів — з аудит-логом і явною згодою на кожен сеанс.

У проектної команди немає і не буде доступу ні до одного байту користувацьких даних. Це архітектурна властивість, а не обіцянка в privacy policy.

## Що проект поставляє в open source

| Компонент | Ліцензія | Призначення |
|-----------|----------|-------------|
| MCP-сервер ядро | Apache 2.0 | Серце системи: запити, згода, аудит |
| FHIR-адаптери (UA, EE, Apple, Google) | Apache 2.0 | Імпорт із bulk-export файлів |
| OAuth 2.1 consent gateway | Apache 2.0 | Потік згоди користувача на запити AI-агентів |
| Reference UI client (web, self-hosted) | Apache 2.0 | Локальний веб-інтерфейс для управління |
| Reference cross-border navigation agent (HealBot.pro) | AGPL 3.0 | Демонстрація патерну в реальному кейсі |
| Документація, replication kit | CC BY-SA 4.0 | Гайди для самостійного розгортання та адаптації |
| Synthetic test datasets | CC0 | Тестові FHIR-bundle-и без реальних PHI |

## Що проект НЕ робить

- **Не збирає дані.** Жодного централізованого сховища. Жодного API на проектному сервері. Жодних аналітичних подій.
- **Не вимагає cloud-акаунту.** Усе працює offline-first; cloud-deployment — опція, не вимога.
- **Не залежить від конкретного LLM-провайдера.** Працює з будь-яким MCP-сумісним клієнтом — Claude Desktop, OpenAI агенти, локальні Llama-моделі, EU-hosted комерційні LLM.
- **Не лікує і не дає медичних рекомендацій.** Це data-layer, а не клінічний продукт. Клінічна логіка — на стороні AI-агента і самого користувача.

## Контекст проекту

- **Грантовий драфт:** [`../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../NGI-CommonsFund-13-DRAFT-2026-05-08.md) — версія v0.2 драфту заявки на NGI Zero Commons Fund #13 (дедлайн 1 червня 2026, запит €50 000).
- **Umbrella-позиціонування:** MyHealth-Europe = Module №1 (Health) ширшого open-source проекту **CivicAI Bridge**, який команда готує до подачі на DIGITAL-2027-AI.
- **Команда:** 4 співзасновники (Грибан Р. — Project Lead, Сураєв О. — Coordination, Мирошников Д. — BD/EU networking, Грибан Т. — Domain Advisor).

## Навігація по docs/

Кожен документ двошаровий: спершу TL;DR (5-10 рядків, для нетехнічного читача), далі deep dive (для розробників/аудиторів).

| # | Документ | Що там |
|---|----------|--------|
| 01 | [Business Requirements (BRD)](docs/01-business-requirements.md) | Проблема, аудиторія, цілі, KPI, скоуп, обмеження |
| 02 | [Product Requirements (PRD)](docs/02-prd.md) | Функціональні і нефункціональні вимоги, фічі по M1-M9 |
| 03 | [Data Flow](docs/03-data-flow.md) | **Найважливіше для комісії.** Звідки беруться дані, як рухаються, що ніколи не виходить назовні |
| 04 | [User Flow](docs/04-user-flow.md) | User journeys: інсталяція, імпорт, згода, повсякденне використання |
| 05 | [Tech Stack](docs/05-tech-stack.md) | Порівняння Python / TypeScript / Go / Rust — **закріплено Rust + `rmcp`** |
| 06 | [Architecture](docs/06-architecture.md) | Компоненти, границі довіри, deployment topology |
| 07 | [Licensing Strategy](docs/07-licensing-strategy.md) | Apache 2.0 / AGPL 3.0 split, обґрунтування, downstream guidance |
| 08 | [Threat Model](docs/08-threat-model.md) | STRIDE-аналіз, припущення, контрзаходи, прив'язка до M5/M8 |

## Поточний статус проекту

**Pre-implementation, design phase.** Грантовий драфт у фінальному review, цей workspace описує систему до подання заявки. Імплементація стартує після підписання MoU з NLnet (очікувано Q3 2026).

## Ліцензія

Документи в цій теці — CC BY-SA 4.0. Код (коли з'явиться) — за компонентами згідно з [licensing strategy](docs/07-licensing-strategy.md).

## Контакт

Ruslan Hryban — ruslan.griban@gmail.com — `linkedin.com/in/ruslan-hryban-ai`
