# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** ArrowMaze Frontend · **Last updated:** 2026-06-20 (T-006 appended)

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| Claude Code | Opus 4.8 / claude-opus-4-8 | Test-first implementation (tickets 01, 02, 03, 04), refactoring, coverage |
| Claude Code | Sonnet 4.6 / claude-sonnet-4-6 | Test-first implementation (ticket 07), Observer pattern wiring, DI |
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
### T-003 — Ticket 02 · Invalid Move (penalized) + CommandHistory

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

### T-004 — Ticket 04 · Session State Machine (win / lose / pause)

- **Task / problem addressed:** Implement Stories B1–B3 from
  `.issues/04-session-state-machine.md`: the player wins when the board is empty,
  loses on a timed level when the clock reaches 0 (untimed levels can *never*
  lose), and can pause/resume without the timer advancing. Model the session
  lifecycle with the GoF **State** pattern so tap/clock legality is encoded by
  state type rather than scattered `if`s.
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (paraphrased) "Implement ticket 04 applying the
  `tdd-strict` and `clean-architecture` skills (red → green → refactor)."
- **Result obtained:** Strict TDD producing: `domain/sesion/`
  (`EstadoSesion` GoF State base + `EstadoJugando`/`EstadoPausado`/`EstadoVictoria`/
  `EstadoDerrota`, `SesionJuego` context delegating `tocarCelda`/`pausar`/
  `reanudar`/`cambiarEstado`/`estaTerminada`, `ResultadoToque`); `domain`
  (`Tablero.estaVacio` victory query + `GrafoTablero` support); `application`
  (`MoverFlechaUseCase` routes taps through the active session and emits a
  `victoria` event when the last arrow empties the board, plus an extended
  `EventoJuego`/`TipoEvento`); `presentation` (`JuegoViewModel` maps session
  state onto UI snapshots, adds a separate `VictoriaViewState` distinct from the
  domain `EstadoVictoria`, pause/resume, and a timed-level clock; `GameView`
  victory/defeat/pause overlays wired with theme tokens). Tests: 5 in
  `test/domain/estado_sesion_test.dart` (incl. the AC3 *untimed-never-loses*
  property test) + 1 ViewModel guardrail in
  `test/presentation/juego_viewmodel_session_test.dart` asserting
  `VictoriaViewState` is not `EstadoVictoria`. Verified: `flutter test` 58/58
  green; `flutter analyze` 0 errors / 0 warnings (3 info-level
  `prefer_initializing_formals` hints, pre-existing style preference); zero
  `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** Review only — the team reviewed the tests
  and code; no manual code edits were required. `flutter test`/`flutter analyze`
  served as the guardrails.
- **Lessons learned / limitations identified:** Encoding tap/clock legality by
  state *type* (the GoF State subclasses) instead of conditional branches kept
  `MoverFlechaUseCase` and the ViewModel free of mode-checking `if`s, and made the
  "untimed level can never lose" guarantee expressible as a property test rather
  than a defensive runtime check. Keeping the domain `EstadoVictoria` strictly
  separate from the presentation `VictoriaViewState` (enforced by a naming
  guardrail test) prevented state leakage across the layer boundary. The detailed
  AC-to-test mapping in the issue again gave unambiguous red-phase targets, so no
  rework was needed.

### T-005 — Ticket 03 · Collectible Pass-through (bonus time)

- **Task / problem addressed:** Implement Story A4 from
  `.issues/03-collectible-passthrough.md`: a 4th `Celda` kind, `Coleccionable`,
  that is **transparent** to a ray (never blocks a move) and, when a *valid*
  move's ray crosses it, is collected by pass-through — emitting a
  `ColeccionableRecogido` event and adding seconds to the level timer. Victory
  must stay independent of collectibles (the board can empty regardless).
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim) "implement this ticket
  `…\.issues\03-collectible-passthrough.md` is obligatory to aplly the rules in
  these skills `…\clean-architecture\SKILL.md` `…\tdd-strict\SKILL.md` the visual
  design is up to you based on `…\lib\core\theme`".
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `domain/entities/celda.dart` (new `Coleccionable` sealed kind + a polymorphic
  `esColeccionable` getter alongside `bloqueaRayo`);
  `domain/entities/fabrica_celdas_estandar.dart` (`collectible` Factory product);
  `domain/tablero.dart` (`ResultadoRaycast.coleccionables` + a `recogerColeccionable`
  port method); `domain/detector_colisiones.dart` (the ray walk gathers crossed
  collectibles via the cell property, no type branch); `domain/grafo_tablero.dart`
  (`recogerColeccionable` — collect-once, empties the cell);
  `domain/sesion/` (`EstadoJugando` collects on a valid exit and surfaces it in
  `ResultadoToque.coleccionables`; `SesionJuego.otorgarBonus` extends the clock);
  `application/use_cases/` (`TipoEvento.coleccionableRecogido`; `MoverFlechaUseCase`
  emits one event per collectible and applies `bonusPorColeccionable` = 5 s each);
  `presentation/` (`TipoCeldaUI.coleccionable` + `JuegoViewState.coleccionables`
  HUD tally, `JuegoViewModel` mapping + accumulation, `GameView` glowing-diamond
  painter using the `cellCollectible`/`collectibleGlow` theme tokens and a HUD
  bonus counter). New tests: `test/domain/raycast_collectible_test.dart` (AC1
  transparency + a wall-after-collectible guard), `test/application/mover_flecha_collectible_test.dart`
  (AC2 event+bonus, AC3 victory-without-collecting), `test/presentation/juego_viewmodel_collectible_test.dart`
  (DM-F8 HUD reflects bonus). Verified: `flutter test` 63/63 green (60 prior + 3
  new, plus a pre-existing exhaustive-switch test updated for the new kind);
  `flutter analyze` 0 errors / 0 warnings (same 3 pre-existing info-level
  `prefer_initializing_formals` hints); zero `package:flutter` imports under
  `domain/`+`application/`.
- **Modifications made by the team:** Review only — the team reviewed the tests
  and code; no manual code edits were required. The in-memory demo board
  (`FuenteTableroMemoria`) was intentionally left unchanged, since it is a
  fully-covered grid with a tested "zero empty cells" invariant and has no free
  cell for a collectible; the mechanic is reachable through file-backed levels
  (`type: "collectible"`).
- **Lessons learned / limitations identified:** Modelling "transparency" and
  "collectibility" as polymorphic cell properties (`bloqueaRayo`,
  `esColeccionable`) queried by the raycast walk kept the use case branching on
  **data** (`toque.coleccionables`) rather than on `if (type == …)`, satisfying
  the ticket's OCP refactor note — adding a future cell kind touches only the
  entity. One self-inflicted slip: the AI's first draft of the application test
  contained a broken helper (an undefined `_pathEn` and a bogus `Trayectoriaable`
  type), caught immediately on review/compile and fixed before the green run. An
  edge case was consciously accepted rather than special-cased: a winning move
  that also crosses a collectible emits the event but skips the bonus because the
  session is already terminal (the clock has stopped anyway).

### T-006 — Ticket 07 · Observer Reactions (audio/UI decoupled from rules)

- **Task / problem addressed:** Implement the GoF **Observer** pattern to decouple
  audio and UI reactions from the game rules (`.issues/07-observer-reactions.md`,
  Stories F1). The use case must emit events through a Subject without knowing who
  listens; `AudioServiceImp` and the `JuegoViewModel` register as observers. Three
  acceptance criteria: (AC1) every registered observer receives emitted events;
  (AC2) the use case holds no direct reference to audio or UI; (AC3) this Observer
  is distinct from the MVVM data-binding (`notifyListeners()`).
- **AI tool used:** Claude Code (Sonnet 4.6 / claude-sonnet-4-6).
- **Prompt / instruction:** (verbatim) "implement this ticket
  `…\.issues\07-observer-reactions.md` is obligatory to apply the rules in these
  skills `…\clean-architecture\SKILL.md` `…\tdd-strict\SKILL.md` the visual design
  is up to you based on `…\lib\core\theme`".
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `domain/evento_juego.dart` (`EventoJuego` + `TipoEvento` moved here from
  `application/`); `domain/observador_juego.dart` (`abstract interface class
  ObservadorJuego { alOcurrirEvento(EventoJuego) }`); `domain/publicador_eventos_juego.dart`
  (`PublicadorEventosJuego` Subject — `suscribir / desuscribir / publicar`, iterates
  a snapshot so observers may safely unsub from within their callback);
  `application/use_cases/mover_flecha_use_case.dart` (accepts optional
  `PublicadorEventosJuego`, auto-creates one when absent, exposes `publicador`
  getter, publishes every `EventoJuego` via `_publicarTodos` — **zero** audio/UI
  imports); `infrastructure/audio/audio_service_imp.dart` (private ctor Singleton
  `AudioServiceImp._()` / `static final instance`, reacts to `flechaEliminada` and
  `victoria` via `alOcurrirEvento`, stubs audio calls pending a later asset-player
  ticket); `presentation/viewmodels/juego_view_model.dart` (implements
  `ObservadorJuego`, subscribes to `moverFlecha.publicador` in the constructor,
  handles `coleccionableRecogido` in `alOcurrirEvento` so `tocar()` no longer
  inspects `resultado.eventos` directly, unsubscribes in `dispose()`);
  `di/inyeccion.dart` (subscribes `AudioServiceImp.instance` to the use case's
  publisher before building the ViewModel). New tests: `test/domain/publicador_eventos_test.dart`
  (3 tests: all-observers notified, unsub stops delivery, sequential order preserved),
  `test/application/mover_flecha_publishes_events_test.dart` (3 tests: events reach
  spy via publisher on valid move, on penalized move; AC2 confirmed via spy),
  `test/infrastructure/audio_service_singleton_test.dart` (4 tests: singleton
  identity, implements ObservadorJuego, no-throw on flechaEliminada and victoria, no-throw
  on all event kinds). Verified: `flutter test` 73/73 green (63 prior + 10 new);
  zero `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** Review only — the team reviewed the tests and
  code; no manual code edits were required. `flutter test` and `flutter analyze`
  served as the guardrails.
