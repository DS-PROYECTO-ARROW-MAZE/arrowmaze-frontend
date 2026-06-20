# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** ArrowMaze Frontend · **Last updated:** 2026-06-20 (T-011 appended)

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| Claude Code | Opus 4.8 / claude-opus-4-8 | Test-first implementation (tickets 01, 02, 03, 04, 09), refactoring, coverage |
| Claude Code | Sonnet 4.6 / claude-sonnet-4-6 | Test-first implementation (ticket 07), Observer pattern wiring, DI |
| OpenCode | deepseek-v4-flash-free | Test-first implementation (tickets 05, 10), architectural analysis, documentation |

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

### T-007 — Ticket 06 · Clean Architecture fixes (circular dependency + leaked Timer)

- **Task / problem addressed:** Fix two violations identified during code review:
  (1) circular dependency between domain/sesion/sesion_juego.dart ↔
  domain/sesion/estado_sesion.dart (GoF State pattern gave the concrete
  context a concrete dependency on the state hierarchy, violating DIP);
  (2) JuegoViewModel in presentation/ imported dart:async Timer.periodic
  directly (infrastructure leaked into presentation, violating Clean Architecture rules).
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** (paraphrased) The session began with the user asking
  "What did we do so far?" — the AI produced an anchored summary that surfaced
  the two issues from the conversation history. The user confirmed with "Do it"
  and "Continua" multiple times. The final cycle was "Pon el summary como un
  anchored read. Despues, actualiza los tests." The user also provided the
  AGENTS.md file as a reference for architecture rules.
- **Result obtained:** (1) domain/sesion/contexto_sesion.dart — new ContextoSesion
  interface; EstadoSesion now receives ContextoSesion instead of SesionJuego;
  SesionJuego implements ContextoSesion; the circular dependency is replaced by
  an acceptable abstract–abstract cycle per GoF State. (2)  pplication/ports/reloj.dart
  — new Reloj interface with iniciar(intervalo, tic) and detener();
  infrastructure/reloj/reloj_timer.dart — concrete RelojTimer using dart:async;
  JuegoViewModel now injects Reloj instead of using Timer directly;
  Inyeccion.construirJuegoViewModel() passes RelojTimer(). All 4 presentation
  test files inject _RelojNulo() (no-op). Verified: lutter test 78/78 green;
  lutter analyze no errors; zero package:flutter or dart:async imports under
  domain/+ pplication/.
- **Modifications made by the team:** The team reviewed all changes. During the
  iterative back-and-forth, several test failures occurred due to missing 
eloj:
  parameter in existing ViewModel constructions. The AI fixed each one as the
  user reported the failure. One presentation test file
  (juego_viewmodel_invalido_test.dart) had the _RelojNulo import added by
  the AI but was later refactored to define the class inline like the other test
  files — the user instructed "Pon el summary como un anchored read. Despues,
  actualiza los tests." which led to this final cleanup.
- **Lessons learned / limitations identified:** (1) Changing a constructor parameter
  that affects many callers (DI + 4+ test files) is best done by first adding the
  parameter as optional with a default before making it required, to keep the test
  suite green during the refactor. (2) The ContextoSesion interface was kept in
  the domain/sesion/ package rather than a domain/ports/ package — since the
  GoF State pattern is a domain-internal concern, this respects the project's
  package-by-layer convention. (3) The _RelojNulo helper was initially placed
  in the shared juego_viewmodel_test.dart but then moved inline into each
  test file (4 copies) following the project's self-contained test file convention —
  this is a small duplication vs. maintainability trade-off.

### T-008 — Ticket 08 · Identity, Auth & Session (register/login)

