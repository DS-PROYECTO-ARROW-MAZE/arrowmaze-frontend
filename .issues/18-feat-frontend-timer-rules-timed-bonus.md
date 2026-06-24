# feat(frontend): timer rules — timed levels ≥10, untimed 1–9, bonus-level exemption

- **Phase:** 5 — enhancement
- **Stories:** B/D (session + scoring rules)
- **Blocked by:** 04 (session state machine), 06 (scoring & stars), 17 (catalog/numero)
- **Cross-repo twin:** `arrowmaze-backend` ticket 15 (same rule table)
- **Traceability:** PRD §3 · CLAUDE.md State machine (`PlayingState`, `VictoryState`)

> The presence of a countdown timer is governed by the level's integer `numero`, and bonus
> levels opt out of timing **and** scoring entirely:
>
> | `numero` | `esBonus` | Timer | Scoring |
> |---|---|---|---|
> | 1–9 | false | **none** | yes |
> | ≥10 | false | **countdown (`limiteTiempo`)** | yes |
> | any | true | **none** | **no** |
>
> Running out of time on a timed level is a defeat; bonus levels can neither be lost on
> time nor produce a `Puntaje`/`Estrellas`.

## User Story

> *As a player, levels 1–9 let me take my time, levels 10+ put me on the clock, and bonus
> levels are a relaxed break with no timer and no score.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain`/`application` | the timed-vs-`numero` and bonus rules read from `DefinicionNivel` (`numero`, `esBonus`, `limiteTiempo?`) — data-driven, no `if` on difficulty |
| `presentation` (DM-F8) | `JuegoViewModel` starts a countdown only when the level is timed; exposes remaining time to the HUD; on a bonus level neither timer nor score is shown |
| `presentation` | timeout → defeat transition via the existing GoF State machine (no new state — it's a normal `EstadoDerrota`) |
| `application` (DM-F6) | scoring is skipped on bonus levels (mirrors backend ticket 15/17) |

## Acceptance Criteria

1. Levels `numero 1–9` (non-bonus) run with **no timer**; the HUD shows no countdown.
2. Levels `numero ≥ 10` (non-bonus) run a countdown from `limiteTiempo`; reaching 0 → defeat.
3. Bonus levels (`esBonus`) have **no timer** and produce **no `Puntaje`/`Estrellas`**; the
   victory overlay omits score/stars for them.
4. The rule is data-driven from `DefinicionNivel`; no View branches on level number/type.
5. The GoF session State machine is unchanged — a timeout is an ordinary transition to
   `EstadoDerrota`, not a new state (consistent with ticket 13's note).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_not_start_timer_when_level_numero_below_10` (AC1).
  - `should_start_countdown_when_level_numero_10_or_above` (AC2).
  - `should_transition_to_defeat_when_time_runs_out` (AC2).
  - `should_not_time_or_score_when_level_is_bonus` (AC3).
- `application/calcular_puntuacion_use_case_test.dart` (if not already in ticket 19):
  - `should_skip_scoring_when_level_is_bonus` (AC3).

### 🟢 GREEN
- Drive timer start/skip from `DefinicionNivel` (`numero`/`esBonus`/`limiteTiempo`); wire
  timeout to `EstadoDerrota`; suppress score/stars on bonus.

### ♻️ REFACTOR
- Centralize the rule (`esCronometrado(definicion)`) so the boundary (9 vs 10) lives in one
  place shared in spirit with backend ticket 15.

## Definition of Done
- Timer presence matches the rule table (boundary-tested at 9/10); bonus levels untimed.
- Bonus levels produce no score/stars; timeout → defeat with no new State.
- No View branches on number/type; `flutter analyze` clean, suite green.
