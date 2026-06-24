# feat(frontend): retrofit shape-mask rotation + raised 7×7 grid floor onto the 15 authored catalog levels

- **Phase:** 6 — enhancement (content / generation tooling)
- **Stories:** C1/C2 (authored content — shape retrofit), Progression (ties into tickets 13/17/23)
- **Blocked by:** 16 (shaped board model/mask), 23 (`RepertorioFormas` + `MascaraForma` + rotation
  rule), 26 (irregular-shape rendering)
- **Why a new ticket:** tickets **17** (authored catalog) and **BE 16** (catalog seed) are already
  **done** and cannot be edited. They shipped the 15 bundled boards as (effectively) rectangular
  grids. This ticket retrofits the **same shape rotation** the endless generator uses (ticket 23)
  onto the authored levels so the rotation **starts at Level 1** and is **continuous** into the
  procedurally-generated tail.
- **Cross-repo note:** boards are **frontend assets** (architecture decision 2026-06-22 — backend is
  source of truth for level *identity*/UUID only; its seeded boards are trivial single-cell grids
  that are **never rendered**). Therefore this retrofit is **frontend-only** — **no backend twin**.
- **Traceability:** PRD §12 req 2/3 (generation + shape rotation) · §1.4 rule 7 (irregular shapes) ·
  CLAUDE.md "Formato JSON de niveles"

> Ticket 23 introduces `RepertorioFormas.formaParaIndice(numero)` — a deterministic rotation through
> the fixed, ordered shape repertoire `[Cuadrado, Corazón, Triángulo, Cruz, Estrella]`. The endless
> generator applies it to levels **past** the authored catalog. This ticket applies the **identical**
> repertoire and rotation to the **authored** levels 1–15, regenerating
> `assets/levels/level_01.json … level_15.json` via `tool/generar_niveles.dart` so each authored
> board carries its rotation-assigned shape mask. **In the same regeneration, the difficulty bands
> are raised to the new 7×7 floor** (PRD §12 req 2, 2026-06-24): levels **1–5 → 7×7**, **6–10 → 8×8**,
> **11–15 → 9×9** (up from the old 5×5/6×6/7×7) — small grids could not render hearts/stars legibly
> and made early levels trivially easy. Size and shape remain **orthogonal** axes (ticket 23): the
> band sets the grid, the rotation sets the shape mask applied within it.

## User Story

> *As a player starting at Level 1, the very first levels already come in real shapes — square, then
> heart, triangle, cross, star — and the same shapes keep cycling as I move from the built-in levels
> into the endless ones, with no sudden change of look at the hand-off.*

## Deep Modules / artifacts touched (vertical slice)

| Layer | Module / file |
|---|---|
| `tool` (offline content generation) | `tool/generar_niveles.dart` consumes `RepertorioFormas.formaParaIndice(numero)` (ticket 23) and passes the selected `MascaraForma` into the seeded `GeneracionAleatoriaNivel(semilla:)` so the generated board is **masked to the shape** before serialization; keeps per-level seeding (reproducible) and applies the **raised difficulty bands** (1–5 → 7×7, 6–10 → 8×8, 11–15 → 9×9 — min 7×7 floor, PRD §12 req 2) in place of the old 5×5/6×6/7×7 |
| `assets` | regenerated `assets/levels/level_01.json … level_15.json` — each now a shaped (masked) board; *absent* positions are simply **omitted** from `cells` (sparse), consistent with the FE-16/FE-26 *absent* concept (no filler cells) |
| `domain`/`application` | **no rule change** — reuses `RepertorioFormas`/`MascaraForma` (ticket 23), the `validarSolvencia` gate and arrow-length ≥ 2 invariant (ticket 16); `CatalogoNivelesArchivo` loads the regenerated assets unchanged |

## Acceptance Criteria