- **Task / problem addressed:** Implement client-side identity & session (register
  and login) with token storage via an injected `ProveedorSesion` port — never
  static/global accessor. Scope defined by `.issues/08-identity-auth-session.md`.
  Acceptance criteria: (AC1) successful register stores token via the injected
  session port; (AC2) duplicate-email register surfaces a mapped domain
  error (`RegistroEmailDuplicado`) with no raw exceptions; (AC3) session is read
  through the injected port, not a static/global accessor; (AC4) `cerrarSesion()`
  clears the stored token.
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** (paraphrased) The session spanned multiple rounds:
  starting with "Implement ticket 08 following TDD strict and Clean Architecture"
  and then iterating on each test failure / naming conflict / missing port,
  progressively building up the full stack. Key prompts included: implementing
  ports first, then use cases, then ViewModel/View, then infrastructure, and
  finally DI wiring. The user also instructed to run `flutter test` and
  `flutter analyze` after each cycle and fix any failures.
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `lib/application/ports/proveedor_sesion.dart` (abstract interface port —
  `obtenerToken`, `guardarToken`, `cerrarSesion`);
  `lib/application/ports/fuente_autenticacion.dart` (abstract interface port —
  `registrar`, `iniciarSesion` + `AutenticacionException`);
  `lib/application/use_cases/resultado_registro.dart` (sealed: `RegistroExitoso`,
  `RegistroEmailDuplicado`, `RegistroError`);
  `lib/application/use_cases/resultado_inicio_sesion.dart` (sealed:
  `InicioSesionExitoso`, `InicioSesionCredencialesInvalidas`, `InicioSesionError`);
  `lib/application/use_cases/registrar_usuario_use_case.dart` (injects
  `FuenteAutenticacion` + `ProveedorSesion`, maps `EMAIL_DUPLICATE` →
  `RegistroEmailDuplicado`);
  `lib/application/use_cases/iniciar_sesion_use_case.dart` (maps
  `INVALID_CREDENTIALS` → `InicioSesionCredencialesInvalidas`);
  `lib/infrastructure/sesion/proveedor_sesion_impl.dart` (in-memory token storage);
  `lib/infrastructure/datasources/fuente_autenticacion_http.dart` (dart:io
  HttpClient-based HTTP implementation);
  `lib/infrastructure/dtos/auth_request_dto.dart` + `auth_response_dto.dart`;
  `lib/core/errors/auth_errors.dart` (shared error code constants);
  `lib/core/config/api_config.dart` (API base URL and endpoint paths);
  `lib/presentation/viewmodels/auth_view_model.dart` (ChangeNotifier with
  login/register/idle/authenticated states);
  `lib/presentation/viewmodels/auth_view_state.dart` (immutable state + copyWith);
  `lib/presentation/views/auth/auth_view.dart` (login/register form UI using
  AppColors, AppTypography, AppSpacing theme tokens);
  `lib/di/inyeccion.dart` (proveedorSesion singleton, fuenteAutenticacion
  singleton, use case builders, `construirAuthViewModel()`). New tests:
  `test/application/registrar_usuario_use_case_test.dart` (AC1 + AC2),
  `test/infrastructure/proveedor_sesion_impl_test.dart` (AC4),
  `test/application/session_es_inyectado_test.dart` (AC3). Verified:
  `flutter test` 143/143 green (137 prior + 6 new); `flutter analyze` 0 errors,
  0 warnings from new code (9 pre-existing info-level lints only); zero
  `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** (a) A Dart naming conflict was detected:
  the ViewModel field `_iniciarSesion` (instance of `IniciarSesionUseCase`)
  shadowed the private method `_iniciarSesion()`; fixed by renaming the field to
  `_loginUseCase` and the other to `_registroUseCase`. (b) The `AuthViewModel.setField`
  parameter `FuenteAutenticacion` was removed — the ViewModel only needs
  `ProveedorSesion` + pre-built use cases, not the raw data source port.
- **Lessons learned / limitations identified:** The sealed-class pattern for
  result types (`ResultadoRegistro`, `ResultadoInicioSesion`) maps well to Dart's
  `sealed class` and forces exhaustive handling at every call site — no unhandled
  error states. Dart's field/method name collision (same identifier for a field
  and a private method) is easy to create when both follow the same naming
  convention; a naming convention like `_<Verb>UseCase` for injected use cases
  (vs. `_<verb>()` for methods) prevents it. Keeping `ProveedorSesion` as an
  injected abstract interface (never static/global) satisfies DIP and makes
  all callers (use cases, ViewModel) testable via simple inline fakes without
  mocktail.

### T-009 — Ticket 10 · Offline Progress Sync (client queue + batch upload)

- **Task / problem addressed:** Implement offline progress sync
  (`.issues\\10-offline-progress-sync.md`): queue completed runs offline and
  batch-upload when connectivity returns. Acceptance criteria: (AC1) `encolar()`
  stores locally with zero network dependency; (AC2) `sincronizar()` uploads all
  pending in a single batch call; (AC3) DTO shape matches Pact consumer contract;
  (AC4) failed upload leaves queue intact for retry. Domain model: `RunCompletado`
  value object. Ports: `IColaSincronizacion`, `IRepositorioProgreso`.
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** (paraphrased) The session started with the user asking
  "What did we do so far?" — the AI produced an anchored summary that surfaced the
  pending ticket 10. The user then instructed "Implement ticket #10: Offline Progress
  Sync. Follow TDD strict and Clean Architecture." The session iterated through
  multiple Red → Green → Refactor cycles: first the use case tests, then the
  domain/port layer, then infrastructure (DTOs, queue, HTTP datasource), then
  presentation (ViewModel, ViewState, sync status widget), and finally DI wiring
  and theme token updates. The user ran `flutter test` and `flutter analyze` after
  each cycle and reported any failures, which the AI fixed immediately. The user
  also instructed "Usa la skill 'ai-usage-doc' para documentar en el AI_USAGE.md
  todo el trabajo, los prompts y el resultado de este ticket" to finalize.
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `lib/domain/progreso/run_completado.dart` (value object — nivelId, movimientos,
  segundosRestantes, puntaje, estrellas, completadoEn);
  `lib/domain/progreso/i_cola_sincronizacion.dart` (abstract interface port —
  encolar, obtenerPendientes, vaciar, cantidadPendientes);
  `lib/application/ports/i_repositorio_progreso.dart` (abstract interface port —
  guardarLote);
  `lib/application/use_cases/sincronizar_progreso_use_case.dart` (injects
  `IColaSincronizacion` + `IRepositorioProgreso`; encola offline, sincroniza
  batch one-shot, queue-intact on failure);
  `lib/infrastructure/dtos/sync_run_dto.dart` + `sync_request_dto.dart` (toJson
  shapes matching Pact contract);
  `lib/infrastructure/progreso/cola_sincronizacion_local.dart` (in-memory queue);
  `lib/infrastructure/progreso/progreso_data_source_http.dart` (dart:io HttpClient
  batch POST with Bearer token);
  `lib/presentation/viewmodels/sync_view_state.dart` (SyncStatus enum + copyWith);
  `lib/presentation/viewmodels/sync_view_model.dart` (ChangeNotifier — encolar,
  sincronizar, _actualizarPendientes);
  `lib/presentation/views/sync/sync_status_view.dart` (compact HUD badge with
  coloured icon + pending-count + retry indicator);
  `lib/core/theme/game_theme.dart` (sync colour tokens — syncQueued, syncActive,
  syncDone, syncError);
  `lib/core/config/api_config.dart` (syncPath = '/progress/sync');
  `lib/di/inyeccion.dart` (singleton queue + repo, use case, factory for ViewModel).
  New tests: `test/application/sincronizar_progreso_use_case_test.dart` (4 tests:
  AC1 queue offline without network, AC2 batch upload calls guardarLote once, AC4
  failed upload leaves queue intact, empty queue skips call);
  `test/infrastructure/progreso_pact_consumer_test.dart` (2 tests: full DTO shape
  matches contract, empty batch produces empty runs array).
  Verified: `flutter test` 149/149 green (143 prior + 6 new); `flutter analyze`
  0 errors, 0 warnings from new code (9 pre-existing info-level lints only);
  zero `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** (a) After the first Red pass, AC4
  (queue-intact on failure) was not satisfied — `guardarLote` returned `void` but
  the test expected `bool`. Fixed by adding `bool` return to the port and a
  queue-preserving conditional in the use case. (b) A naming convention check:
  abstract interface ports were prefixed `I` throughout (e.g. `IColaSincronizacion`,
  `IRepositorioProgreso`) to match the project's existing convention. (c) The
  `SyncViewModel` initially imported the infra DTO (`SyncRunDto`) instead of the
  domain entity (`RunCompletado`) — caught during review and fixed to respect the
  Dependency Rule. (d) Theme tokens were adjusted to match the existing colour
  palette: `syncQueued` → `AppColors.warningNeon`, `syncActive` →
  `AppColors.accentNeon`, `syncDone` → `AppColors.primaryNeon`, `syncError` →
  `AppColors.errorNeon`.
