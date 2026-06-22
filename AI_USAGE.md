# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** ArrowMaze Frontend · **Last updated:** 2026-06-21 (T-015 appended)

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| Claude Code | Opus 4.8 / claude-opus-4-8 | Test-first implementation (tickets 01, 02, 03, 04, 09, 12, 13, 14), refactoring, coverage, cross-platform/web fixes, API client + interceptor, doc reconciliation |
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

### T-012 — Ticket 12 · Use-case Decorator Stack + Architecture Guards

- **Task / problem addressed:** Implement Story F1 + §7.8 from
  `.issues/12-decorator-stack-and-arch-guards.md`: add metrics/logging/security
  to any use case by **composition** (GoF **Decorator**) with no framework
  leaking into the domain, plus automated CI guards that keep the architecture
  and ubiquitous language honest. Acceptance criteria: (AC1) a decorated use case
  returns the **same** result while the metrics/logging/security ports are
  invoked; (AC2) **no logging/metrics library** is imported inside the
  decorators; (AC3) `DecoradorSeguridad` reads the session via an injected
  `ProveedorSesion`, never a static accessor; (AC4) **domain purity** — `domain/`
  imports no Flutter/Nest/Prisma/logging/metrics symbols (ADR-0004); (AC5)
  **language guard** — forbids the avoid-list identifiers (`CeldaSalida`,
  `*Decorator` cells, `Composite`, `NivelFacil/Medio/Dificil`,
  `PuntuacionPorTiempo`, plural `CargadorNiveles`).
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim) "implement this ticket
  `…\.issues\12-decorator-stack-and-arch-guards.md` is obligatory to apply the
  rules of these skills `…\clean-architecture\SKILL.md` `…\tdd-strict\SKILL.md`
  the visual design is pu to you based on `…\lib\core\theme`".
- **Result obtained:** Strict TDD (red → green → refactor) producing —
  **application (depends only on ports, zero framework imports):**
  `lib/application/ports/i_caso_de_uso.dart` (`ICasoDeUso<E,S>` narrow generic
  contract — `Future<S> ejecutar(E)`);
  `lib/application/ports/i_registro.dart` (`IRegistro` logging port — `info`,
  `error`);
  `lib/application/ports/i_medidor_metricas.dart` (`IMedidorMetricas` metrics
  port — `registrar(operacion, {duracion, exito})`);
  `lib/application/decoradores/decorador_caso_de_uso.dart` (abstract
  `DecoradorCasoDeUso<E,S>` — GoF Decorator base holding the wrapped
  `ICasoDeUso`);
  `lib/application/decoradores/decorador_metricas_caso_de_uso.dart` (times via a
  pure `Stopwatch`, reports through the port for success **and** failure);
  `lib/application/decoradores/decorador_registro_caso_de_uso.dart` (logs
  enter/exit/error, rethrows);
  `lib/application/decoradores/decorador_seguridad_caso_de_uso.dart` (reads token
  through the injected `ProveedorSesion`, throws on absence);
  `lib/application/decoradores/sesion_requerida_exception.dart` (pure-Dart guard
  exception);
  `lib/application/decoradores/caso_de_uso_accion.dart` (function adapter so an
  existing use case is wrapped **without being edited**).
  **infrastructure (the only place primitives live):**
  `lib/infrastructure/observabilidad/registro_consola.dart` (`RegistroConsola`
  — the sanctioned console sink);
  `lib/infrastructure/observabilidad/medidor_metricas_simple.dart`
  (`MedidorMetricasSimple` + `MuestraMetrica` in-memory meter).
  **di:** `lib/di/inyeccion.dart` composes the full
  **security → logging → metrics → use case** stack around the leaderboard read
  (`consultarRankingDecorado`), lifting `ConsultarRankingUseCase` via
  `CasoDeUsoAccion` and reading the session through the injected
  `proveedorSesion` — the use case itself is untouched (AOP via SOLID).
  New tests: `test/application/decorador_caso_de_uso_test.dart` (AC1 same-result,
  AC1 all-ports-invoked, AC3 session via injected port, plus a block-when-no-token
  case — mocktail spies); `test/architecture/dependency_direction_test.dart`
  (AC2 no logging/metrics lib in decorators, AC4 domain framework-free —
  source-level import scans); `test/architecture/ubiquitous_language_test.dart`
  (AC5 avoid-list identifiers banned across `lib/`, full-line comments stripped so
  the rule can still be documented in dartdoc). Verified: `flutter test`
  172/172 green (165 prior + 7 new); `flutter analyze` 0 errors / 0 warnings on
  new code (only pre-existing info-level `prefer_initializing_formals` hints,
  which can't be satisfied here since named params can't be private initializing
  formals); zero `package:flutter`/logging/metrics imports under
  `domain/`+`application/`.