1. **Rotation starts at Level 1:** the regenerated authored levels follow
   `RepertorioFormas.formaParaIndice(numero)` exactly — level 1 → `Cuadrado`, 2 → `Corazón`,
   3 → `Triángulo`, 4 → `Cruz`, 5 → `Estrella`, 6 → `Cuadrado` … through level 15 — the **same**
   repertoire/order ticket 23 uses (no second source of truth).
2. **Continuous hand-off:** the shape assigned to the last authored level and the first generated
   level follow one unbroken rotation by index — there is **no shape discontinuity** between the
   authored catalog and the endless tail (ticket 23).
3. **Raised grid floor + shape ⟂ difficulty:** the difficulty bands are regenerated at the **new
   7×7 minimum floor** (PRD §12 req 2) — levels **1–5 → 7×7**, **6–10 → 8×8**, **11–15 → 9×9** (up
   from 5×5/6×6/7×7); **no authored level is smaller than 7×7**. Size (band) and shape (rotation)
   stay independent axes — the band sets the grid, the mask is applied within it. The trajectory-count
   window still rejects the generator's degenerate 2-trajectory fallback.
4. **Invariants hold:** every regenerated board still passes `validarSolvencia` and contains no
   length-1 arrow; *absent* positions are omitted from `cells` (sparse) and render as nothing
   (FE-26) — distinct from a transparent `EmptyCell`.
5. **Reproducible & offline:** regeneration is deterministic (per-level `semilla:` retained), runs
   fully offline via `dart run tool/generar_niveles.dart`, and the resulting assets load through the
   existing `CatalogoNivelesArchivo` fallback **without** any change to ticket 17's catalog/unlock
   code or the backend.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `tool` / `application` level-generation test (e.g. `generacion_niveles_tool_test.dart` or extend
  the generator suite):
  - `should_assign_shape_by_rotation_for_each_authored_numero` (AC1 — numero→shape matches
    `RepertorioFormas`).
  - `should_apply_raised_difficulty_bands_with_7x7_floor` (AC3 — 1–5 → 7×7, 6–10 → 8×8, 11–15 → 9×9;
    no level smaller than 7×7).
  - `should_produce_solvable_masked_board_with_no_length_1_arrow_for_each_authored_level`
    (AC4 — invariants over all 15).
  - `should_omit_absent_positions_from_serialized_cells` (AC4 — sparse JSON, no filler).
- `infrastructure/catalogo_niveles_archivo_test.dart` (reuse existing): the regenerated shaped
  assets still load into `ResumenNivel`/`DefinicionNivel` without crashing (AC5).

### 🟢 GREEN
- Wire `RepertorioFormas.formaParaIndice(numero)` (ticket 23) into `tool/generar_niveles.dart`; mask
  the seeded board before serialization; regenerate the 15 assets; serialize absent positions as
  omitted rows.

### ♻️ REFACTOR
- The tool must **consume** ticket 23's `RepertorioFormas` (single source of truth for shape order) —
  do **not** duplicate the repertoire in the tool. Keep masking a single step layered on top of the
  seeded generation; the raised band sizes are a single tunable (one place to retune the 7×7 floor).

## Definition of Done
- `assets/levels/level_01.json … level_15.json` are regenerated as shaped boards whose shapes follow
  the ticket-23 rotation starting at Level 1, continuous into the endless tail.
- Difficulty bands raised to the 7×7 floor (1–5 → 7×7, 6–10 → 8×8, 11–15 → 9×9; none smaller than
  7×7); all 15 boards solvable, arrow-length ≥ 2, sparse (absent omitted).
- Tool reuses `RepertorioFormas` (no duplicated shape list); ticket 17 catalog/unlock code and the
  backend are untouched; `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **Clean Architecture / MVVM**
(CLAUDE.md): shape repertoire/masking lives in `domain` (ticket 23), the tool only orchestrates;
no Flutter import in domain/application. Use the **ubiquitous language** (PRD §4); shape is **data**
(`RepertorioFormas`), never a `switch`/`if` on the shape name. **Reuse** ticket 23's repertoire —
this ticket adds **content**, not a second rotation rule.