- **Lessons learned / limitations identified:** (1) The `int` return from
  `guardarLote` (number of synced runs) was over-engineered for the current use
  case — a `bool` success signal suffices. Keeping return types minimal avoids
  unnecessary complexity. (2) The in-memory `ColaSincronizacionLocal` is adequate
  for the ticket's scope but will need persistence (SQLite/shared_preferences) in a
  future ticket to survive app restarts. (3) The Pact consumer tests verify JSON
  shape (`toJson`) without actual HTTP calls — true provider verification belongs
  in the backend repo. (4) The `SyncViewModel` is not yet wired into the gameplay
  loop (victory overlay and HUD badge) — documented as the immediate next step.

### T-010 — Ticket 11 · Leaderboard (read-only projection — client)

- **Task / problem addressed:** Implement the read-only client projection for the
  leaderboard (`.issues/11-leaderboard-read.md`, Stories E3). Top-N scores per
  `(idNivel, limite)` are fetched from the backend. The client is strictly
  **read-only** — no `publicar` write path exists. Acceptance criteria: (AC1)
  `obtenerTop` returns top-N per level; (AC2) the ranking port has zero write
  methods — no `publicar`; (AC3) the ranking DTO has a Pact consumer contract.
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** "Implementa el ticket `.issues\11-leaderboard-read.md`.
  Es OBLIGATORIO que apliques estrictamente las reglas de las skills 'tdd-strict'
  y 'clean-architecture'. El diseño visual lo defines tú usando 'lib/core/theme'."
  After completion the user instructed: "Usa la skill 'ai-usage-doc' para documentar
  en el AI_USAGE.md todo el trabajo, los prompts y el resultado de este ticket."
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `lib/domain/ranking/fila_ranking.dart` (pure entity — posicion, nombreJugador,
  puntaje, estrellas);
  `lib/domain/ranking/ranking_dto.dart` (read-only projection — List<FilaRanking>);
  `lib/application/ports/i_consulta_ranking.dart` (abstract interface port —
  `obtenerTop(int idNivel, int limite)`, no `publicar`);
  `lib/application/use_cases/consultar_ranking_use_case.dart` (delegates to
  `IConsultaRanking.obtenerTop`);
  `lib/infrastructure/dtos/fila_ranking_dto.dart` + `ranking_response_dto.dart`
  (toJson/fromJson shapes matching Pact contract — idNivel, limite, filas);
  `lib/infrastructure/ranking/ranking_data_source_http.dart` (dart:io HttpClient
  GET with Bearer token, parses RankingResponseDto → RankingDto);
  `lib/presentation/viewmodels/ranking_view_state.dart` (RankingStatus enum +
  RankingViewState immutable state + copyWith);
  `lib/presentation/viewmodels/ranking_view_model.dart` (ChangeNotifier —
  `cargarRanking(idNivel, limite)` with loading/loaded/error states);
  `lib/presentation/views/ranking/ranking_view.dart` (thin widget — AppBar +
  ranked list with position badges (gold/silver/bronze), player name, star row,
  neon score, error/empty states; all colours from AppColors/GameTheme tokens);
  `lib/core/config/api_config.dart` (rankingPath = '/ranking');
  `lib/di/inyeccion.dart` (consultaRanking singleton, consultarRankingUseCase,
  construirRankingViewModel).
  New tests (4 files, 8 tests):
  `test/application/consulta_ranking_test.dart` (2 tests: top-N for level returns
  ordered rows, empty ranking when no scores);
  `test/presentation/ranking_viewmodel_test.dart` (2 tests: exposes rows in
  ViewState on load, sets error status on port failure);
  `test/architecture/ranking_is_read_only_test.dart` (2 tests: source-level check
  that `publicar` is absent, interface has exactly `obtenerTop`);
  `test/infrastructure/ranking_pact_consumer_test.dart` (2 tests: DTO shape
  matches contract, empty ranking produces empty filas array).
  Verified: `flutter test` 157/157 green (149 prior + 8 new); `flutter analyze`
  0 errors, 0 warnings from new code (9 pre-existing info-level lints only);
  zero `package:flutter` imports under `domain/`+`application/`; no `publicar`
  method anywhere in ranking source.
