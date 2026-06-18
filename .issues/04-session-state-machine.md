# 04 · Session State Machine (win / lose / pause)

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** B1 (victory), B2 (defeat, timed only), B3 (pause/resume)
- **Blocked by:** 01
- **Unblocks:** 09 (undo), 10 (sync)
- **Traceability:** PRD §11 (B1–B3) · tests §7.3

## User Story

> *As a player, I win when the board is empty; on a timed level I lose if time
> runs out; and I can pause and resume without the timer advancing.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F5) | `EstadoSesion` (GoF **State**): `EstadoJugando/Pausado/Victoria/Derrota`; `SesionJuego` delegates `tocarCelda`, `pausar`, `reanudar`, `cambiarEstado`, `estaTerminada` |
| `domain` | `Victoria` event on emptied board; defeat only when `limiteTiempo` hits 0 |
| `application` | `MoverFlechaUseCase` routes taps through the active `EstadoSesion`; victory check after a valid exit |
| `presentation` (DM-F8) | `JuegoViewModel` maps session state → `JuegoViewState`; **separate** `VictoriaViewState` (UI) — NOT `EstadoVictoria` |
| `presentation/views` | wire `victory/`, `defeat/`, pause overlay |

## Acceptance Criteria (PRD §3 B1–B3, §7.3)

1. Last arrow exits → transition to `EstadoVictoria`; `Victoria` event fires; final `Puntaje`/`Estrellas` computed (scoring trigger; integrates with ticket 06).
2. Timed level: timer reaches 0 before clear → `EstadoDerrota`.
3. **Untimed level can never enter `EstadoDerrota`** (property/negative test).
4. `EstadoPausado`: taps are **rejected**; timer **frozen**; resume returns to `EstadoJugando`.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/estado_sesion_test.dart`:
  - `should_transition_to_EstadoVictoria_when_last_arrow_exits` (AC1).
  - `should_transition_to_EstadoDerrota_when_timer_reaches_zero_on_timed_level` (AC2).
  - `should_never_reach_EstadoDerrota_when_level_is_untimed` (AC3 — property test over arbitrary move/time sequences).
  - `should_reject_tap_when_EstadoPausado` (AC4).
  - `should_freeze_timer_while_paused_and_resume_to_EstadoJugando` (AC4).
- `presentation/juego_viewmodel_session_test.dart`:
  - `should_expose_VictoriaViewState_distinct_from_EstadoVictoria` (naming guardrail).

### 🟢 GREEN
- Implement the four `EstadoSesion` subclasses; `tocarCelda` legal only in `EstadoJugando`. `SesionJuego.cambiarEstado` swaps state. Freeze the injected clock/timer in `EstadoPausado`.

### ♻️ REFACTOR
- Encode tap legality by **type** (state class), not scattered `if`s.
- Keep `EstadoSesion` (domain) and `*ViewState` (presentation) strictly separate — no leakage either direction.

## Definition of Done
- All four AC green incl. the untimed-never-loses property test; pause freezes the clock; VM exposes a UI victory snapshot distinct from the domain state.