- **Modifications made by the team:** Review only — no manual code edits to the
  delivered design. During implementation the AI self-corrected three of its own
  first-draft slips (see below) before the green run / lint pass. The architecture
  guards were implemented as Dart tests under `test/architecture/` (run by
  `flutter test`) rather than a new GitHub Actions workflow, because the repo has
  **no `.github`/CI config** to extend — the ticket explicitly allowed
  "Dart tests (or `dart analyze` custom lint) wired into CI", and an offer to add
  a CI workflow was left open for the team.
- **Lessons learned / limitations identified:** (1) Naming the decorators with the
  Spanish `Decorador` prefix (not the English `Decorator` suffix) was deliberate:
  the AC5 language guard bans `*Decorator` on *cells*, and `Decorador` is not a
  substring of `Decorator`, so the new code stays green against its own guard. (2)
  The metrics/logging concerns are added purely by composition at the DI root, so
  no use case was edited to gain them — the "AOP via SOLID, no library" showcase
  (ADR-0004) is structural, not conventional. (3) Source-level architecture tests
  must strip comments before scanning: the existing dartdoc that *documents* the
  avoid-list (`PuntuacionPorTiempo must not exist`, `CeldaSalida`) would otherwise
  trip the very guard it describes — the language guard filters full-line `//`/`///`
  comments, mirroring the ticket-11 `publicar` regex lesson. (4) `ICasoDeUso<E,S>`
  was kept asynchronous so the security decorator can `await` the injected session
  port uniformly; a record entrada (`({int idNivel, int limite})`) let the
  leaderboard read be lifted into the generic contract without a bespoke param
  object.

### T-013 — Ticket 13 · Meta-Game Loop & Progression (Level Select + locks + post-game nav)

- **Task / problem addressed:** An end-to-end UX review found the meta-game loop
  broken in three ways: (1) no Level Selection screen (Auth jumped straight to a
  board), (2) no progression locks / completion persistence, (3) the Victory and
  Defeat overlays were dead ends with no actionable buttons. Build, as a brand-new
  ticket (not a retrofit of the closed ticket 05), the selection UI, an unlock
  engine with local persistence, and post-game Next/Retry/Level-Select navigation.
  Scope captured in `.issues/13-meta-game-loop-progression.md` and
  `DIAGRAM-RECONCILIATION.md §10`. A precondition was reconciling the docs to remove
  phantom interfaces (`ILevelRepository`, `IProgressRepository.getCompletedLevels()`)
  that were named in `CLAUDE.md`/`AGENTS.md` but never existed in code.
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim, kickoff) "Yes, please reconcile the
  documentation in `CLAUDE.md` and `AGENTS.md` first to remove those phantom
  references so we have a clean slate. … we are formalizing this as a brand new
  ticket: **Ticket 13 - Meta-Game Loop & Progression**. Please proceed with
  implementing your 5-point plan strictly under the scope of this new Ticket 13.
  For the local persistence (Point 1), please use the `shared_preferences` package
  … Let me know when the first slice of this new ticket is ready to test!" Then
  (verbatim, slice 2) "go with slice 2 and please write the issue in this folder
  …\.issues". The 5-point plan referenced was the one previously drafted into
  `DIAGRAM-RECONCILIATION.md §10` (progression read port + persistence, level
  catalog port, unlock-rule use case, Level Selection UI, post-game buttons).