- **Lessons learned / limitations identified:** Moving `EventoJuego` to `domain/`
  was architecturally necessary: the `ObservadorJuego` interface lives in domain and
  must reference the event type; keeping it in `application/` would have inverted the
  Dependency Rule. The "auto-create publisher" strategy in `MoverFlechaUseCase`
  (creates a fresh `PublicadorEventosJuego` when none is injected) meant all 63
  pre-existing tests passed unmodified — no ripple effect on the test suite.
  The ViewModel's two concurrent Observer roles (MVVM data-binding via
  `notifyListeners()` and game-event Observer via `alOcurrirEvento`) must be kept
  strictly distinct; in-code comments make this explicit and AC3 tests it.
  `AudioServiceImp._()` audio play methods are deliberate stubs — the Singleton +
  Observer shell is the ticket's deliverable; the actual audio asset wiring belongs
  to a later infrastructure ticket.

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** ~90%
- **Basis for the estimate:** All `lib/` and `test/` files across tickets 01, 02,
  03, 04, 05, and 07 were AI-generated then human-reviewed; the theme tokens under
  `lib/core/theme` were pre-existing (not AI-authored in these tasks). Every ticket
  followed the same pattern (full AI authoring + human review), so the share holds
  at ~90%. Rough judgment over the files added across the slices (73 passing tests,
  all source in `lib/domain/`, `lib/application/`, `lib/infrastructure/`,
  `lib/presentation/`, `lib/di/`).

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
- **Case:** First draft of `mover_flecha_collectible_test.dart` had a broken test
  helper — a misspelled return type (`Trayectoriaable`) and a call to an undefined
  `_pathEn` (ticket 03).
  - **How it was detected:** Self-review immediately after writing, confirmed by
    the compile error on the red-phase run.
  - **How it was corrected:** Replaced it with a properly typed `Trayectoria pathEn(...)`
    factory before proceeding to green.
