# feat(frontend): endless in-app level generation + aggressive difficulty scaling

- **Phase:** 6 — enhancement (gameplay / progression)
- **Stories:** C1 (random solvable level — extension), Progression (ties into ticket 13/17)
- **Blocked by:** 05 (level-generation/solvability), 16 (shaped boards), 17 (level catalog)
- **Cross-repo note:** difficulty is **data** (`PerfilDificultad`), aligned in spirit with
  backend tickets 14/16 (geometry + catalog). No app-store update is required to add difficulty.
- **Traceability:** PRD §3 (C1), §1.3 (Goals: solvable-by-construction), §8 (offline-first)

> Beyond the authored catalog (ticket 17), the app must **generate fresh, always-solvable
> levels on the fly**, indefinitely, so difficulty can keep climbing **without shipping a new
> build**. Three requirements combine here: (a) **endless generation** — once a player clears the
> authored catalog, the app keeps producing new playable levels procedurally; (b) **aggressive
> difficulty scaling** — the difficulty curve is **steep**: grids grow large, arrow counts grow
> heavy, and the move budget tightens toward the late game, so the final levels are genuinely
> complex; (c) **shape rotation** — generated levels are **never square-only**: a fixed, ordered
> repertoire of predefined shape masks (`Cuadrado`, `Corazón`, `Triángulo`, `Cruz`, `Estrella`)
> is applied to each board, selected **deterministically by rotating on the level index**. Generation
> always passes `validarSolvencia` before render (no soft-locks, ever).
>
> **Shape and difficulty are orthogonal axes.** The shape is chosen by rotating the repertoire by
> index; the difficulty (grid size, arrow count, move budget) is chosen independently by
> `PerfilDificultad`. Shapes therefore **repeat** as the player advances (e.g. 1→Cuadrado,
> 2→Corazón, 3→Triángulo, 4→Cruz, 5→Estrella, 6→Cuadrado…), but each recurrence of a shape sits at
> **strictly higher complexity** — the difficulty keeps climbing *inside* the shape.

## User Story

> *As a player who finishes the built-in levels, I keep getting new, harder levels forever — and
> they come in real shapes (hearts, triangles, crosses, stars), cycling as I go, each return of a
> shape bigger and packed with more arrows than the last — and every one is still winnable.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` | `PerfilDificultad` — value object mapping a level index/`numero` → **difficulty** parameters (board size, arrow count/density, max path length, **move budget** — FE-30); a **steep, monotonic** curve expressed as data, not branches, with a **hard minimum board size of 7×7 at the lowest index** (no level is ever smaller — accommodates every shape mask and raises baseline load). **Orthogonal to shape** (next row) |
| `domain` | `RepertorioFormas` + `MascaraForma` — a **fixed, ordered** repertoire of predefined shape masks (`Cuadrado`, `Corazón`, `Triángulo`, `Cruz`, `Estrella`) plus a **deterministic selector** `formaParaIndice(numero)` that **rotates** through the repertoire by index (wraps after its length). Reuses FE-16's *absent-position* mask concept: the `MascaraForma` defines the playable region the generator may populate; positions outside it stay *absent* |
| `application`/`domain` (DM-F3/DM-F4) | `GeneracionAleatoriaNivel.poblar()` consumes **both** `PerfilDificultad` (how hard) **and** the `MascaraForma` from `RepertorioFormas.formaParaIndice(numero)` (what shape); it populates **only in-mask (playable) positions**, then the `GeneradorNivelBase` template runs `validarSolvencia` (cannot be bypassed) and the arrow-length ≥ 2 invariant (ticket 16) on the masked board |
| `application` | `CatalogoNiveles` (ticket 13/17) extended so that **past the last authored level** it yields procedurally-generated `DefinicionNivel`s on demand (endless tail) |
| `presentation` (DM-F8) | Level Select shows the authored catalog plus an "endless"/progressive continuation; `JuegoViewModel` plays generated levels identically to authored ones |

## Acceptance Criteria (PRD §3, §7.4, §12 req 2/3)

1. **Endless:** after the last authored level, requesting the next level returns a freshly
   generated, **solvable** `DefinicionNivel` — generation never returns an unsolvable board, and
   the supply is unbounded (no fixed cap).
2. **Steep scaling with a raised floor:** `PerfilDificultad` is **monotonic and aggressive** — board
   size, arrow count, and **move budget** (FE-30) increase strictly with level index; late indices
   yield **large grids with a high arrow count** (boundary-tested: index N+k is meaningfully
   larger/denser than index N). The **minimum board size is 7×7 even at the lowest index** — no
   generated level is ever smaller than 7×7 (so shape masks render legibly and the baseline is
   non-trivial).
3. **Shape rotation (never square-only):** every generated level applies a predefined shape mask
   selected **deterministically** by rotating through the **fixed, ordered** repertoire
   `[Cuadrado, Corazón, Triángulo, Cruz, Estrella]` keyed on the level index — e.g. 1→Cuadrado,
   2→Corazón, 3→Triángulo, 4→Cruz, 5→Estrella, 6→Cuadrado (wraps). The generator **must not** emit
   only squares: over any window of ≥ repertoire-length consecutive indices, **every** shape in the
   repertoire appears exactly per the rotation.
4. **Shape ⟂ difficulty (orthogonal axes):** shape comes solely from
   `RepertorioFormas.formaParaIndice(numero)` and difficulty solely from `PerfilDificultad(numero)`;
   the two are independent. The **same shape recurs** as the index grows, but each recurrence is at
   **strictly higher complexity** (larger grid / more arrows / larger move budget) — complexity
   scales *inside* the shape, never by swapping the shape. (Boundary-tested: for indices `i` and
   `i + repertoireLength` — same shape — the later board is strictly larger/denser.)
5. **In-mask population & invariants:** the generator populates **only playable (in-mask)
   positions** — *absent* positions stay absent, reusing FE-16's concept with **no UI- or
   generator-side re-derivation of geometry**; the resulting shaped board passes `validarSolvencia`
   before render (DM-F3 template, un-bypassable) and contains **no length-1 arrow** (ticket 16).
6. Generation is **offline-first**: no network is required (PRD §8); no app-store update is
   needed to reach higher difficulty **or new shapes**.
7. Both axes are **data-driven**: the difficulty curve lives in `PerfilDificultad` and the shape
   order in `RepertorioFormas`; **no** View or use case branches on a hard-coded level number for
   either difficulty or shape.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/perfil_dificultad_test.dart`:
  - `should_increase_grid_size_and_arrow_count_monotonically_when_index_grows` (AC2).
  - `should_never_yield_board_smaller_than_7x7_for_any_index` (AC2 — hard minimum floor at index 1).
  - `should_increase_move_budget_monotonically_when_index_grows` (AC2 — move budget axis).
  - `should_yield_large_dense_board_when_index_is_late` (AC2 — assert thresholds for a high index).
