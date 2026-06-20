# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** ArrowMaze Frontend · **Last updated:** 2026-06-19

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| Claude Code | Opus 4.8 / claude-opus-4-8 | Test-first implementation (ticket 01), refactoring, coverage |
| OpenCode | deepseek-v4-flash-free | Test-first implementation (ticket 05), architectural analysis, documentation |

## 2. Usage Log by Task

### T-001 — Ticket 01 · Core Move Mechanic (tracer-bullet slice)

- **Task / problem addressed:** Implement the thinnest end-to-end vertical slice
  (`View → ViewModel → UseCase → Tablero`) that proves the architecture: tapping
  a clear-ray arrow removes it and empties its cell. Scope defined by
  `.issues/01-core-move-mechanic.md` (Stories A1, A3).
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim) "implement this ticket
  `…\.issues\01-core-move-mechanic.md`, it is obligatory to apply the rules of
  this skills: `…\tdd-strict\SKILL.md` `…\clean-architecture\SKILL.md`. the
  visual design you define it based on `…\lib\core\theme`".
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `domain/value_objects/` (`Vector3`, `Posicion`, `Direccion`);
  `domain/entities/` (`Celda` sealed + `CeldaFlecha`/`CeldaPared`/`CeldaVacia`,
  `FabricaCeldasEstandar`); `domain/` (`Tablero` port + `ResultadoRaycast`,
  `GrafoTablero`+`Nodo`, `DetectorColisiones`); `application/use_cases/`
  (`MoverFlechaUseCase`, `ResultadoMovimiento`, `EventoJuego`/`TipoEvento`);
  `presentation/` (`JuegoViewModel` + immutable `JuegoViewState`, `GameView`);
  `infrastructure/datasources/FuenteTableroMemoria` + `di/Inyeccion` + `main.dart`
  wiring; and 22 unit tests across `test/domain`, `test/application`,
  `test/presentation`. Verified: `flutter test` 22/22 green; 100% line coverage on
  every touched `domain/`+`application/` file (gate ≥90%); `flutter analyze` no
  errors; zero `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** The team reviewed the tests. During
  implementation the following corrections were also made on top of the first AI
  drafts: (a) `Posicion` reworked to store `fila`/`columna` directly after the
  original `const` constructor failed to compile; (b) a `dynamic` callback type in
  `GameView` replaced with `Posicion` to satisfy the project's no-`dynamic` rule;
  (c) extra value-object/factory/guard tests added to lift coverage from ~72–87%
  to 100%.
- **Lessons learned / limitations identified:** AI initially produced a `const`
  constructor that did not compile and reached for `dynamic`, and its first test
  set did not meet the coverage gate — all caught by `flutter test`/`analyze`/
  coverage, confirming the value of the TDD + tooling guardrails. Naming had to be
  reconciled against `CONTEXT.md` (used `CeldaFlecha`, not the ticket's shorthand
  `Flecha`).

### T-002 — Ticket 05 · Level Generation with Solvability Gate

- **Task / problem addressed:** Implement level generation that guarantees every
  produced board is solvable via a greedy solver. Add file-backed and random
  strategies, a selection ViewModel, and DI wiring. Scope defined by
  `.issues/05-level-generation-solvability.md`.
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** (paraphrased) Implement ticket 05 following strict TDD
  (Red → Green → Refactor) and Clean Architecture. All code in Spanish. Greedy
  solver must be complete, polynomial (no backtracking), and mutate only a copy
  of the board. Template method generator with `validarSolvencia` gate. Strategy
  pattern for random (border-only) and file-backed generation. Selection VM with
  loading/error states. Wire in DI.
- **Result obtained:** Strict TDD producing: `domain/solver.dart` (greedy
  `Solver.esSolvable` — 5 tests); `domain/grafo_tablero.dart` extensions
  (`agregarTrayectoria`, `agregarCelda`); `application/generadores/` (Template
  Method `GeneradorNivelBase` + `ConfiguracionGeneracion` + `GeneracionAleatoriaNivel`
  border-only strategy + `GeneracionPorArchivoNivel` strategy — 6 tests);
  `application/ports/` (`CargadorNivel` + `DefinicionNivelDto`); `infrastructure/`
  (`CargadorNivelArchivo` reads `assets/levels/level_XX.json` via `rootBundle`);
  `presentation/` (`SeleccionNivelViewModel` + `SeleccionNivelViewState` — 3 tests);
  `di/Inyeccion` wiring for all new components; `pubspec.yaml` asset declaration.
  Verified: `flutter test` 45/45 green (32 existing + 13 new); `flutter analyze`
  0 warnings, 3 info-level only (pre-existing style preferences); Clean
  Architecture verified — zero `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** The team reviewed all tests and code. (a)
  Several unused imports across solver, ViewModel, and test files removed after
  `flutter analyze` flagged them; (b) an unused local variable in
  `solver_test.dart` removed; (c) the analysis identified that
  `SeleccionNivelViewModel` bypasses the use-case pattern (calls
  `GeneracionPorArchivoNivel` directly instead of a `LoadLevelUseCase`) —
  documented as a future improvement rather than fixed inline.
