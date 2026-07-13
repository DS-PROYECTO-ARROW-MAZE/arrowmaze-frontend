# feat(frontend): playable 3D boards (depth axis, layer rendering & controls)

- **Phase:** 8 — enhancement
- **Stories:** C1/C2 (extension of level generation/rendering), A1–A3 (move mechanic — proven
  unchanged)
- **Blocked by:** 01 (core mechanic), 16 (dynamic board shapes — mask/length-invariant
  machinery this extends), 26 (render irregular board shapes — painter split this extends
  per layer)
- **Cross-repo twin:** `arrowmaze-backend` ticket 19 — shared golden fixtures must agree
  (differ in shape between repos; see fixtures section — only the minimal-smoke-test and
  unsolvable boards are structurally identical).
- **Traceability:** PRD §1.1 ("a future 3D board"), §4 (Posicion/Vector3/Direccion —
  "2D = 4 dirs, future 3D = 6, same contract"), §6.1 DM-F1, §8 NFR Portability/Extensibility

> The PRD has promised since inception that a 3D board is "a new `Tablero` implementation
> with 6-direction `Vector3` — zero caller changes" (§6.1 DM-F1). `Vector3` already carries a
> dormant `z`, but `Posicion` (`fila`/`columna` only), `Direccion` (4 cardinals) and
> `GrafoTablero` (2D neighbour wiring) are still 2D-only, and there is no way to render or
> interact with more than one layer. This ticket makes the depth axis real end to end — model,
> loading, and **playable UI** — while proving the PRD's OCP claim: `MoverFlechaUseCase`
> (DM-F2) and `Solver` (DM-F4) require **zero** code changes, because both already depend only
> on the `Tablero` port and a `Direccion`, never on a fixed direction count.

## User Story

> *As a player, some levels are stacked in layers — a path can bend not just around the
> board's rows and columns but up/down through the stack — and I can see and play every
> layer: switch which layer I'm looking at, tap any visible segment of a path (on any layer)
> to resolve it, and clear a fully 3D board exactly like a flat one.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F1) | `Posicion` gains `capa` (`int`, default `0` — every existing call site stays valid); `Direccion` gains `adelante`/`atras` (+z/−z), extending `cardinales` (4) to a 6-direction set; `GrafoTablero.desde` gains `profundo` (default `1`) and links neighbours across all six directions (no dimension branching — a layer-1 board simply has no depth neighbours to link) |
| `domain` (DM-F4) | **No changes.** `Solver.esSolvable` and `DetectorColisiones` already depend only on `Tablero.raycast`/`Direccion` — this ticket adds a regression test proving the existing solver suite passes unmodified against a 3D `GrafoTablero` fixture |
| `application` (DM-F2) | **No changes.** `MoverFlechaUseCase` depends only on the `Tablero` port — regression test proves the existing move-mechanic suite passes unmodified against a 3D fixture |
| `application`/`infrastructure` (DM-F3/F9) | level JSON schema gains `layers` (top-level, default `1`) and `layer` (per cell, default `0`); `CargadorNivelArchivo`/`FabricaCeldasEstandar` read/produce `capa`; new direction strings `FORWARD`/`BACKWARD` map to `Direccion.adelante`/`Direccion.atras` |
| `presentation` (DM-F8) | `JuegoViewState`/`TableroUI`/`CeldaUI` gain the active `capa` and `profundo`; the `CustomPainter` renders **one layer at a time**, reusing the existing playable/absent/empty rules unmodified per layer; a new **layer switcher** control changes the active layer without losing board/session state; hit-testing scopes taps to the active layer's cells only |
| `presentation` | path-following exit animation (ticket 22): a path whose head resolves on a different layer than the tapped segment simply completes without an on-screen glide across the hidden layer (fade/pop), since only one layer's geometry is ever visible at once |

## Acceptance Criteria (PRD §1.1, §3 A1–A3/C1–C2, §8)