- `domain/repertorio_formas_test.dart`:
  - `should_rotate_through_shapes_in_fixed_order_when_index_advances` (AC3 — 1→Cuadrado … 5→Estrella).
  - `should_wrap_to_first_shape_after_repertoire_length` (AC3 — index 6 → Cuadrado).
  - `should_yield_every_shape_over_a_full_cycle` (AC3 — never square-only).
- `application/generacion_aleatoria_nivel_test.dart`:
  - `should_produce_solvable_board_for_any_index` (AC1/AC5 — property over many indices, now shaped).
  - `should_apply_selected_shape_mask_and_populate_only_playable_cells` (AC5 — absent stays absent;
    no arrow placed outside the mask).
  - `should_recur_same_shape_at_strictly_higher_complexity_when_index_wraps` (AC4 — indices `i` and
    `i + repertoireLength` share a shape but the later board is strictly larger/denser).
  - `should_fail_generation_when_candidate_unsolvable` (AC5 — invariant still un-bypassable).
- `application/catalogo_niveles_test.dart`:
  - `should_yield_generated_level_when_index_past_last_authored` (AC1 — endless tail).

### 🟢 GREEN
- Implement `PerfilDificultad` as a steep curve in data **and** `RepertorioFormas` as a fixed,
  ordered, index-rotating shape selector; feed **both** the selected `MascaraForma` and the profile
  into `poblar()` (populate in-mask only); extend `CatalogoNiveles` to generate beyond the authored
  manifest; keep the template `validarSolvencia`/arrow-length gate intact.

### ♻️ REFACTOR
- Keep difficulty (`PerfilDificultad`) and shape (`RepertorioFormas`) as **two separate, tunable
  data objects** — the slope and the shape order are retuned independently, in one place each.
  Ensure generation remains a Strategy under `GeneradorNivelBase` (no new branches in callers); keep
  *absent* a single concept threaded from FE-16 (no scattered geometry re-derivation).

## Definition of Done
- The game never "runs out" of levels; the post-catalog supply is solvable and unbounded.
- Difficulty climbs steeply (size + arrow count + move budget) per a single data-driven
  `PerfilDificultad`.
- Generated levels **cycle through the predefined shapes** (`Cuadrado`/`Corazón`/`Triángulo`/`Cruz`/
  `Estrella`) deterministically by index — **never square-only** — via a single data-driven
  `RepertorioFormas`; shape and difficulty are independent, and a recurring shape returns at strictly
  higher complexity.
- All generated boards populate only in-mask cells and pass solvability + arrow-length invariants;
  `flutter analyze` clean, full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **Clean Architecture / MVVM**
(CLAUDE.md): generation lives in `domain`/`application` (no Flutter import); the solvability gate
is structural, never a caller responsibility (DM-F3). Use the **ubiquitous language** (PRD §4);
**no** `NivelFacil/Medio/Dificil` subtypes — difficulty is data, and **shape is data too**
(`RepertorioFormas`), never a `switch`/`if` on the shape name in callers.