- **Case:** After the first pass of the timer extraction, 4 presentation tests
  failed because `JuegoViewModel` required a `reloj` parameter that existing
  constructions didn't supply (ticket 06).
  - **How it was detected:** `flutter test` — 4 tests failed to compile.
  - **How it was corrected:** Added `_RelojNulo()` to each construction across
    4 test files. One file was fixed in a suboptimal way (importing a shared
    helper) and had to be refactored to use an inline class.

### Team reflection

- **Impact on productivity:** Very high across all six tickets. The predefined
  Clean Architecture / MVVM folder structure, the skills (`tdd-strict`,
  `clean-architecture`), and the detailed issue tickets gave the AI clear rails
  to follow. Each subsequent ticket was faster than the previous because domain
  vocabulary, port interfaces, and conventions were already established. T-006
  (iterative refactoring and test repair) was the fastest ticket to complete.
- **Impact on code quality:** The enforced TDD cycle plus architecture constraints
  kept output consistent and well-tested (78/78 tests, 0 warnings). The few AI
  mistakes were caught by `flutter analyze`, `flutter test`, and manual review —
  no defect reached production code.
- **Overall takeaways:** (1) Up-front investment in structure, skills, and
  well-scoped issues pays off directly in AI speed and reliability. (2) Reusing
  established domain abstractions (like the `Tablero` port) makes subsequent
  tickets faster and less error-prone. (3) A few architectural inconsistencies
  (e.g., missing use-case wrapper for generation, missing `AssetLoader` port)
  remain as technical debt — consciously deferred rather than accidental.