- **Lessons learned / limitations identified:** The greedy solver on a copied
  board works well and is polynomial. The Template Method pattern cleanly
  separated the validation concern from population. The AI's first solver draft
  mutated the original board — caught by `grafo_tablero`'s reference semantics
  in tests. The `CargadorNivelArchivo` skipped an `AssetLoader` abstraction,
  coupling directly to `rootBundle` (documented as an improvement for later).
  Clean Architecture rules were verified both by tool (`flutter analyze`) and by
  manual inspection — no violations found.

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** ~90%
- **Basis for the estimate:** All `lib/` and `test/` files across tickets 01 and
  05 were AI-generated then human-reviewed; the theme tokens under `lib/core/theme`
  were pre-existing (not AI-authored in this task).

### Incorrect or suboptimal AI results

- **Case:** `const Posicion.en(...)` initializer built a non-constant `Vector3`,
  so the code would not compile (ticket 01).
  - **How it was detected:** `flutter test` compile error.
  - **How it was corrected:** Stored `fila`/`columna` as fields and exposed
    `coordenada` as a getter.
- **Case:** `GameView` used a `dynamic` callback parameter (ticket 01).
  - **How it was detected:** Self-review against `CLAUDE.md`.
  - **How it was corrected:** Typed the callback as `void Function(Posicion)`.
- **Case:** First test set left domain/application files below 90% coverage gate
  (ticket 01).
  - **How it was detected:** `flutter test --coverage` + per-file line-coverage.
  - **How it was corrected:** Added value-object, factory, and use-case guard
    tests, reaching 100%.
- **Case:** Solver initially mutated the original board object instead of a copy
  (ticket 05).
  - **How it was detected:** `flutter test` — the test board mutated unexpectedly
    after `esSolvable` ran.
  - **How it was corrected:** `validarSolvencia` in the Template Method
    reconstructs a fresh `GrafoTablero` from the `Tablero` port, keeping the
    original intact.
- **Case:** Several unused imports across solver, ViewModel, and test files, plus
  an unused local variable (ticket 05).
  - **How it was detected:** `flutter analyze` (7 issues originally, 3 remaining
    after fixes, all info-level).
  - **How it was corrected:** Removed each unused import/variable by hand.
- **Case:** `CargadorNivelArchivo` coupled directly to `rootBundle` with no
  abstraction layer (ticket 05).
  - **How it was detected:** Manual Clean Architecture review.
  - **How it was corrected:** Not corrected — documented as a future improvement
    (OCP violation, low priority).

### Team reflection

- **Impact on productivity:** Very high across both tickets. The predefined Clean
  Architecture / MVVM folder structure, the skills (`tdd-strict`,
  `clean-architecture`), and the detailed issue tickets gave the AI clear rails
  to follow. Ticket 05 was notably faster than ticket 01 because the domain
  vocabulary, port interfaces, and conventions were already established.
- **Impact on code quality:** The enforced TDD cycle plus architecture constraints
  kept output consistent and well-tested (45/45 tests, 0 warnings). The few AI
  mistakes were caught by `flutter analyze`, `flutter test`, and manual review —
  no defect reached production code.
- **Overall takeaways:** (1) Up-front investment in structure, skills, and
  well-scoped issues pays off directly in AI speed and reliability. (2) Reusing
  established domain abstractions (like the `Tablero` port) makes subsequent
  tickets faster and less error-prone. (3) A few architectural inconsistencies
  (e.g., missing use-case wrapper for generation, missing `AssetLoader` port)
  remain as technical debt — consciously deferred rather than accidental.