- **Modifications made by the team:** (a) After the first test run, several test
  files failed due to missing imports (`ConsultarRankingUseCase`, `FilaRankingDto`)
  and a deleted `ranking_view_state.dart` — all fixed by correcting the import
  paths and re-creating the missing file. (b) The architecture test's regex for
  `publicar` matched the word inside a doc comment (`there is no \`publicar\``),
  causing a false positive — fixed by filtering comment lines before the method
  scan, then reworded the doc comment to avoid the literal. (c) The method-count
  regex `Future<\w+>\s+\w+\s*\(` correctly matched `Future<RankingDto> obtenerTop(`
  once the false-positive was cleared.
- **Lessons learned / limitations identified:** (1) A source-level architecture
  test (`should_have_no_publicar_method`) is effective but brittle: doc comments
  that quote the forbidden word (`publicar`) cause false positives unless the regex
  excludes comment lines. (2) The Pact consumer test for the ranking response DTO
  (infra layer) follows the same shape-verification pattern as the existing sync
  DTO test — consistent CI signal for contract drift. (3) The ranking port
  (`IConsultaRanking`) is intentionally thinner than the sync write port
  (`IRepositorioProgreso`): one `obtenerTop` method vs. one `guardarLote` method,
  both abstract interfaces with zero write semantics. (4) Caching (60s TTL via
  `InterceptorCacheRanking`) is the backend's concern — the client simply calls
  `obtenerTop` on every request, keeping the client-side read-port stateless and
  trivial.

