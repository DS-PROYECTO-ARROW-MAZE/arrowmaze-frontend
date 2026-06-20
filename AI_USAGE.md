# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** ArrowMaze Frontend · **Last updated:** 2026-06-19 (T-002 appended)

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| Claude Code | Opus 4.8 / claude-opus-4-8 | Test-first implementation (domain + application + presentation), refactoring, coverage |

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

### T-002 — Ticket 02 · Invalid Move (penalized) + CommandHistory

- **Task / problem addressed:** Implement Story A2 from
  `.issues/02-invalid-move-history.md`: tapping an arrow whose head ray is blocked
  (by a `CeldaPared` **or** another `Flecha`) is a *penalized invalid move* —
  `movimientos` still increments (anti-cheat), the board stays byte-identical, the
  arrow is not consumed, and the move is recorded in history. Unify valid/invalid
  outcomes into one `ResultadoMovimiento` and introduce the GoF **Command** pattern
  (`PlayerMoveCommand` + `CommandHistory`) to set up undo (ticket 09).
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (paraphrased) "implement ticket
  `.issues/02-invalid-move-history.md` applying the `tdd-strict` and
  `clean-architecture` skills (red → green → refactor)."
- **Result obtained:** Strict TDD producing: `application/use_cases/`
  (`CommandHistory` + `PlayerMoveCommand`, `DeltaTablero`, reworked
  `ResultadoMovimiento` with an optional `DeltaTablero`, invalid branch in
  `MoverFlechaUseCase`, extended `EventoJuego`/`TipoEvento`); `presentation/`
  (`JuegoViewState.movimientoInvalido` flag, `JuegoViewModel` wiring, a
  theme-driven shake/flash in `GameView` that does **not** mutate the board); and
  new tests `command_history_test.dart`, `mover_flecha_invalida_test.dart`,
  `juego_viewmodel_invalido_test.dart` (plus trimming of
  `mover_flecha_guardas_test.dart`). Verified: `flutter test` 38/38 green; the
  invalid branch leaves a byte-identical board snapshot; both valid and invalid
  moves push a command to `CommandHistory`; zero `package:flutter` imports under
  `domain/`+`application/`.
- **Modifications made by the team:** Review only — the team reviewed the tests and
  code; no manual code edits were required. `flutter test`/`flutter analyze` served
  as the guardrails.
- **Lessons learned / limitations identified:** The refactor step (unifying
  valid/invalid into a single `ResultadoMovimiento` with an optional delta so
  callers branch on data, not type) confirmed that designing the result shape for
  the *next* ticket (undo) up front keeps the Command/History wiring clean. The
  detailed AC-to-test mapping in the issue gave the AI unambiguous red-phase targets,
  so no rework was needed.

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** ~90%
- **Basis for the estimate:** All `lib/` and `test/` files in tickets 01 and 02
  were AI-generated then human-reviewed; the theme tokens under `lib/core/theme`
  were pre-existing (not AI-authored in these tasks). Ticket 02 followed the same
  pattern (full AI authoring + human review), so the share holds at ~90%. Rough
  judgment over the files added across both slices.

### Incorrect or suboptimal AI results

- **Case:** `const Posicion.en(...)` initializer built a non-constant `Vector3`,
  so the code would not compile.
  - **How it was detected:** `flutter test` compile error.
  - **How it was corrected:** Stored `fila`/`columna` as fields and exposed
    `coordenada` as a getter.
- **Case:** `GameView` used a `dynamic` callback parameter, violating the project's
  "no `dynamic`" rule.
  - **How it was detected:** Self-review against `CLAUDE.md`.
  - **How it was corrected:** Typed the callback as `void Function(Posicion)`.
- **Case:** The first test set left several domain/application files below the 90%
  coverage gate (~72–87%).
  - **How it was detected:** `flutter test --coverage` + per-file line-coverage
    calculation.
  - **How it was corrected:** Added value-object, factory, and use-case guard
    tests, reaching 100%.

### Team reflection

- **Impact on productivity:** Very high — the slice came together fast because the
  groundwork was already in place: the predefined Clean Architecture / MVVM folder
  structure, the agents, the skills (`tdd-strict`, `clean-architecture`), and the
  detailed issue tickets gave the AI clear, unambiguous rails to follow.
- **Impact on code quality:** The enforced TDD cycle plus the architecture and
  naming constraints (`CONTEXT.md`) kept the output consistent and well-tested
  (100% coverage on touched domain/application files), with the few AI mistakes
  caught immediately by the test/analyze/coverage tooling.
- **Overall takeaways:** Investing up front in structure, skills, and well-scoped
  issues pays off directly in AI speed and reliability — the clearer the rails,
  the less rework. Keep that setup for the remaining tickets.
