# feat(frontend): smooth path-following (snake-like) arrow exit animation

- **Phase:** 6 — enhancement (UX / animation)
- **Stories:** A1 (valid move — visual refinement)
- **Blocked by:** 01 (core-move-mechanic), 16 (board shapes / path geometry)
- **Traceability:** PRD §1.4 (visual & interaction model) · §3 A1 · CLAUDE.md MVVM/Patterns
- **Strictly presentation-only:** the domain already resolves a move atomically; this ticket
  changes only how that resolution is **drawn over time**. No rule, solver, or scoring change.

> When a `Trayectoria` resolves, it must **animate out of the board like a snake moving
> forward** — the head travels along the path's own multi-cell trajectory toward the exit
> edge, and every tail segment **follows the exact same curve, cell by cell**, until the whole
> path has left the board. It must **not** be a rigid translation of the entire shape sliding
> off-screen as one block. Bends in the path must be followed faithfully (the tail turns where
> the head turned). The animation is purely visual: the domain already removed the path the
> instant the tap was valid; the View plays the exit afterwards, then settles to the empty
> (dots) state.

## User Story

> *As a player, when an arrow exits I see it glide smoothly forward along its own winding path
> — head first, the body trailing through every curve — like a snake leaving the board, not a
> stiff block sliding away.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F1) | `Trayectoria` already exposes ordered segment positions + head/corner geometry — **read-only** here (the per-segment ordered path and its extension to the edge) |
| `presentation` (DM-F8) | `JuegoViewModel`/`JuegoViewState` carries a transient `AnimacionSalida` descriptor (the ordered path of exiting cells + the edge target) emitted on a valid `FlechaEliminada`, then cleared |
| `infrastructure/ui` | a Flutter `AnimationController` per exiting path tweens a normalized progress `t`; the `CustomPainter` samples the polyline (cell centers → edge) so head and each tail segment are offset along the **same** curve by a fixed arc-length spacing |
| `core` | a small path-sampling helper (arc-length parametrization of a bending polyline) — pure Dart, no business logic |

## Acceptance Criteria

1. On a valid exit, the path's **head** advances along its own trajectory to the board edge and
   off-board; each **tail segment follows the identical polyline** (including 90° bends), spaced
   one cell behind the segment ahead — a snake gait, never a rigid whole-shape slide.
2. The motion is driven by a Flutter `AnimationController` tweening segments along the
   established path (arc-length parametrized), not by translating a single rigid bitmap/shape.
3. The animation is **decoupled from the rule**: the domain still resolves the move atomically
   and `movimientos`/victory are unaffected by animation timing; if the animation is disabled or
   skipped the final board state is identical (empty cells / dots).
4. Performance: the exit animation holds the frame budget (≤ 16 ms/frame target, PRD §8) for the
   longest authored path; concurrent exits do not stutter.
5. Works on **shaped** boards (ticket 16): the path may bend around absent positions and still
   animates cleanly to the correct edge.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_emit_exit_animation_descriptor_with_ordered_path_when_move_valid` (AC1/AC3 — the VM
    exposes the ordered exiting-cell polyline + edge target on `FlechaEliminada`, then clears it).
  - `should_not_emit_exit_descriptor_when_move_invalid` (AC3).
- `core/path_sampling_test.dart`:
  - `should_place_tail_segments_one_cell_behind_head_along_curve_when_sampled_at_t` (AC1/AC2 —
    arc-length sampling keeps inter-segment spacing constant through bends).
  - `should_reach_edge_target_when_t_equals_one` (AC1).

### 🟢 GREEN
- Add the transient `AnimacionSalida` descriptor to `JuegoViewState`; implement the pure
  arc-length path sampler in `core`; drive it from an `AnimationController` in the board widget;
  have the `CustomPainter` render head + offset tail segments from sampled points.

### ♻️ REFACTOR
- Keep the sampler pure and reusable; keep the painter dumb (consumes sampled points only);
  ensure the descriptor is cleared so a finished animation never leaks into later frames.

## Definition of Done
- Arrows exit with a smooth, path-following snake gait through every bend; no rigid block slide.
- Animation is controller-driven and fully decoupled from the rule (skippable → identical end
  state); holds the frame budget; works on shaped boards.
- `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️; test behaviour, not
implementation). **MVVM + Clean Architecture** (CLAUDE.md): the View never calls a use case
directly — animation state flows View ← ViewModel; `domain`/`application` import **no Flutter**.
Use the **ubiquitous language** (`Trayectoria`, `FlechaEliminada`, PRD §4).