- **Result obtained:** Delivered in two slices.
  **Docs reconciliation:** rewrote the "Interfaces del dominio" sections of
  `CLAUDE.md` and `AGENTS.md` to list the ports that actually exist and point the
  progression read at Ticket 13.
  **Slice 1 — progression engine (no UI):**
  `lib/domain/niveles/dificultad.dart` (`Dificultad` enum + `desde()` JSON mapper),
  `resumen_nivel.dart` (`ResumenNivel` value object),
  `regla_desbloqueo.dart` (`ReglaDesbloqueo` Strategy + `ReglaDesbloqueoSecuencial`
  — level 1 always open, level N unlocks when N−1 completed);
  `lib/application/ports/catalogo_niveles.dart` (`CatalogoNiveles`) +
  `consulta_progreso_local.dart` (`ConsultaProgresoLocal` read port,
  `nivelesCompletados`/`mejorEstrellas`/`registrarCompletado`);
  `lib/application/use_cases/nivel_con_estado.dart` + `obtener_niveles_use_case.dart`
  (joins catalog + progress + rule);
  `lib/infrastructure/progreso/progreso_local_persistente.dart`
  (**`shared_preferences`** store — best-stars per level under
  `arrowmaze.progreso.estrellas.<id>`; completed-set derived from keys);
  `lib/infrastructure/niveles/catalogo_niveles_archivo.dart` (`AssetManifest`
  enumeration of `assets/levels/level_*.json`); `di/inyeccion.dart` wiring;
  `pubspec.yaml` (`shared_preferences`).
  **Slice 2 — UI + navigation + content:**
  `lib/presentation/viewmodels/seleccion_niveles_view_state.dart`
  (`NivelResumenUI` + `SeleccionNivelesViewState`) +
  `seleccion_niveles_view_model.dart` (calls `ObtenerNivelesUseCase`);
  `lib/presentation/views/seleccion/seleccion_niveles_view.dart` (level cards with
  lock/star badges, locked cards dimmed & non-tappable);
  `lib/presentation/viewmodels/juego_view_model.dart` (records completion on
  victory via the injected `ConsultaProgresoLocal` + `idNivel`);
  `lib/presentation/views/game/game_view.dart` (Next/Retry/Level-Select buttons on
  both end-of-game overlays via a shared `_AccionesFinDeJuego`, injected callbacks);
  `lib/presentation/views/auth/auth_view.dart` (post-auth `construirInicio` →
  Level Select); `lib/main.dart` (Auth → Select → `_JuegoHost` `FutureBuilder`
  loading shell with per-level leaderboard and Next/Retry/Menu routing);
  `assets/levels/level_02.json` + `level_03.json`;
  `.issues/13-meta-game-loop-progression.md`. New tests (14):
  `test/domain/regla_desbloqueo_test.dart` (4),
  `test/application/obtener_niveles_use_case_test.dart` (3),
  `test/infrastructure/progreso_local_persistente_test.dart` (5,
  `SharedPreferences.setMockInitialValues`),
  `test/presentation/seleccion_niveles_viewmodel_test.dart` (2). Verified:
  `flutter test` 186/186 green (172 prior + 14 new); `flutter analyze` 0 errors /
  0 warnings (info-level `prefer_initializing_formals`/`unnecessary_underscores`
  only, matching existing style); `flutter build web` succeeds; Ticket 05's
  `SeleccionNivelViewModel` left untouched; zero `package:flutter` imports under
  `domain/`+`application/`.
- **Modifications made by the team:** Review plus several deliberate design choices
  on top of the AI's first drafts. (a) The AI's first `NivelConEstado` modelled
  `completado` as a getter with a dead `_completadoSinEstrellas` helper (a
  zero-star clear would have read as *not* completed) — self-caught while writing
  and replaced with an explicit `completado` field set by the use case from the
  completed-set, before any test run. (b) Diverged from the
  `DIAGRAM-RECONCILIATION.md §10.1` sketch: `registrarCompletado({idNivel,
  estrellas})` takes the two fields it needs rather than a `RunCompletado`, keeping
  progression decoupled from the offline-sync value object — documented in the issue.
  (c) Created a **new** `SeleccionNivelesViewModel` rather than mutating ticket 05's
  `SeleccionNivelViewModel`, honouring the "no retrofit of closed tickets" rule.
  (d) Renamed the post-auth builder `AuthView.construirJuego` → `construirInicio`
  for clarity now that it opens the menu, not a board.
