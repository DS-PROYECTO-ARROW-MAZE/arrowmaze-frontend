# feat(frontend): render & generate dynamic board shapes + arrow-length-≥2 invariant

- **Phase:** 5 — enhancement
- **Stories:** C1/C2 (extension of level generation/rendering)
- **Blocked by:** 01 (core mechanic), 05 (level generation/solvability)
- **Cross-repo twin:** `arrowmaze-backend` ticket 14 — shared golden boards must agree.
- **Traceability:** PRD §3 (C1–C2) · CLAUDE.md "Formato JSON de niveles" · DR §11 (FRONTEND-04)

> Boards are no longer restricted to filled `rows × cols` rectangles. A level may take a
> **shape** — heart, triangle, star, etc. — by marking grid positions as *absent* (not part
> of the playable region), so the cell count and arrangement vary per level. The board model,
> the renderer, the solver and the random generator must all treat absent positions as
> non-existent, and **no generated or loaded board may contain a single-cell arrow — the
> minimum arrow path length is always 2 cells.**

## User Story

> *As a player, levels come in varied shapes (not just rectangles), and every arrow I see
> always spans at least two cells — never a degenerate one-cell move.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F1) | `Tablero`/`GrafoTablero` distinguishes **absent** positions from `EmptyCell` (present-but-transparent); raycast/edge detection skip absent positions |
| `domain` | board JSON schema gains an absent/mask concept (positions with no cell are absent); `Solver.esSolvable` operates over the masked region only |
| `domain`/`application` (DM-F4) | new invariant: an arrow whose ray resolves to length 1 is **invalid** — `GeneradorNivelBase`/`poblar()` never emits one; loader validation rejects one |
| `presentation` (DM-F8) | `CeldaUI`/board render draws only playable cells; absent positions are blank (no grid cell, no hit-test) |
| `assets` | shaped sample levels (e.g. `level_heart.json`, `level_triangle.json`) |

## Acceptance Criteria (PRD §3, §7.4)

1. A board can be non-rectangular: positions marked absent are not rendered, not traversed,
   and not hit-testable; an `EmptyCell` (transparent, pass-through) remains distinct.
2. The solver gives correct verdicts on **shaped golden boards** shared with backend
   ticket 14 (solvable → true, unsolvable → false), order-independently.
3. No board — generated or loaded — contains a length-1 arrow; generation that would
   produce one **fails** (never renders), and the loader **rejects** such a board.
4. Complexity (cells/arrows) still scales as configured (ties into ticket 17).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/solver_test.dart`:
  - `should_skip_absent_positions_during_raycast` (absent ≠ EmptyCell).
  - `should_match_shaped_golden_boards` (shared fixtures w/ backend).
- `domain/tablero_test.dart`:
  - `should_treat_absent_position_as_non_existent_when_celdaEn` /
    `should_not_hit_test_absent_position`.
- `application/generador_nivel_base_test.dart`:
  - `should_fail_generation_when_arrow_length_is_one` (AC3 — inject a `poblar()` that emits
    a length-1 arrow; assert it never renders).
- `application/generacion_por_archivo_test.dart`:
  - `should_reject_loaded_board_with_length_one_arrow` (AC3).

### 🟢 GREEN
- Add the absent/mask concept to the board model + JSON schema; make raycast/edge detection
  mask-aware; enforce the minimum-arrow-length invariant in the template `validarSolvencia`
  step (or a sibling structural validation step); render only playable cells.

### ♻️ REFACTOR
- Keep "absent" a single named concept (not scattered null checks); express minimum length
  as a named constant shared with the backend fixtures' expectations.

## Definition of Done
- Shaped boards render and play correctly; absent vs empty are distinct in the model.
- Solver agrees with backend on shaped golden boards.
- No length-1 arrow can be generated or loaded; `flutter analyze` clean, suite green.
