# feat(frontend): endless in-app level generation + aggressive difficulty scaling

- **Phase:** 6 — enhancement (gameplay / progression)
- **Stories:** C1 (random solvable level — extension), Progression (ties into ticket 13/17)
- **Blocked by:** 05 (level-generation/solvability), 16 (shaped boards), 17 (level catalog)
- **Cross-repo note:** difficulty is **data** (`PerfilDificultad`), aligned in spirit with
  backend tickets 14/16 (geometry + catalog). No app-store update is required to add difficulty.
- **Traceability:** PRD §3 (C1), §1.3 (Goals: solvable-by-construction), §8 (offline-first)

> Beyond the authored catalog (ticket 17), the app must **generate fresh, always-solvable
> levels on the fly**, indefinitely, so difficulty can keep climbing **without shipping a new
> build**. Two requirements combine here: (a) **endless generation** — once a player clears the
> authored catalog, the app keeps producing new playable levels procedurally; (b) **aggressive
> difficulty scaling** — the difficulty curve is **steep**: grids grow large and arrow counts
> grow heavy toward the late game, so the final levels are genuinely complex. Generation always
> passes `validarSolvencia` before render (no soft-locks, ever).

## User Story

> *As a player who finishes the built-in levels, I keep getting new, harder levels forever —
> bigger boards packed with many more arrows — and every one is still winnable.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` | `PerfilDificultad` — value object mapping a level index/`numero` → generation parameters (board size, arrow count/density, max path length, shape pool); a **steep, monotonic** curve expressed as data, not branches |
| `application`/`domain` (DM-F3/DM-F4) | `GeneracionAleatoriaNivel.poblar()` consumes `PerfilDificultad`; the `GeneradorNivelBase` template still runs `validarSolvencia` (cannot be bypassed) and the arrow-length ≥ 2 invariant (ticket 16) |
| `application` | `CatalogoNiveles` (ticket 13/17) extended so that **past the last authored level** it yields procedurally-generated `DefinicionNivel`s on demand (endless tail) |
| `presentation` (DM-F8) | Level Select shows the authored catalog plus an "endless"/progressive continuation; `JuegoViewModel` plays generated levels identically to authored ones |

## Acceptance Criteria (PRD §3, §7.4)

1. **Endless:** after the last authored level, requesting the next level returns a freshly
   generated, **solvable** `DefinicionNivel` — generation never returns an unsolvable board, and
   the supply is unbounded (no fixed cap).
2. **Steep scaling:** `PerfilDificultad` is **monotonic and aggressive** — both board size and
   arrow count increase strictly with level index; late indices yield **large grids with a high
   arrow count** (boundary-tested: index N+k is meaningfully larger/denser than index N).
3. Generation is **offline-first**: no network is required (PRD §8); no app-store update is
   needed to reach higher difficulty.
4. Every generated board honours existing invariants: `validarSolvencia` passes before render
   (DM-F3 template, un-bypassable) and no length-1 arrow exists (ticket 16).
5. Difficulty is **data-driven**: the curve lives in `PerfilDificultad`; no View or use case
   branches on a hard-coded level number for difficulty.

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/perfil_dificultad_test.dart`:
  - `should_increase_grid_size_and_arrow_count_monotonically_when_index_grows` (AC2).
  - `should_yield_large_dense_board_when_index_is_late` (AC2 — assert thresholds for a high index).
- `application/generacion_aleatoria_nivel_test.dart`:
  - `should_produce_solvable_board_for_any_difficulty_index` (AC1/AC4 — property over many indices).
  - `should_fail_generation_when_candidate_unsolvable` (AC4 — invariant still un-bypassable).
- `application/catalogo_niveles_test.dart`:
  - `should_yield_generated_level_when_index_past_last_authored` (AC1 — endless tail).

### 🟢 GREEN
- Implement `PerfilDificultad` as a steep curve in data; feed it into `poblar()`; extend
  `CatalogoNiveles` to generate beyond the authored manifest; keep the template gate intact.

### ♻️ REFACTOR
- Keep the curve a single tunable data object (one place to retune the slope); ensure generation
  remains a Strategy under `GeneradorNivelBase` (no new branches in callers).

## Definition of Done
- The game never "runs out" of levels; the post-catalog supply is solvable and unbounded.
- Difficulty climbs steeply (size + arrow count) per a single data-driven `PerfilDificultad`.
- All generated boards pass solvability + arrow-length invariants; `flutter analyze` clean,
  full suite green.

---
**Working agreement (mandatory):** strict **TDD** (🔴→🟢→♻️). **Clean Architecture / MVVM**
(CLAUDE.md): generation lives in `domain`/`application` (no Flutter import); the solvability gate
is structural, never a caller responsibility (DM-F3). Use the **ubiquitous language** (PRD §4);
**no** `NivelFacil/Medio/Dificil` subtypes — difficulty is data.