- **Lessons learned / limitations identified:** (1) **Runtime gotcha (manual
  testing):** after a guest login the screen showed "Could not load levels". This
  was not a code or backend fault — the catalog reads bundled assets and progress
  reads local storage — but a stale `flutter run` session: the newly added
  `shared_preferences` web plugin and the new `level_02/03.json` assets are not
  picked up by hot reload/restart, only a cold `flutter run`. A reminder that
  plugin/asset additions need a full restart, especially on web. (2) The
  `AssetManifest`-based catalog adapter is hard to unit-test (needs the asset
  bundle), so coverage was placed on `ObtenerNivelesUseCase` via fake ports and on
  the persistence adapter via the `shared_preferences` mock; the adapter itself is
  exercised at runtime. (3) Content debt: `level_02/03.json` reuse level 01's
  proven-solvable interlocking layout so the catalog has sequential content now —
  authoring genuinely distinct boards that pass the solvability gate is follow-up
  work. (4) Per-level scoring still comes from `Inyeccion.definicionNivelInicial`
  (the offline default per §9.4), not from the level files yet. (5) Keeping the
  unlock policy a Strategy and the lock computation in the use case (never the
  View), with Retry/Next implemented as fresh-session navigation rather than new
  GoF session states, kept the existing State machine untouched.

### T-014 — Issue 14 · Connect API services with the NestJS backend (real contract)

- **Task / problem addressed:** The frontend's HTTP layer had been built
  speculatively against a mock/Pact contract that diverged from the now-finished
  NestJS backend (validated via Postman). Issue 14 required wiring the client to
  the **real** contract for all six endpoints (`/auth/register`, `/auth/login`,
  `/auth/me`, `/levels`, `/progress/sync`, `/leaderboard`), with a configurable
  base URL, typed request/response payloads, a clean service layer with error
  handling, persistent token management, and an HTTP interceptor that attaches the
  Bearer token to protected routes (AC1–AC3). Scope captured in
  `.issues/14-feat-frontend-connect-api-services-with-nestjs-backend.md`.
- **AI tool used:** Claude Code (Opus 4.8 / claude-opus-4-8).
- **Prompt / instruction:** (verbatim, kickoff) "please execute this issue
  …\.issues\14-feat-frontend-connect-api-services-with-nestjs-backend.md follow the
  rules inside these skills …clean-architecture\SKILL.md …tdd-strict\SKILL.md". The
  AI surfaced the contract mismatch (existing code vs. the real backend, plus an
  `int` vs. UUID `String` level-id conflict) and asked how far to align; the team
  chose (verbatim option) **"Full migration incl. domain"** — migrate domain types,
  datasources, viewmodels and tests end-to-end.
