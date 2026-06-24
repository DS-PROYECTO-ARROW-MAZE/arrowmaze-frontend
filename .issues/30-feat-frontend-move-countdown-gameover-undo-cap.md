# feat(frontend): move countdown + Game Over condition, and 3-use undo cap

- **Phase:** 6 — enhancement (gameplay rules)
- **Stories:** B2 (defeat — new trigger), B4 (undo — capped)
- **Blocked by:** 01 (core-move-mechanic), 04 (session-state-machine), 09 (undo), 13 (meta-game)
- **Traceability:** PRD §3 (B2, B4) · §7.3 · CLAUDE.md State machine (`GameOverState`),
  Command (`PlayerMoveCommand`)

> Two coupled gameplay-limit rules:
>
> **(A) Move countdown & Game Over.** The move counter must **count down**, not up. Each level
> starts with a **move budget** = `total de flechas + margen de error` (allowed error margin).
> Every tap (valid **or** invalid — consistent with A2) **decrements** the budget. If the budget
> reaches **0 before the board is cleared**, the session transitions to **Game Over (defeat)**.
>
> **(B) Undo cap.** **Undo** is limited to a strict **maximum of 3 uses per level** (no longer
> unlimited). After 3 undos the control is disabled until the level restarts.

> **⚠️ Deliberate invariant change (record in PRD).** Until now, defeat existed **only** on
> timed levels (PRD §3 B2, §7.3: "an untimed level can never reach `EstadoDerrota`"). The move
> budget introduces a **second, timer-independent defeat trigger**, so an **untimed** level
> **can** now end in `EstadoDerrota` via move exhaustion. The old test/assertion must be updated,
> not worked around. This is intentional — see PRD §12.

## User Story

> *As a player, each level gives me a limited number of moves shown counting down; if I run out
> before clearing the board I get a Game Over. I can undo, but only up to 3 times per level.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` | move-budget value (`presupuestoMovimientos = nFlechas + margen`) on `DefinicionNivel`/session; budget decrements on every recorded move; reaching 0 pre-victory → defeat |
| `domain` (DM-F5) | `EstadoSesion`/`GameOverState`: move-exhaustion is an ordinary transition to `EstadoDerrota` (no brand-new state — like timeout in ticket 18) |
| `application` | `DeshacerMovimientoUseCase` (ticket 09) gains a **per-level undo counter** capped at 3; undo also **restores** one unit of move budget consistent with the move it reverses |
| `presentation` (DM-F8) | `JuegoViewModel`/`JuegoViewState` exposes remaining moves (countdown) + remaining undos; HUD shows both; undo control disables at 0 remaining; Game Over overlay (Retry / Level Select) |

## Acceptance Criteria (PRD §3 B2/B4, §7.3)

1. **Countdown:** a level starts with `presupuesto = nFlechas + margen`; the HUD shows it
   counting **down**; each tap (valid or invalid) decrements it by 1.
2. **Game Over:** if the budget hits 0 while the board is non-empty, the session transitions to
   `EstadoDerrota` and a Game Over overlay appears (Retry / Level Select); clearing the board on
   the **last** allowed move is a **victory**, not a defeat (victory check wins ties).
3. **Untimed defeat now possible:** an untimed level can reach `EstadoDerrota` via move
   exhaustion (the prior "untimed never loses" assertion is updated — see PRD §12).
4. **Undo cap:** undo works at most **3 times per level**; the 4th attempt is a no-op and the
   control is disabled; the counter **resets** on level restart/new level.
5. **Undo consistency:** an undo reverses the move (board delta or no-delta +1, ticket 09) **and**
   gives back the corresponding move-budget unit, so counters never drift; undo is unavailable in
   terminal states (`EstadoVictoria`/`EstadoDerrota`).
6. The budget/Game-Over rule is **data-driven** (margin is data on the level); no View branches on
   level number; the GoF State machine gains no ad-hoc state beyond the existing `EstadoDerrota`.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/presupuesto_movimientos_test.dart`:
  - `should_decrement_budget_on_valid_and_invalid_move` (AC1).
  - `should_transition_to_derrota_when_budget_hits_zero_before_clear` (AC2).
  - `should_win_when_board_cleared_on_last_allowed_move` (AC2 — victory beats defeat on a tie).
  - `should_allow_derrota_on_untimed_level_via_move_exhaustion` (AC3 — **replaces** the old
    "untimed never loses" test).
- `application/deshacer_movimiento_use_case_test.dart`:
  - `should_block_fourth_undo_in_a_level` (AC4).
  - `should_restore_one_budget_unit_when_undo` (AC5).
  - `should_reset_undo_count_on_new_level` (AC4).
- `presentation/juego_viewmodel_test.dart`:
  - `should_expose_remaining_moves_and_undos_and_disable_undo_at_zero` (AC1/AC4).

### 🟢 GREEN
- Add `presupuestoMovimientos` to the level/session; decrement on every recorded move; wire
  budget-zero → `EstadoDerrota`; cap undo at 3 with per-level reset; restore budget on undo; HUD +
  Game Over overlay.

### ♻️ REFACTOR
- Express the margin and the undo cap (3) as named constants/data; keep victory-wins-tie logic in
  one place; keep Game Over an ordinary `EstadoDerrota` transition (no new State).

## Definition of Done
- Moves count **down** from `nFlechas + margen`; budget exhaustion → Game Over (untimed included);
  clearing on the last move is a win.
- Undo capped at 3/level with per-level reset; undo restores budget; counters never drift.
- PRD §12 records the deliberate "untimed can now lose" invariant change; the superseded §7.3
  assertion is updated. `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️; the invariant-change test
**replaces** the old one — do not leave both). **MVVM + Clean Architecture** (CLAUDE.md): rules
live in `domain`/`application` (no Flutter import); the View only renders counters/overlays via
the ViewModel. Game Over reuses the GoF **State** `EstadoDerrota` (no ad-hoc state). Ubiquitous
language per PRD §4.
