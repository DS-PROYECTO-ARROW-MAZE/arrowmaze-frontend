# 05 · Level Generation + Solvability Gate

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** C1 (random solvable level), C2 (load level by id)
- **Blocked by:** 01
- **Unblocks:** 12 (decorator stack wraps these use cases)
- **Traceability:** PRD §11 (C1–C2) · tests §7.4

> **Scope:** C3 (backend author-gate, `DM-B1/DM-B2`) is **out of scope** in this repo.
> The client re-validates solvability as defense-in-depth before render.

## User Story

> *As a player offline, I want a fresh level that is always winnable, and I want
> to load a specific authored level — both validated for solvability before render,
> regardless of source.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain` (DM-F4) | `Solver.esSolvable(Tablero) → bool` — greedy loop (remove any arrow with a clear ray until empty; solvable iff board empties) |
| `domain`/`application` (DM-F3) | `GeneradorNivelBase.generar(config)` (**Template Method**, `final`): `crearTableroVacío() → poblar() → validarSolvencia() → entregar()`; only `poblar()` overridable. Strategies: `GeneracionAleatoriaNivel`, `GeneracionPorArchivoNivel` (GoF **Strategy**) |
| `application` (DM-F9) | `CargadorNivel.cargar(String ruta) → Future<DefinicionNivelDto>` **port** |
| `infrastructure` | `CargadorNivelArchivo` (assets/levels/level_XX.json) — HTTP loader stubbed for ticket 10 |
| `presentation` | `SeleccionNivelViewModel` + `SeleccionNivelViewState`; render only validated boards |
| `di` | inject loader port + strategies into the VM |

## Acceptance Criteria (PRD §3 C1–C2, §7.4)

1. `GeneradorNivelBase.generar` **always** runs `validarSolvencia`; it **cannot be bypassed** — an injected unsolvable `poblar()` makes generation **fail**, never render.
2. Solver is **order-independent**: identical verdict across shuffled removal orders.
3. Greedy completeness: known-solvable golden boards → `true`; known-unsolvable → `false`.
4. `GeneracionPorArchivoNivel` validates for solvability **before render**, regardless of source (asset or backend).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/solver_test.dart`:
  - `should_return_true_for_known_solvable_golden_board` / `should_return_false_for_known_unsolvable_golden_board` (AC3 — load shared golden fixtures).
  - `should_return_same_verdict_across_shuffled_removal_orders` (AC2 — property test).
- `application/generador_nivel_base_test.dart`:
  - `should_fail_generation_when_poblar_yields_unsolvable_board` (AC1 — inject a malicious `poblar()`; assert it never returns a renderable level).
  - `should_call_validarSolvencia_before_entregar` (assert template order via spy).
- `application/generacion_por_archivo_test.dart` (fake `CargadorNivel`):
  - `should_validate_solvability_before_render_when_loading_by_id` (AC4).

### 🟢 GREEN
- Implement greedy `Solver`. Implement `GeneradorNivelBase` with the fixed skeleton and a single `poblar()` hook. Implement `CargadorNivelArchivo` reading JSON via the schema in PRD §3 / CLAUDE.md.

### ♻️ REFACTOR
- Make `validarSolvencia` a **structural** step in the template (not a caller responsibility) — solvability-before-render is a guarantee, not a convention.
- Place golden fixtures where backend CI can share them (ADR-0001 cross-repo agreement).

## Definition of Done
- Solver order-independent + complete on golden boards; generation provably cannot emit an unsolvable level; load-by-id validated before render.