- **Result obtained:** Delivered via strict Red→Green TDD per unit.
  **Config & cross-cutting:** `lib/core/config/api_config.dart`
  (`baseUrl` via `String.fromEnvironment('API_BASE_URL', default
  'http://localhost:3000')` + the six real paths);
  `lib/infrastructure/network/cliente_http_autenticado.dart`
  (`ClienteHttpAutenticado extends http.BaseClient` — the Bearer **interceptor**,
  attaches `Authorization: Bearer <token>` from the injected `ProveedorSesion`,
  skips when no token; avoids the avoid-list `*Decorator` name);
  `lib/infrastructure/sesion/proveedor_sesion_persistente.dart`
  (`shared_preferences`-backed token, key `arrowmaze.sesion.token`).
  **Auth:** `domain/sesion/perfil.dart` + `usuario_registrado.dart`;
  `application/ports/fuente_autenticacion.dart` (`registrar({email,password}) →
  UsuarioRegistrado`, `iniciarSesion → token`, `obtenerPerfil → Perfil`);
  `application/use_cases/registrar_usuario_use_case.dart` (register **then** login,
  persist token) + `obtener_perfil_use_case.dart`; `infrastructure/dtos/
  auth_request_dto.dart` + `auth_response_dto.dart` (`AuthResponseDto`,
  `RegistroResponseDto`, `PerfilResponseDto`); `infrastructure/datasources/
  fuente_autenticacion_http.dart` (error mapping by status — 409→duplicate,
  401/403→bad creds, NestJS `message` string/array extraction).
  **Levels:** `domain/niveles/{celda_nivel,definicion_nivel_remota,nivel_creado}.dart`
  + `Dificultad.apiToken` (`FACIL/MEDIO/DIFICIL`); `application/ports/
  fuente_niveles.dart` + `application/use_cases/crear_nivel_use_case.dart`;
  `infrastructure/dtos/{crear_nivel_request_dto,nivel_creado_response_dto}.dart`
  (row-major `celdas[][]` of `{x,y,tipo}`); `infrastructure/niveles/
  niveles_data_source_http.dart`.
  **Progress sync:** `domain/progreso/run_completado.dart` migrated to
  `String nivelId` + `{estrellas,movimientos,tiempoSegundos,completadoEn}`;
  new `infrastructure/dtos/progreso_sync_dto.dart` + rewritten `sync_request_dto.dart`
  (envelope key `progresos`); deleted obsolete `sync_run_dto.dart`;
  `infrastructure/progreso/progreso_data_source_http.dart` (client-injected).
  **Leaderboard:** `domain/ranking/fila_ranking.dart`
  (`{email,puntaje,estrellas,movimientos,segundosRestantes?,completadoEn}`) +
  `ranking_dto.dart` (`entradas`); `application/ports/i_consulta_ranking.dart` +
  `consultar_ranking_use_case.dart` (`String nivelId`); `presentation/viewmodels/
  ranking_view_model.dart` + `ranking_view_state.dart` (`nivelId` String,
  `entradas`); `infrastructure/dtos/{fila_ranking_dto,ranking_response_dto}.dart`;
  `infrastructure/ranking/ranking_data_source_http.dart`
  (`GET /leaderboard?nivelId=<uuid>&limite=`); `presentation/views/ranking/
  ranking_view.dart` (renders `email`, 1-based rank from list index).
  **Wiring:** `di/inyeccion.dart` (one shared `ClienteHttpAutenticado` + persistent
  session injected into every protected data source; new levels/perfil graph;
  decorator record type `({String nivelId, int limite})`); `main.dart`
  (`cargarRanking(nivelId: '${widget.idNivel}', …)`); `auth_view_model.dart`
  (drop the `username` argument). New tests (18 net): interceptor (3),
  persistent session (3), auth HTTP datasource (5), profile use case (1),
  create-level use case (1) + datasource (1), progress datasource (2), ranking
  datasource (2); migrated `registrar_usuario_use_case_test`,
  `session_es_inyectado_test`, `sincronizar_progreso_use_case_test`,
  `progreso_pact_consumer_test`, `ranking_pact_consumer_test`,
  `consulta_ranking_test`, `ranking_viewmodel_test`. Verified: `flutter test`
  **204/204 green** (186 prior → +18 net new); `flutter analyze` 0 errors /
  0 warnings (info-level `prefer_initializing_formals`/`unnecessary_underscores`
  only, matching existing style); architecture guards still green
  (domain framework-free, ranking port single-method, no `*Decorator`).
