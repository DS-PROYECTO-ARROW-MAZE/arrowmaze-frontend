# 09 · Undo (valid or invalid move)

- **Phase:** 3 — DOWNSTREAM
- **Stories:** B4 (undo)
- **Blocked by:** 02 (CommandHistory + no-delta command), 04 (session legality)
- **Unblocks:** —
- **Traceability:** PRD §11 (B4) · tests §7.3

## User Story

> *As a player, I can undo my last move — valid or invalid — and all counters stay
> consistent.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `application` | `DeshacerMovimientoUseCase` consuming `CommandHistory`; `PlayerMoveCommand.deshacer()` (GoF **Command** undo) |
| `domain` (DM-F1) | `Tablero` re-link of an arrow `Nodo` when reversing a real-delta command (incremental, mirror of removal) |
| `domain` (DM-F5) | undo legal only in non-terminal `EstadoSesion` |
| `presentation` (DM-F8) | undo button → VM → use case; `JuegoViewState` reflects reversal |

## Acceptance Criteria (PRD §3 B4, §7.3)

1. Undo of a **valid** move reverses the board delta (arrow restored at its `Posicion`).
2. Undo of an **invalid** move rolls back the **no-delta +1**.
3. `movimientos` decrements; all counters stay consistent.
4. Undoing past an empty history is a safe no-op.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `application/deshacer_movimiento_use_case_test.dart`:
  - `should_restore_arrow_and_decrement_movimientos_when_undo_valid_move` (AC1, AC3).
  - `should_rollback_no_delta_plus_one_when_undo_invalid_move` (AC2, AC3).
  - `should_be_noop_when_history_empty` (AC4).
- `domain/tablero_relink_test.dart`:
  - `should_relink_node_incrementally_when_arrow_restored` (mirror of ticket 01's unlink test).

### 🟢 GREEN
- Implement `deshacer()` on both command variants; pop from `CommandHistory`; decrement `movimientos`; re-link node for real-delta undo.

### ♻️ REFACTOR
- Ensure undo and redo share the same `ResultadoMovimiento`-shaped reversal so counters can't drift.

## Definition of Done
- Both undo paths green; counters consistent; empty-history no-op safe; board re-link is incremental.