1. A level JSON with `layers > 1` loads and passes `validarSolvencia` **before** render, exactly
   like a 2D board — an unsolvable 3D board is never shown (regression of C1/C2 onto the new
   axis).
2. The board renders **one active layer** at a time, using the existing continuous-path /
   arrowhead / empty-dot / absent rules unchanged (PRD §1.4, ticket 26) — no new painter rules
   for a single layer's content.
3. A **layer switcher** (e.g. prev/next control) changes which layer is visible without
   resetting `movimientos`, the timer, or any session state; the currently visible layer is
   always a valid index in `[0, profundo)`.
4. **Tap-any-segment-any-layer:** tapping any visible `CeldaFlecha` segment resolves its whole
   `Trayectoria`, even when the path's head sits on a different layer than the one currently
   shown — the existing "tap any order/any segment" rule (A3) applies unchanged across layers,
   because resolution is driven by the tapped segment's `idFlecha`, not its layer.
5. A resolving path removes every segment on every layer it occupies in one atomic move,
   exactly like a same-layer path (whole-path exit, A1); segments on a non-visible layer
   disappear from that layer's own render the next time it becomes active.
6. Undo, pause/resume, scoring, stars, and victory/defeat all work unchanged on a 3D board —
   these are regression assertions, not new behaviour (they depend on `EstadoSesion`/
   `CalcularPuntuacionUseCase`, neither of which touches board geometry).
7. The three bundled 3D test boards (see fixtures below) load, pass the solvability gate
   (or are correctly rejected, for the intentionally-unsolvable one), and are playable
   end-to-end via the layer switcher.

## Strict TDD instructions (red → green → refactor)

### Step 1 — Depth-aware domain (🔴 → 🟢 → ♻️)
- 🔴 `domain/posicion_test.dart` / `domain/direccion_test.dart`: `should_default_capa_to_zero`,
  `should_step_capa_by_one_when_desplazar_adelante_or_atras`,
  `should_expose_six_directions_when_profundo_greater_than_one`.
- 🔴 `domain/grafo_tablero_3d_test.dart`: build a `GrafoTablero.desde(profundo: 2, ...)` fixture
  and assert cross-layer neighbour links exist both ways; a `profundo: 1` board (every
  existing 2D test) links **zero** depth neighbours (regression — no behaviour change for 2D).
- 🔴 `domain/solver_3d_test.dart`: the three golden 3D boards (below) give the correct verdict;
  **run the existing `solver_test.dart` suite unmodified against a `profundo: 2` fixture** to
  assert zero solver code changes were needed.
- 🔴 `application/mover_flecha_usecase_3d_test.dart`: **run the existing
  `mover_flecha_usecase_test.dart` suite unmodified against a `profundo: 2` fixture** — same
  zero-caller-change assertion for DM-F2.
- 🟢 Add `capa`/`adelante`/`atras`/`profundo` with defaults; extend `GrafoTablero.desde`'s
  neighbour-linking loop to all six directions (single loop, no branch on dimension).
- ♻️ Confirm no existing 2D domain/application test needed a code change to pass — that is the
  acceptance bar for the OCP claim, not just a nice-to-have.

### Step 2 — Level loading (🔴 → 🟢 → ♻️)
- 🔴 `infrastructure/cargador_nivel_archivo_3d_test.dart`:
  `should_read_layers_and_per_cell_layer_field`,
  `should_default_layers_to_one_when_absent` (backward compatibility with every existing
  `level_XX.json`), `should_map_forward_and_backward_direction_strings_to_adelante_atras`.
- 🔴 `application/generacion_por_archivo_test.dart`: a loaded 3D board still runs
  `validarSolvencia` through the unmodified `GeneradorNivelBase` template before it's handed
  to the ViewModel (AC1).
- 🟢 Wire `layers`/`layer` through the DTO → `FabricaCeldasEstandar` → `GrafoTablero.desde`.
- ♻️ `FORWARD`/`BACKWARD` join `UP`/`DOWN`/`LEFT`/`RIGHT` in one direction-string lookup table,
  not a second parallel `switch`.