- **Modifications made by the team:** Several deliberate decisions on top of the
  first drafts. (a) **Scope** was a human call via the clarifying question — chose
  full end-to-end migration rather than an additive parallel client. (b) The real
  `POST /auth/register` returns the created user but **no token**; rather than break
  the "register then you're in" UX, the team kept the auto-login behaviour by having
  `RegistrarUsuarioUseCase` register and then log in to obtain and persist the token.
  (c) Auth error codes are derived from **HTTP status** instead of relying on a
  backend `code` field, since the real error envelope was unspecified. (d) Local
  bundled levels stay **int**-keyed while the API uses **String UUID**; the two
  spaces are bridged at a single point in `main.dart` rather than fabricating UUIDs
  for assets — rationale recorded in the project memory. (e) The cosmetic
  `username` form field was left in the View/VM (harmless) but is no longer sent.
  No commit was made — changes left for review.
- **Lessons learned / limitations identified:** (1) Speculative API code written
  before the provider exists drifts from reality; the Pact-style shape tests caught
  the *envelope* drift but not the semantic ones (register returns no token,
  `int` vs UUID ids) — those needed reading the actual contract. (2) An
  `http.BaseClient` subclass is the idiomatic Dart way to implement an interceptor
  and keeps auth a true cross-cutting concern: data sources depend only on
  `http.Client` and never learn a token exists. (3) `shared_preferences` gives
  persistence but is **not** truly secure storage; `flutter_secure_storage` would be
  the hardened choice but was avoided here to skip a new native dependency. (4) The
  local↔backend level-id impedance (int vs UUID) is real technical debt: the
  leaderboard/sync paths won't return meaningful data for bundled levels until a
  create-then-track flow assigns real UUIDs. (5) `CLAUDE.md`/`AGENTS.md` port lists
  are now slightly stale (e.g. `obtenerTop(nivelId)`, new `FuenteNiveles`) and were
  intentionally left untouched per the "don't edit docs unless asked" rule.

### T-015 — Issue 20 · Logout Button (CerrarSesión)

- **Task / problem addressed:** Implement the logout button on the level-selection
  screen (`.issues/20-feat-frontend-logout-button.md`). Acceptance criteria: (AC1) a
  visible Logout control exists on the post-login surface; (AC2) tapping it calls
  `ProveedorSesion.cerrarSesion()`; (AC3) after logout the app returns to the auth
  screen; (AC4) the View never calls the use case directly — it delegates via an
  `onLogout` callback wired from the composition root.
- **AI tool used:** OpenCode (opencode/deepseek-v4-flash-free).
- **Prompt / instruction:** (paraphrased) "Implementa el Issue 20: Botón de Cerrar
  Sesión. Sigue TDD estricto (Red → Green → Refactor) y Clean Architecture. Primero
  escribe el `CerrarSesionUseCase` con test, luego refactoriza el `AuthViewModel`
  para usarlo, y finalmente añade el botón a `SeleccionNivelesView` con callback
  `onLogout` y wiring en `main.dart`. Ejecuta `flutter test` y `flutter analyze`
  después de cada ciclo."  After each Red → Green cycle the user prompted
  "continua", and after the final analyzer fix the user instructed "Usa la skill
  'ai-usage-doc' para documentar en el AI_USAGE.md todo el trabajo, los prompts y
  el resultado de este ticket."
- **Result obtained:** Strict TDD (red → green → refactor) producing:
  `lib/application/use_cases/cerrar_sesion_use_case.dart` (delegates
  `ejecutar()` → `ProveedorSesion.cerrarSesion()`);
  `lib/presentation/viewmodels/auth_view_state.dart` (new `sesionCerrada` bool +
  `copyWith`);
  `lib/presentation/viewmodels/auth_view_model.dart` (now requires
  `CerrarSesionUseCase` as constructor param; `cerrarSesion()` sets
  `sesionCerrada: true`);
  `lib/presentation/views/seleccion/seleccion_niveles_view.dart`
  (`IconButton(Icons.logout)` in AppBar actions, wired via new optional `onLogout`
  `VoidCallback`);
  `lib/di/inyeccion.dart` (`cerrarSesionUseCase` getter; updated
  `construirAuthViewModel()`);
  `lib/main.dart` (`_cerrarSesionYVolverALogin` — calls use case then
  `pushAndRemoveUntil` to fresh `AuthView`; fixes `use_build_context_synchronously`
  by capturing `Navigator.of(context)` before the `then`).
  New tests: `test/application/cerrar_sesion_use_case_test.dart` (2 tests: clears
  session on logout, no-op when already logged out);
  `test/presentation/auth_view_model_test.dart` (2 tests: exposes `sesionCerrada`
  after logout, resets form fields).
  Verified: `flutter test` 208/208 green (204 prior + 4 new); `flutter analyze`
  0 errors, 0 warnings on all new code; architecture guards still green.