### T-011 — Ticket 09 · Undo (valid or invalid move)

- **Task / problem addressed:** Implement Story B4 from `.issues/09-undo.md`: the
  player can undo their last move — valid **or** invalid — with every counter
  staying consistent. Acceptance criteria: (AC1) undo of a valid move reverses the
  board delta (the arrow is restored at its `Posicion`); (AC2) undo of an invalid
  move rolls back the no-delta +1; (AC3) `movimientos` decrements and all counters
  stay consistent; (AC4) undoing past an empty history is a safe no-op. The
  vertical slice touches all four layers: a `DeshacerMovimientoUseCase` consuming
  `CommandHistory`, `PlayerMoveCommand.deshacer()` (GoF **Command** undo), an
  incremental board re-link mirroring removal (DM-F1), undo legality gated to
  non-terminal `EstadoSesion` (DM-F5), and an undo button View → VM → use case
  (DM-F8).
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim) "implement this ticket
  `…\.issues\09-undo.md` is obligatory to apply the rules in these skills
  `…\clean-architecture\SKILL.md` `…\tdd-strict\SKILL.md` the visual design is up
  to you based on `…\lib\core\theme`".
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  **domain** — `Tablero.restaurarTrayectoria` port method + `GrafoTablero`
  implementation that re-materialises every segment cell and re-links each node to
  the nearest still-present neighbour in each direction (the exact inverse of
  `eliminarTrayectoria`'s wire-across-the-gap, incremental, identity-preserving),
  with a `_vecinoPresenteMasCercano` walk that skips still-removed gaps;
  `EstadoSesion.permiteDeshacer` (default `!estaTerminada` on the sealed base, so
  `EstadoJugando`/`EstadoPausado` allow undo and `EstadoVictoria`/`EstadoDerrota`
  forbid it) + `SesionJuego.puedeDeshacer`. **application** —
  `ContadorMovimientos` (the single shared mutable move counter both the forward
  and undo use cases mutate); `CommandHistory.pop()` + `estaVacio`;
  `PlayerMoveCommand.deshacer(Tablero)` (restores its delta's path, board no-op for
  a no-delta invalid command); `DeshacerMovimientoUseCase` (shares the session,
  history and counter with `MoverFlechaUseCase`, returns the same
  `ResultadoMovimiento` shape so undo and the forward move can't drift);
  `MoverFlechaUseCase` refactored to use the shared `ContadorMovimientos` instead
  of a private `int`. **presentation** — `JuegoViewModel.deshacer()` + a
  `puedeDeshacer` getter (defaults the undo use case onto the move use case's own
  session/history/counter); `GameView` undo `IconButton` in the AppBar (disabled
  when nothing to undo, hidden once the level is decided), beside the pause control,
  using existing theme tokens. Also corrected a misleading copy-pasted dartdoc on
  the pre-existing `GrafoTablero.agregarTrayectoria` (it described removal). New
  tests: `test/application/deshacer_movimiento_use_case_test.dart` (AC1 restore +
  decrement, AC2 rollback no-delta +1, AC4 empty-history no-op);
  `test/domain/tablero_relink_test.dart` (incremental re-link mirror, ray re-block
  after restore, and a cross-gap two-arrow reverse-order undo);
  `test/presentation/juego_viewmodel_undo_test.dart` (View→VM→use-case flow rebuilds
  the board snapshot and rolls the counter back; empty-history no-op). Verified:
  `flutter test` 165/165 green (157 prior + 8 new — 3 application, 3 domain, 2
  presentation); `flutter analyze` 0 errors / 0 warnings (20 pre-existing
  info-level lints only, `prefer_initializing_formals` and similar style hints);
  zero `package:flutter` imports under `domain/`+`application/`.
- **Modifications made by the team:** Review only — the team reviewed the tests and
  code; no manual code edits were required. `flutter test`/`flutter analyze` served
  as the guardrails. One test was added proactively during the refactor phase (the
  cross-gap two-arrow case) to lock in the re-link correctness beyond the ticket's
  single-arrow mirror test.
- **Lessons learned / limitations identified:** (1) Designing the undo result as
  the same `ResultadoMovimiento` shape the forward move returns — and routing both
  through one shared `ContadorMovimientos` — made "counters can't drift" a
  structural guarantee rather than a runtime check (the ticket's refactor goal).
  (2) The incremental board re-link had a subtle trap: a naive position-based
  re-link (link each restored node to its in-bounds neighbours) is **wrong** for
  adjacent arrows, because removal wires neighbours *across* the gap, so a restored
  node's true neighbour can be two-plus cells away. The correct mirror walks each
  direction skipping still-removed nodes; combined with reverse-order undo (popping
  the most-recent command first) this reconstructs cross-gap links exactly with no
  journal needed. This was reasoned out during design and pinned down with a
  dedicated cross-gap test. (3) Gating legality on the State subclass
  (`permiteDeshacer` defaulted on the sealed base) kept the rule out of the use
  case and the ViewModel, consistent with how `relojActivo`/`estaTerminada` are
  modelled. (4) Defaulting the undo use case inside the ViewModel from the move use
  case's already-injected session/history/counter (mirroring the existing
  `CalcularPuntuacionUseCase` default) meant all 157 prior tests passed unmodified
  and DI needed no change.

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** ~90%
- **Basis for the estimate:** All `lib/` and `test/` files across tickets 01, 02,
  03, 04, 05, 07, 08, 09, 10, and 11 were AI-generated then human-reviewed; the
  theme tokens under `lib/core/theme` were pre-existing (not AI-authored in these
  tasks). Every ticket followed the same pattern (full AI authoring + human review),
  so the share holds at ~90%. Rough judgment over the files added across the slices
  (165 passing tests, all source in `lib/domain/`, `lib/application/`,
  `lib/infrastructure/`, `lib/presentation/`, `lib/di/`).

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
- **Case:** ViewModel field `_iniciarSesion` (of type `IniciarSesionUseCase`)
  shadowed the private method `_iniciarSesion()` — Dart compiler error (ticket 08).
  - **How it was detected:** `flutter test` compile error.
  - **How it was corrected:** Renamed fields to `_registroUseCase` / `_loginUseCase`
    to avoid collision with the private methods `_registrar()` / `_iniciarSesion()`.
- **Case:** First draft of `SincronizarProgresoUseCase.sincronizar()` declared
  `guardarLote` as `void` instead of `Future<bool>`, so AC4 (queue intact on
  failure) had no way to signal success/failure (ticket 10).
  - **How it was detected:** `flutter test` — the AC4 test expected a `bool` return
    but the port method returned `void`.
  - **How it was corrected:** Changed the port signature to `Future<bool> guardarLote(...)`
    and the use case conditionally clears the queue only on `true`.
- **Case:** `SyncViewModel` initially imported `SyncRunDto` from infrastructure/
  instead of the domain entity `RunCompletado`, violating the Dependency Rule
  (ticket 10).
  - **How it was detected:** Manual Clean Architecture review.
  - **How it was corrected:** Replaced the infrastructure import with the domain
    import (`RunCompletado`).
- **Case:** Missing imports in test files (`ConsultarRankingUseCase`,
  `FilaRankingDto`) and a deleted `ranking_view_state.dart` caused 3 of 4 test
  files to fail loading (ticket 11).
  - **How it was detected:** `flutter test` — 3 compilation errors on first run.
  - **How it was corrected:** Added missing imports to test files and re-created
    the view state file.
- **Case:** Architecture test's `publicar` regex matched the word inside a doc
  comment (`there is no \`publicar\``), causing a false-positive failure
  (ticket 11).
  - **How it was detected:** `flutter test` — 2 architecture tests failed.
  - **How it was corrected:** Filtered comment lines before the regex scan, then
    reworded the doc comment to remove the literal `publicar` backtick reference.
- **Case:** The instinctive design for restoring a removed arrow on undo — a
  position-based re-link that wires each restored node back to its in-bounds
  neighbours — is incorrect for adjacent arrows, because removal wires neighbours
  *across* the gap, so a restored node's true neighbour can be several cells away
  (ticket 09).
  - **How it was detected:** Design-time reasoning while implementing
    `restaurarTrayectoria`, then locked in with a dedicated cross-gap two-arrow
    `tablero_relink_test.dart` case that would have failed the naive approach.
  - **How it was corrected:** Implemented the re-link as the true mirror of
    removal — a directional walk that skips still-removed nodes — which, paired
    with reverse-order undo, reconstructs cross-gap links exactly without any
    removal journal.

### Team reflection

- **Impact on productivity:** Very high across all ten tickets. The predefined
  Clean Architecture / MVVM folder structure, the skills (`tdd-strict`,
  `clean-architecture`), and the detailed issue tickets gave the AI clear rails
  to follow. Each subsequent ticket was faster than the previous because domain
  vocabulary, port interfaces, and conventions were already established. T-009
  (offline sync) was implemented in a single focused session — the fastest vertical
  slice yet (~2.5 hours of iterative Red-Green-Refactor cycles). T-010 (leaderboard
  read-only) was similarly fast — the read port pattern was already established from
  T-009 and the Pact consumer test followed the same shape-verification template.
- **Impact on code quality:** The enforced TDD cycle plus architecture constraints
  kept output consistent and well-tested (165/165 tests, 0 errors, 0 warnings from
  new code). The few AI mistakes were caught by `flutter test` and manual review —
  no defect reached production code. Architecture violations (ViewModel importing
  infra DTO) were caught and fixed during the same session. On ticket 09 the
  trickiest correctness concern (the incremental board re-link for adjacent arrows)
  was surfaced by design-time reasoning and pinned with a dedicated test before it
  could become a latent gameplay bug.
- **Overall takeaways:** (1) Up-front investment in structure, skills, and
  well-scoped issues pays off directly in AI speed and reliability. (2) Reusing
  established domain abstractions (like the `IColaSincronizacion` port interface)
  makes subsequent tickets faster and less error-prone. (3) A few architectural
  inconsistencies (e.g., missing use-case wrapper for generation, missing
  `AssetLoader` port) remain as technical debt — consciously deferred rather than
  accidental. (4) The "anchored summary" pattern (asking "What did we do so far?")
  is an effective way to re-synchronise context: it forces the AI to produce a
  structured recap that surfaces pending work, blockers, and next steps, which the
  team can then confirm or redirect before spending effort on the wrong task.