### Step 3 — Presentation: layer rendering, switcher, cross-layer taps (🔴 → 🟢 → ♻️)
- 🔴 `presentation/juego_viewmodel_3d_test.dart`:
  `should_expose_active_layer_and_profundo_in_view_state`,
  `should_render_only_active_layer_cells`,
  `should_change_active_layer_without_resetting_movimientos_or_timer` (AC3),
  `should_resolve_owning_path_when_tapped_segment_is_on_active_layer_even_if_head_is_not`
  (AC4).
- 🔴 `presentation/hit_test_3d_test.dart`: a tap outside the active layer's playable region
  (including positions that only exist on other layers) is a no-op, mirroring ticket 26's
  absent-tap rule.
- 🟢 Add the layer switcher widget/control; scope the `CustomPainter` and hit-testing to
  `TableroUI`'s active-layer slice; map `capa` through `CeldaUI` unchanged from the existing
  per-cell fields otherwise.
- ♻️ The painter stays a pure consumer of one layer's `TableroUI` slice — it must not know
  `profundo` exists; layer selection is entirely a ViewModel/ViewState concern.

## Golden 3D fixtures (bundled test boards)

> Placed at `assets/levels/level_3d_test_01.json` / `_02.json` / `_03.json` (ids `9001`–`9003`,
> outside the real 1–15 catalog range and the endless-generation id space, so they are never
> served by `CatalogoNiveles`/`CargadorNivel` unless loaded explicitly by path — e.g. from a
> debug/QA entry point added during this ticket). They are the Dart-model equivalent of
> `arrowmaze-backend` ticket 19's three fixtures; only #1 (minimal) and #3 (unsolvable) are
> structurally identical across repos, since only the frontend's `Trayectoria` supports
> multi-segment bending paths.

1. **`level_3d_test_01` — minimal depth smoke test** (1×1 footprint, 2 layers). A single
   2-segment arrow (tail on layer 0, head on layer 1, direction `FORWARD`) exits the stack
   immediately. Smallest possible board that exercises the depth axis at all.
2. **`level_3d_test_02` — cross-layer bending path** (1×2 footprint, 2 layers). A 3-segment
   path bends once in-plane (column 0 → column 1 on layer 0) and once through depth (column 1,
   layer 0 → column 1, layer 1), head on layer 1 pointing `FORWARD`. Demonstrates a
   `Trayectoria` whose orthogonal adjacency now spans layers, not just rows/columns.
3. **`level_3d_test_03` — mutual cross-layer block (unsolvable)** (1×2 footprint, 3 layers).
   Two 2-segment arrows on opposite ends of a 3-layer stack point at each other through the
   middle layer and block each other forever. Used to prove the solvability gate correctly
   **rejects** a bad 3D board (never renders it) — this board is not meant to be played.

## Definition of Done
- `Posicion`/`Direccion`/`GrafoTablero` are depth-aware; `MoverFlechaUseCase` and `Solver`
  pass their existing suites **unmodified** against a 3D fixture (the OCP proof, not just an
  assertion in prose).
- 3D levels load, solvability-gate correctly (including rejecting the intentionally-unsolvable
  fixture), render one layer at a time with the layer switcher, and are fully playable —
  tap-any-segment-any-layer, whole-path cross-layer exit, undo/pause/scoring/victory all work
  unchanged.
- The three bundled 3D test boards are present under `assets/levels/` and covered by the test
  suites above; `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **MVVM + Clean Architecture**
(CLAUDE.md): the painter/hit-testing only ever consumes what the ViewModel maps from the
domain — no geometry re-derivation in `presentation`. Use the **ubiquitous language** (PRD §4);
new terms (`capa`, `profundo`, `adelante`, `atras`) follow the existing Spanish domain-naming
convention exactly like `fila`/`columna`/`arriba`/`abajo`.