- **Modifications made by the team:** Review only — the team reviewed the tests and
  code; no manual code edits were required. The AI self-corrected two minor issues
  after `flutter analyze` flagged them: (a) a `use_build_context_synchronously`
  warning in `main.dart` — fixed by capturing `Navigator.of(context)` before the
  async `then`; (b) an unused import in `auth_view_model_test.dart` — removed before
  finalizing. `flutter test` / `flutter analyze` served as guardrails throughout.
- **Lessons learned / limitations identified:** (1) The MVP `ProveedorSesion` port
  already had a `cerrarSesion()` method (from ticket 08), so the new
  `CerrarSesionUseCase` was a thin one-line delegation — keeping the port stable
  and the new class trivial. (2) Adding an `onLogout` callback on the View (rather
  than adding auth logic to `SeleccionNivelesViewModel`) respected SRP: the
  level-selection VM never learns about auth. (3) The `use_build_context_synchronously`
  lint is a common trap when chaining async use-case calls with navigation inside a
  `then` — capturing the navigator reference before the async gap is the idiomatic
  fix. (4) All 4 new tests pass with the `sesionCerrada` state field, keeping
  `AuthViewState` consistent and making the ViewModel testable without building the
  full widget tree.

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** ~90%
- **Basis for the estimate:** All `lib/` and `test/` files across tickets 01, 02,
  03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, and 20 were AI-generated then
  human-reviewed; the theme tokens under `lib/core/theme` were pre-existing (not
  AI-authored in these tasks). Every ticket followed the same pattern (full AI
  authoring + human review), so the share holds at ~90%. Rough judgment over the
  files added across the slices (208 passing tests, all source in `lib/domain/`,
  `lib/application/`, `lib/infrastructure/`, `lib/presentation/`, `lib/di/`; deps
  `http` and `shared_preferences` added during tickets' web/persistence work).

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
- **Case:** The language-guard test helper was written with a literal space in
  its identifier (`_codigoSin Comentarios`), an invalid Dart name (ticket 12).
  - **How it was detected:** Self-review immediately after writing the file, before
    the first test run.
  - **How it was corrected:** Renamed the helper to `_codigoSinComentarios` (and
    later, on the lint pass, to `codigoSinComentarios` to drop the leading
    underscore on a local function).
- **Case:** The three concrete decorators each imported `i_caso_de_uso.dart`
  although they reference `ICasoDeUso` only transitively via their base class —
  an unused-import warning (ticket 12).
  - **How it was detected:** `flutter analyze` (3 `unused_import` warnings).
  - **How it was corrected:** Removed the redundant import from each concrete
    decorator; the abstract base already carries the dependency.
- **Case:** The new test files declared local helper functions with leading
  underscores (`_stack`, `_imports`, `_codigoSinComentarios`), tripping the
  `no_leading_underscores_for_local_identifiers` lint (ticket 12).
  - **How it was detected:** `flutter analyze` (3 info-level lints).
  - **How it was corrected:** Renamed the locals to `construirStack`, `importsDe`,
    and `codigoSinComentarios`.
- **Case:** First draft of `NivelConEstado` exposed `completado` as a getter
  (`estrellas > 0 || _completadoSinEstrellas`, the latter hard-coded to `false`),
  so a level cleared with **zero stars** would have read as not completed and
  failed to unlock the next level (ticket 13).
  - **How it was detected:** Self-review while writing the model, before any test
    run — the dead helper was an obvious smell.
  - **How it was corrected:** Replaced it with an explicit `completado` field set by
    `ObtenerNivelesUseCase` from the completed-set; a dedicated use-case test
    (`should_mark_completed_even_when_cleared_with_zero_stars`) and persistence test
    (`should_mark_completed_when_cleared_with_zero_stars`) lock the behaviour in.
- **Case:** During manual web testing, "Could not load levels" appeared after a
  guest login (ticket 13).
  - **How it was detected:** User testing in Chrome (`flutter run -d chrome`).
  - **How it was corrected:** Diagnosed as a **stale dev session**, not a code or
    backend defect — the screen reads only bundled assets + local storage, but the
    newly added `shared_preferences` web plugin and `level_02/03.json` assets aren't
    registered by hot reload/restart. Resolved by a cold `flutter run`; no code
    change required. (Noted as a deployment limitation rather than an AI defect.)
- **Case:** Migrating the `FuenteAutenticacion` port (new `registrar` signature
  without `username`, new `obtenerPerfil` method) broke the older
  `session_es_inyectado_test.dart`, whose fake still overrode `registrar({email,
  password, username})` and lacked `obtenerPerfil` (ticket 14).
  - **How it was detected:** `flutter analyze` — 3 errors (`undefined_named_parameter`,
    `non_abstract_class_inherits_abstract_member`, `invalid_override`).
  - **How it was corrected:** Migrated the test's fake to the new contract
    (`registrar` returns `UsuarioRegistrado`, added `obtenerPerfil`) and updated the
    assertion to expect the **login** token, since register now auto-logs-in.
- **Case:** The new HTTP data-source tests cast the `MockClient` handler argument
  with `req as http.Request`, but `MockClientHandler` already receives an
  `http.Request` (ticket 14).
  - **How it was detected:** `flutter analyze` — 3 `unnecessary_cast` warnings.
  - **How it was corrected:** Dropped the redundant casts in the three test files.

### Team reflection

- **Impact on productivity:** Very high across all fourteen tasks. The predefined
  Clean Architecture / MVVM folder structure, the skills (`tdd-strict`,
  `clean-architecture`), and the detailed issue tickets gave the AI clear rails
  to follow. Each subsequent ticket was faster than the previous because domain
  vocabulary, port interfaces, and conventions were already established. T-009
  (offline sync) was implemented in a single focused session — the fastest vertical
  slice yet (~2.5 hours of iterative Red-Green-Refactor cycles). T-010 (leaderboard
  read-only) was similarly fast — the read port pattern was already established from
  T-009 and the Pact consumer test followed the same shape-verification template.
  T-014 (real-backend API client) touched every layer at once, yet the established
  port/datasource/DTO conventions let the AI migrate auth, levels, sync and
  leaderboard end-to-end in one session while keeping all 204 tests green — and the
  up-front clarifying question on migration scope prevented a wrong-sized refactor.
- **Impact on code quality:** The enforced TDD cycle plus architecture constraints
  kept output consistent and well-tested (186/186 tests, 0 errors, 0 warnings from
  new code, web build green). The few AI mistakes were caught by `flutter test` and
  manual review — no defect reached production code. On ticket 13 the trickiest
  correctness slip (a zero-star clear that would not have unlocked the next level)
  was self-caught at design time and pinned with dedicated tests before it could
  become a latent progression bug. Architecture violations (ViewModel importing
  infra DTO) were caught and fixed during the same session. On ticket 09 the
  trickiest correctness concern (the incremental board re-link for adjacent arrows)
  was surfaced by design-time reasoning and pinned with a dedicated test before it
  could become a latent gameplay bug. Ticket 12 went a step further by making the
  architecture rules *self-enforcing*: the dependency-direction, domain-purity, and
  ubiquitous-language guards are now executable tests in the suite, so a future
  framework leak or avoid-list identifier fails CI rather than relying on reviewer
  vigilance.
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
  (5) Tests and `analyze` catch logic and architecture faults, but **manual
  runtime testing still matters**: ticket 13's "Could not load levels" was a
  green-suite, clean-build session that only surfaced in the browser — a stale dev
  session needing a cold restart after new plugins/assets, not a code defect.

