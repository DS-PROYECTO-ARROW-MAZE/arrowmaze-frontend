# feat(frontend): render irregular board shapes in the Flutter UI

- **Phase:** 6 — enhancement (UI rendering)
- **Stories:** C2 (load/render level — visual completion)
- **Blocked by:** 16 (dynamic board shapes — model/solver/mask)
- **Cross-repo note:** the **backend already serves non-square / shaped layouts** (backend
  ticket 14 — sparse `CeldaNivel`, mask derived on load); this ticket completes the **client
  rendering** of those shapes.
- **Traceability:** PRD §1.4 (visual & interaction model) · §3 (C2) · CLAUDE.md MVVM (`CustomPainter`)

> Ticket 16 introduced the **absent-position** concept in the model/solver. This ticket ensures
> the Flutter UI **renders irregular shapes correctly**: a heart, triangle, star, or any
> non-rectangular mask served by the backend must draw only its playable region, with paths,
> arrowheads, and empty-dots laid out faithfully and centered — and **absent** positions drawn as
> nothing (no tile, no dot, no hit-test), distinct from a transparent `EmptyCell`.

## User Story

> *As a player, levels come in real shapes — hearts, triangles, stars — and they look right:
> only the shape is drawn, paths bend within it, and the area outside the shape is simply not
> there.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `presentation` (DM-F8) | `JuegoViewModel`/`JuegoViewState` maps the masked board → `TableroUI`/`CeldaUI` carrying which positions are **playable vs absent**; layout/centering accounts for a non-rectangular bounding box |
| `infrastructure/ui` | the `CustomPainter` draws **only** playable cells (continuous bending paths + single arrowhead + dots for `EmptyCell`); **absent** positions paint nothing and are excluded from hit-testing |
| `presentation` | tap hit-testing maps a touch point to a playable cell only; taps on absent regions are ignored |

## Acceptance Criteria (PRD §1.4, §3 C2)

1. A non-rectangular board served by the backend (sparse mask) renders **only its playable
   region**; absent positions are blank — no background tile, no dot, no hit-test target.
2. **Absent ≠ empty:** an `EmptyCell` (transparent, pass-through) still renders its subtle dot;
   an absent position renders nothing. The two are visibly and behaviourally distinct.
3. Continuous bending paths, the single arrowhead, and empty-dots all draw correctly **within the
   shape**, including paths that bend around absent positions; the board is centered/scaled to fit.
4. Tapping inside the shape resolves the owning path; tapping an absent region is a no-op.
5. Rendering matches the model from ticket 16 (no UI-side re-derivation of which cells exist) and
   stays within the frame budget (PRD §8).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `presentation/juego_viewmodel_test.dart`:
  - `should_mark_absent_positions_as_non_playable_in_view_state` (AC1/AC2 — `CeldaUI` flags
    playable vs absent from the masked board).
  - `should_distinguish_absent_from_empty_cell_in_view_state` (AC2).
- `presentation/hit_test_test.dart` (or board-mapping unit):
  - `should_ignore_tap_on_absent_position` (AC4).
  - `should_resolve_owning_path_when_tap_inside_shape` (AC4).

### 🟢 GREEN
- Map the masked board into `TableroUI`/`CeldaUI`; make the `CustomPainter` skip absent positions
  for both paint and hit-test; center/scale to the shape's bounding box.

### ♻️ REFACTOR
- Keep "absent" a single named concept threaded from the model (no scattered null checks in the
  painter); keep the painter a pure consumer of `TableroUI`.

## Definition of Done
- Irregular shapes render faithfully (only the playable region; absent = nothing; empty = dot).
- Taps on absent regions are ignored; paths/arrowheads/dots draw correctly within bends.
- UI consumes ticket 16's masked model without re-deriving geometry; `flutter analyze` clean,
  suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️; test behaviour/state mapping, not
painter pixels). **MVVM + Clean Architecture** (CLAUDE.md): geometry comes from the
`domain` model via the ViewModel; the View/painter only draws. No discrete background tiles
(PRD §1.4). Use the **ubiquitous language** (PRD §4).
