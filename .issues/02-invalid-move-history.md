# 02 · Invalid Move (penalized) + CommandHistory

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** A2 (invalid move, penalized, board unchanged)
- **Blocked by:** 01
- **Unblocks:** 09 (undo)
- **Traceability:** PRD §11 (A2) · tests §7.2

## User Story

> *As a player, when I tap an arrow whose path is blocked, I want clear, fair
> feedback without being able to "cheat" the move count.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F1) | `Tablero.raycast` blocked branch (hits `CeldaPared` **or** another `Flecha`) |
| `application` (DM-F2) | `MoverFlechaUseCase` invalid branch: no board delta, arrow **not** consumed, `movimientos` **still** +1 |
| `application` | `CommandHistory` + `PlayerMoveCommand` (GoF **Command**): valid move pushes a real-delta command, invalid pushes a **no-delta +1** command |
| `presentation` (DM-F8) | `JuegoViewModel` surfaces "invalid tap" feedback flag in `JuegoViewState` (board unchanged) |
| `presentation/views/game` | shake/flash affordance on invalid tap (no board mutation) |

## Acceptance Criteria (PRD §3 A2, §7.2)

1. Ray blocked **by a wall** → board byte-identical, arrow present, `movimientos == 1`.
2. Ray blocked **by another arrow** → same as above (two distinct cases).
3. `ResultadoMovimiento` has **no** board delta on an invalid move.
4. `CommandHistory` holds a **no-delta +1** command after the invalid tap.
5. The arrow is **not** consumed (still a `Flecha` at the same `Posicion`).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/mover_flecha_invalida_test.dart` (fake `Tablero`):
  - `should_keep_board_identical_when_ray_blocked_by_wall` (AC1).
  - `should_keep_board_identical_when_ray_blocked_by_arrow` (AC2).
  - `should_increment_movimientos_when_move_invalid` (AC1/AC2 — the anti-cheat invariant).
  - `should_produce_result_without_board_delta_when_invalid` (AC3).
- `application/command_history_test.dart`:
  - `should_push_no_delta_plus_one_command_when_move_invalid` (AC4).
  - `should_push_real_delta_command_when_move_valid` (regression against ticket 01).
- Assert byte-identity by comparing a serialized board snapshot before/after.

### 🟢 GREEN
- Add the blocked branch to `MoverFlechaUseCase`: detect block via `raycast`, skip mutation, still `movimientos += 1`, emit a `ResultadoMovimiento` with empty delta, push `PlayerMoveCommand` (no-delta) to `CommandHistory`.

### ♻️ REFACTOR
- Unify valid/invalid into one `ResultadoMovimiento` shape with an optional delta so callers branch on data, not type.
- Ensure `CommandHistory` push happens for **both** outcomes (sets up clean undo in ticket 09).

## Definition of Done
- Both block cases green; `movimientos` increments on invalid taps; history records a no-delta command; board provably unchanged.
