# ArrowMaze — Product Requirements Document (PRD)

> **Status:** Draft for engineering kickoff
> **Author:** Senior Software Architect (autonomously generated)
> **Date:** 2026-06-17
> **Single source of truth inputs:** [`CONTEXT.md`](./CONTEXT.md) (ubiquitous language),
> [`DIAGRAM-RECONCILIATION.md`](./DIAGRAM-RECONCILIATION.md) (decisions Q1–Q18), and
> [`arrowmaze-backend/docs/adr/`](./arrowmaze-backend/docs/adr/) (ADR-0001 … ADR-0004).
> This document is normative: where prose and code disagree, the decisions recorded here
> and in the ADRs win, and the divergence is intentional (see §9 Open Risks).

---

## 1. Problem Statement & Solution

### 1.1 Problem

Players want a fast, "one-more-try" spatial puzzle that is **easy to pick up and hard to
master**, while the team needs a codebase that doubles as a **defensible showcase of clean
architecture and GoF design patterns** (the academic rubric). Two forces are in tension:

1. **Player force** — the game must feel instant and fair: every tap resolves immediately,
   any arrow is playable at any time, and the difficulty signal (move count, time) must be a
   *true* measure of skill, not luck.
2. **Engineering force** — the same domain runs on two stacks (Flutter client +
   Nest.js/Prisma backend) that must agree on rules (scoring, solvability) while keeping the
   domain layer free of frameworks, so the system stays testable and extensible (e.g. a
   future 3D board) without rewrites.

A naïve implementation couples game rules to the UI and to persistence, makes invalid moves
"free" (destroying the skill signal), and risks **soft-locking** players with unsolvable
levels — especially dangerous because levels can be authored/served from the backend.

### 1.2 Solution

ArrowMaze is a tap-to-clear grid puzzle. The board starts **fully covered** by arrows,
where each arrow is a **continuous, possibly bending path** (`Trayectoria`) of one or more
cells with a single arrowhead at its head. Tapping any segment of a path makes the **whole
path** try to exit in the head's `Direccion`; if the head's ray to the board edge is clear
the entire path **disappears** (its cells become empty, drawn as subtle dots), otherwise it
**retreats unchanged** and the tap is an *invalid move* — still counted, deliberately
penalized. **Victory** is emptying the board; **defeat** exists only on timed levels when
`limiteTiempo` runs out.

The solution is delivered as **two cooperating applications sharing one ubiquitous language**:

- **`arrowmaze-frontend`** — Flutter, **MVVM** presentation over a framework-free
  domain/application core. Offline-first: generates and validates its own levels, plays,
  scores, and queues progress for sync.
- **`arrowmaze-backend`** — Nest.js + Prisma (PostgreSQL/Supabase). The **authoritative
  gate**: it owns identity, persists/serves level definitions, re-validates solvability so a
  bad level can never be served, ingests synced progress, and projects the leaderboard.

Both sides enforce two non-negotiable invariants:

- **Solvability before render** — no board is ever shown or persisted unless a greedy,
  polynomial check proves it can be emptied (ADR-0001).
- **Move count is a true skill signal** — invalid taps increment `movimientos` and are
  recorded in history so undo stays consistent.

### 1.3 Goals & Non-Goals

| Goals | Non-Goals (explicitly out of scope) |
|---|---|
| Instant, all-or-nothing **whole-path** exit; tap any order | Traveling token / "stop in the middle" / cell-by-cell sliding |
| Continuous, bending multi-cell arrow paths; full initial coverage | Discrete 1×1 background tiles; arrow rotation; player position / reachability |
| Solvable-by-construction levels (client + server) | Deadlock-based defeat ("game over by blockage") |
| Deterministic, data-driven scoring + 1–3 stars | Real-time multiplayer / live PvP |
| Framework-free, pattern-showcasing domain | Exit/target tile ("maze-escape") interpretation |

### 1.4 Visual & Interaction Model (continuous paths)

The board is **not** a grid of discrete square tiles. It renders as a plain dark surface;
empty grid spaces show only a **subtle dot**. These rules are normative for the UI:

1. **No discrete background blocks.** There are no rounded square tiles behind cells — only
   the dark backdrop and dots for empty space.
2. **Continuous paths, not single blocks.** An arrow is a colored line/path spanning multiple
   cells, drawn as one continuous stroke through the cell centers it covers.
3. **Paths can bend.** A path may turn at 90° corners to snake around the board, and carries
   exactly **one** arrowhead, at its tip (head).
4. **Full initial coverage.** At level start every cell is covered by some path segment —
   there are **zero** empty cells until the player resolves paths.
5. **Gameplay reveal.** Resolving a path removes its **entire** length at once, leaving empty
   space (dots) behind, which in turn opens exit rays for the remaining paths.
6. **Path-following exit animation.** A resolving path animates out **snake-like** — the head
   travels along the path's own multi-cell trajectory to the exit edge and each tail segment
   follows the **exact same curve** (including bends), driven by Flutter animation controllers.
   It is **never** a rigid whole-shape slide. The animation is purely presentational and
   decoupled from the rule (the domain has already removed the path). See §12 (req 1) / FE-22.
7. **Irregular board shapes render faithfully.** Boards may be non-rectangular (heart, triangle,
   star…). The UI draws **only** playable cells; *absent* positions paint nothing and are not
   hit-testable, distinct from a transparent `CeldaVacia` (which still shows a dot). See §12
   (req 6) / FE-16 / FE-26.

> **Resolve rule (assumption, faithful to the source game):** a path resolves when its
> **head** has a clear straight ray to the board edge in the head's direction; the whole path
> then disappears. This reuses the existing `raycast`/`Tablero` machinery and keeps the
> order-independent solvability theory (`Solvencia`) intact — removals only ever clear cells.

### 1.5 Success Metrics

- **Correctness:** 100% of generated/served boards pass the solvability gate; 0 soft-locks.
- **Agreement:** client and backend produce identical `Puntaje`/`Estrellas` for the same
  input (verified by shared golden fixtures + Pact contract tests).
- **Quality bar (TDD):** domain + application layers ≥ 90% line coverage; every use case has
  a failing-first test; CI runs both solvers against shared golden boards (ADR-0001).
- **Feel:** a valid/invalid tap resolves and renders in a single frame (≤ 16 ms) on target devices.

---

## 2. Personas & Roles

| Persona | Description | Primary needs |
|---|---|---|
| **Player (guest)** | Plays offline, no account yet | Generate & play solvable levels, see score/stars, no friction |
| **Player (registered)** | Has an account, plays across devices | Sync progress, appear on leaderboard, resume |
| **Level Author / Ops** | Publishes new levels via the API | Create/update level definitions that are *guaranteed solvable* before they go live |
| **Examiner / Maintainer** | Reviews architecture | Point to each GoF pattern and each clean-architecture seam unambiguously |

---

## 3. User Stories

Stories are grouped by epic. Each carries acceptance criteria in **Given/When/Then** form;
these map directly to the automated tests in §7.

### Epic A — Core Move Mechanic

**A1 — Valid move (whole path exits).**
*As a player, when I tap an arrow path whose head can reach the edge, I want the entire path
to leave the board so I make progress.*
- **Given** an arrow `Trayectoria` whose head has a clear ray to the board edge,
  **When** I tap **any** of its segments,
  **Then** every cell of the path becomes `CeldaVacia`, the move is *valid*, `movimientos` += 1,
  and a `ResultadoMovimiento` with `FlechaEliminada` (and `MovimientoRealizado`) events is produced.

**A2 — Invalid move (penalized, board unchanged).**
*As a player, when I tap a path whose head ray is blocked, I want clear, fair feedback without
being able to "cheat" the move count.*
- **Given** a path whose head ray hits a `CeldaPared` or another path's segment,
  **When** I tap it,
  **Then** the board is unchanged, the path is **not** consumed, `movimientos` **still** += 1,
  a `ResultadoMovimiento` (no board delta) is produced, and a no-delta `+1` command is pushed
  to `CommandHistory`.

**A3 — Tap any order.**
*As a player, I want to tap any path at any time, on any of its segments.*
- **Given** any non-empty board, **When** I tap any `CeldaFlecha` segment,
  **Then** the owning path resolves with no player-position or reachability constraint.

**A4 — Collectible pass-through.**
*As a player, when a valid move's ray crosses a collectible, I want bonus time.*
- **Given** a `Coleccionable` on the path of an otherwise-clear ray,
  **When** the arrow exits,
  **Then** the ray is **not** blocked, a `ColeccionableRecogido` event adds seconds to the
  level timer, and victory never depends on the collectible.

### Epic B — Win / Lose / Session

**B1 — Victory.** *As a player, I win when the board is empty.*
- **Given** the last arrow exits, **Then** the session transitions to `EstadoVictoria`, a
  `Victoria` event fires, and the final `Puntaje`/`Estrellas` are computed.

**B2 — Defeat (out of time *or* out of moves).** *As a player, I lose if time runs out on a
timed level **or** if I exhaust my move budget before clearing the board.*
- **Given** a level with `limiteTiempo`, **When** the timer reaches 0 before victory,
  **Then** the session transitions to `EstadoDerrota`.
- **Given** a level's move budget (`presupuestoMovimientos = nFlechas + margen`), **When** the
  budget reaches 0 while the board is non-empty, **Then** the session transitions to
  `EstadoDerrota` (Game Over) — **on timed *and* untimed levels**. Clearing the board on the
  last allowed move is a **victory** (victory wins ties). See §12 (req 12) / FE-30.
- **Note (superseded invariant):** the move-budget rule introduces a **timer-independent**
  defeat trigger, so the former "an untimed level can never enter `EstadoDerrota`" invariant is
  **deliberately retired** as of 2026-06-24 (§12). Deadlock-based defeat (§1.3 / §10) remains
  out of scope — defeat comes only from time or move-budget exhaustion.

**B5 — Move countdown HUD.** *As a player, my moves count **down** from a per-level budget.*
- **Given** a started level, **Then** the HUD shows `presupuestoMovimientos` decrementing on
  every tap (valid **or** invalid, consistent with A2) rather than a from-zero up-counter. FE-30.

**B3 — Pause/Resume.** *As a player, I can pause and resume.*
- **Given** `EstadoJugando`, **When** I pause, **Then** state is `EstadoPausado` and taps are
  rejected until I resume (`EstadoJugando`). The timer does not advance while paused.

**B4 — Undo (capped at 3 per level).** *As a player, I can undo my last move (valid or invalid),
up to a strict maximum of **3 uses per level**.*
- **Given** a recorded move in `CommandHistory`, **When** I undo,
  **Then** the board delta is reversed (or the no-delta +1 is rolled back), `movimientos`
  decrements, the **move budget is restored by one** (§B2/FE-30), and counters stay consistent.
- **Given** I have already undone **3** times this level, **When** I attempt a 4th undo,
  **Then** it is a no-op and the control is disabled; the undo counter **resets** on level
  restart / new level. See §12 (req 8) / FE-30.

### Epic C — Levels & Generation

**C1 — Random solvable level.**
*As a player offline, I want a fresh level that is always winnable.*
- **Given** a request to `GeneracionAleatoriaNivel`, **Then** the produced board passes
  `validarSolvencia` **before** it is rendered; an unsolvable candidate is never shown.

**C2 — Load level by id (asset or backend).**
*As a player, I can load a specific authored level.*
- **Given** a level id, **When** `GeneracionPorArchivoNivel` loads it via the `CargadorNivel`
  port, **Then** it is validated for solvability before render, regardless of source.

**C3 — Author a level (backend gate).**
*As Ops, I publish a level and trust it can't soft-lock anyone.*
- **Given** a `CrearNivelCasoDeUso`/`ActualizarNivelCasoDeUso` request with a board,
  **When** the greedy solver cannot empty it,
  **Then** the request is **rejected** and nothing is persisted/served (ADR-0001).

### Epic D — Scoring & Progression

**D1 — Deterministic score.**
*As a player, my score reflects skill (fewer moves, more time left).*
- **Given** `movimientos`, `segundosRestantes`, and the level's `baseNivel`/`Kmov`/`Ktiempo`,
  **Then** `Puntaje = max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo)`; the
  time term is dropped on untimed levels.

**D2 — Strategy selection.**
- **Given** a timed level, scoring uses `PuntuacionMixta`; **given** an untimed level it uses
  `PuntuacionPorMovimientos`. (`PuntuacionPorTiempo` does not exist.)

**D3 — Stars.**
- **Given** a `Puntaje` and the three `umbralesEstrellas` thresholds in `DefinicionNivel`,
  **Then** `CalcularPuntuacionUseCase` returns both `Puntaje` and a 1–3 `Estrellas` rating,
  so client and backend always agree.

### Epic E — Identity, Sync & Leaderboard

**E1 — Register.** *As a guest, I can create an account.*
- **Given** valid credentials, **When** I register, **Then** a `User` is persisted (unique
  email, hashed password) atomically via a Prisma nested/single write (no Unit of Work, ADR-0003).

**E2 — Sync offline progress.** *As a returning player, my offline runs upload.*
- **Given** a queue of completed runs, **When** I sync, **Then** they persist as one batch
  inside a repository-scoped `$transaction` (`RepositorioProgreso.guardarLote`), the
  application layer never naming Prisma (ADR-0003).

**E3 — Leaderboard (read projection).** *As a player, I see top scores per level.*
- **Given** synced progress, **When** I open the leaderboard, **Then** I read a top-N
  projection (`IConsultaRanking`) served through a ~60s TTL cache keyed by `(idNivel, limite)`
  (`InterceptorCacheRanking`). The leaderboard is read-only — no client `publicar()`.

### Epic F — Reactions (audio/UI) decoupled from rules

**F1 — Events drive reactions, not the domain.**
- **Given** a move emits `List<EventoJuego>`, **When** the use case feeds them to
  `PublicadorEventosJuego`, **Then** registered `ObservadorJuego`s react (audio plays on
  `FlechaEliminada`/`Victoria`; score & HUD view models update) **without** the use case
  referencing audio or UI.

---

## 4. Domain Model & Ubiquitous Language (binding)

The terms below are normative (full definitions in `CONTEXT.md`). Code, tests, and APIs MUST
use these names.

- **Movimiento / ResultadoMovimiento** — one tap → exactly one result; exit is all-or-nothing
  and resolves the **whole path**, never a single cell.
- **Flecha / Trayectoria** — an arrow is a continuous, possibly bending multi-cell path with one
  arrowhead at its head; each covered cell is a `CeldaFlecha` segment sharing the path's `idFlecha`.
- **CeldaFlecha, CeldaPared, CeldaVacia, Coleccionable** — the **four** `Celda` kinds, produced by
  `FabricaCeldasEstandar`. **No** `CeldaSalida`, **no** cell decorators, **no** Composite.
- **Tablero** — a **port** (`celdaEn`, `trayectoriaEn`, `raycast`, `eliminarTrayectoria`);
  `GrafoTablero` is the incremental implementation detail (removing a path unlinks each of its
  nodes; never a full rebuild).
- **Posicion / Vector3 / Direccion** — dimension-agnostic; 2D = 4 dirs, future 3D = 6, same contract.
- **Nivel / DefinicionNivel / Dificultad** — difficulty is **data** (enum + definition), never
  a subtype. No `NivelFacil/Medio/Dificil`.
- **Solvencia** — order-independent; greedy polynomial decision procedure; gate before render.
- **EventoJuego / TipoEvento** — pure value objects (a record of what happened, never a command).
- **EstadoSesion** — GoF **State**: exactly `EstadoJugando/Pausado/Victoria/Derrota`. Distinct
  from MVVM `*ViewState` UI snapshots.

> **Avoid-list enforced in review:** rotación, token, turno, CeldaSalida, cell decorators,
> Composite, `NivelFacil/Medio/Dificil`, `PuntuacionPorTiempo`, plural `CargadorNiveles`,
> calling MVVM `notifyListeners()` "the Observer", conflating `VictoriaViewState` with `EstadoVictoria`.

---

## 5. Architecture Overview

Both apps follow **Clean Architecture** with a strict Dependency Rule: `domain` ← `application`
← `infrastructure`/`presentation`. The **domain layer imports no framework** — no Flutter,
no Nest, no Prisma, no logging/metrics libraries (ADR-0004).

```
            ┌──────────────────────── arrowmaze-frontend (Flutter / MVVM) ────────────────────────┐
            │ presentation (Views, ViewModels, *ViewState)                                          │
            │   ▲ data-binding (notifyListeners)            ▲ ObservadorJuego reactions             │
            │ application (use cases, Decorator stack, ports: Tablero, CargadorNivel, ProveedorSesion)│
            │ domain (Celda/Flecha, GrafoTablero, EstadoSesion, EstrategiaPuntuacion, Solver, Events)│
            │ infrastructure (datasources, dtos, mappers, network, repositories, AudioServiceImp)   │
            └───────────────────────────────────────────────────────────────────────────────────────┘
                                         │ HTTP (DTO contracts, Pact)
                                         ▼
            ┌──────────────────────── arrowmaze-backend (Nest.js / Prisma) ───────────────────────┐
            │ infrastructure/adapters/http (controllers, guards, interceptors, presenters)          │
            │ application (use cases + Decorator stack, dtos, services)                              │
            │ domain (aggregates, entities, value-objects, events, repositories ports, exceptions)   │
            │ infrastructure/adapters/persistence (Prisma, mappers, repositories) · security · messaging│
            └───────────────────────────────────────────────────────────────────────────────────────┘
```

**Cross-cutting (AOP) is split by altitude (ADR-0004):**
- **Application layer →** use-case **Decorator** stack, *identical on both repos*:
  `DecoradorCasoDeUso` (abstract) + `DecoradorMetricas/Registro/SeguridadCasoDeUso`, depending
  on **ports** (`IMedidorMetricas`, `IRegistro`, `ProveedorSesion`) — the "AOP via SOLID, no library" showcase.
- **Transport layer →** NestJS interceptors at the HTTP edge (access logging, correlation,
  error→DTO mapping, `InterceptorCacheRanking`) — framework plumbing, explicitly *not* the showcase.

---

## 6. Technical Implementation — Deep Modules

We design to **Ousterhout's "deep modules"**: a *narrow, stable interface* hiding a *powerful,
substitutable implementation*. Below, each module is specified as **Interface (shallow surface)**
+ **Hidden complexity** + **Why it is deep / what it lets us change without callers noticing**.

### 6.1 Frontend Deep Modules (Flutter / MVVM)

#### DM-F1 · `Tablero` (board port) — `lib/domain/...`
- **Interface:** `Celda celdaEn(Posicion p)`, `Trayectoria? trayectoriaEn(Posicion p)`,
  `ResultadoRaycast raycast(Posicion origen, Direccion dir)`, `void eliminarTrayectoria(int id)`.
- **Hidden:** `GrafoTablero` graph + `Nodo` links, the `idFlecha → Trayectoria` index,
  **incremental** mutation (removing a path unlinks each of its nodes — never a full rebuild),
  neighbor wiring, edge detection.
- **Why deep / OCP seam:** callers (use cases, solver, collision detector) never see the graph
  or how a path is stored. A future **3D board** is a new `Tablero` implementation with
  6-direction `Vector3` — *zero* caller changes. `DetectorColisiones.detectar(...)` delegates to
  `raycast(...)`.

#### DM-F2 · `MoverFlechaUseCase` (move resolution) — `lib/application/use_cases`
- **Interface:** `ResultadoMovimiento ejecutar(Posicion celda)`.
- **Hidden:** path lookup from the tapped segment (`trayectoriaEn`), head-ray clear/blocked
  decision, valid-exit **whole-path** removal vs invalid retreat, `movimientos` increment for
  **both** outcomes, `EventoJuego` list assembly, `CommandHistory` push (real delta *or* no-delta
  +1), victory check, scoring trigger.
- **Why deep:** a one-call surface hides the entire rule engine. The tap-any-segment resolution,
  the penalize-invalid-taps rule and the all-or-nothing whole-path exit live here only — UI and
  persistence stay ignorant of them.

#### DM-F3 · `EstrategiaGeneracionNivel` + `GeneradorNivelBase` (level generation) — Strategy + Template Method
- **Interface:** `DefinicionNivel generar(ConfigGeneracion config)` (template, **final**).
- **Hidden:** fixed skeleton `crearTableroVacío() → poblar() → validarSolvencia() → entregar()`;
  `poblar()` is the **only** overridable hook. `GeneracionAleatoriaNivel` /
  `GeneracionPorArchivoNivel` override only `poblar()`.
- **Why deep:** `validarSolvencia` **cannot be skipped** — solvability-before-render is a structural
  guarantee, not a caller responsibility. New generation strategies = override one hook.

#### DM-F4 · `Solver` (`validarSolvencia`) — `lib/domain/...`
- **Interface:** `bool esSolvable(Tablero tablero)`.
- **Hidden:** greedy loop (remove any arrow with a clear ray until empty; solvable iff board empties).
- **Why deep:** order-independence and polynomial completeness are guaranteed internally; callers
  get a boolean. Mirrored in TS on the backend; agreement enforced by **golden boards** (ADR-0001).

#### DM-F5 · `EstadoSesion` (GoF State) — `lib/domain/...`
- **Interface:** `ResultadoMovimiento tocarCelda(Posicion p)`, `pausar()`, `reanudar()`,
  `cambiarEstado(EstadoSesion e)`, `bool estaTerminada()`.
- **Hidden:** per-state behavior in `EstadoJugando/Pausado/Victoria/Derrota`; `SesionJuego`
  delegates and switches via `cambiarEstado`.
- **Why deep:** legality of a tap (rejected while paused/finished) is encoded by *type*, not
  scattered `if`s. **Not** the MVVM `*ViewState` snapshots.

#### DM-F6 · `EstrategiaPuntuacion` + `CalcularPuntuacionUseCase` (scoring) — Strategy
- **Interface:** `ResultadoPuntaje calcular(...)` → `{ Puntaje, Estrellas }`.
- **Hidden:** timed→`PuntuacionMixta` / untimed→`PuntuacionPorMovimientos` selection; the
  `max(0, …)` formula; star thresholding from `umbralesEstrellas`.
- **Why deep:** tuning is **data** (`baseNivel/Kmov/Ktiempo` in `DefinicionNivel`); algorithm
  swaps without touching callers. Returns both numbers so the backend agrees.

#### DM-F7 · `PublicadorEventosJuego` + `ObservadorJuego` (GoF Observer)
- **Interface:** Subject `suscribir/desuscribir/publicar(EventoJuego)`; Observer `alOcurrirEvento(EventoJuego)`.
- **Hidden:** observer registry + dispatch. Observers: `AudioServiceImp`, score VM, HUD/board VM.
- **Why deep:** the use case emits events and knows no reaction. **Distinct** from MVVM
  data-binding (`notifyListeners()`), which is View↔ViewModel only.

#### DM-F8 · MVVM Presentation (`ViewModel` + immutable `*ViewState`)
- **Interface:** ViewModels expose immutable `JuegoViewState` / `VictoriaViewState` /
  `SeleccionNivelViewState` (with `TableroUI`, `CeldaUI`, `NivelResumenUI`) via `copyWith`;
  Views bind via `notifyListeners()`.
- **Hidden:** mapping domain → UI snapshots, including per-segment **path geometry** for the
  board (`CeldaUI.conexiones`/`esCabeza`/`idFlecha`) read off each `Trayectoria`; a `CustomPainter`
  draws continuous bending paths + arrowheads and dots for empties (no discrete tiles);
  orchestration of use cases.
- **Why deep / guardrail:** UI churn never reaches the domain. `VictoriaViewState` (UI) is **not**
  `EstadoVictoria` (session state) — naming enforced to keep the State pattern unambiguous.

#### DM-F9 · `CargadorNivel` (level-loader port) + Decorator use-case stack + `ProveedorSesion`
- **Interface:** `CargadorNivel.cargar(String ruta) → Future<DefinicionNivelDto>`;
  `DecoradorCasoDeUso<E,S>` wraps `ICasoDeUso<E,S>`; `ProveedorSesion.obtenerToken/guardarToken/cerrarSesion`.
- **Hidden:** asset (`CargadorNivelArchivo`) vs HTTP (`CargadorNivelHttp`) source; metrics/logging/
  security wrapping; token storage (`ProveedorSesionImpl`).
- **Why deep / DIP:** strategies depend on the **port**, never a concrete loader; cross-cutting is
  added by composition; session is an injected port, **not** a static singleton (ADR-0002).
  `AudioServiceImp` is the **one** honest GoF Singleton.

### 6.2 Backend Deep Modules (Nest.js / Prisma)

#### DM-B1 · `Nivel` aggregate + `DefinicionTablero` VO (solvability invariant) — `src/domain`
- **Interface:** construct/validate a level; `DefinicionTablero` rejects unsolvable boards on creation.
- **Hidden:** the greedy TS solver enforced as an **aggregate invariant**.
- **Why deep:** it is structurally impossible to persist/serve a soft-lock — the gate is the type,
  not a caller check (ADR-0001). Re-validated client-side as defense-in-depth.

#### DM-B2 · `CrearNivelCasoDeUso` / `ActualizarNivelCasoDeUso` — `src/application/use-cases`
- **Interface:** `execute(dto) → Result`.
- **Hidden:** validation, solvability gate, mapping, persistence via repository port; **no Unit of
  Work** — single-aggregate atomicity from Prisma nested writes (ADR-0003).
- **Why deep:** callers (controllers) never know about Prisma or transactions; rejection of bad
  levels is encapsulated.

#### DM-B3 · `IRepositorioNivel` / `IRepositorioJugador` / `RepositorioProgreso` (Repository ports) — `src/domain/repositories` + `infrastructure/adapters/persistence`
- **Interface:** port methods (`guardar`, `obtenerPorId`, `RepositorioProgreso.guardarLote(...)`, …).
- **Hidden:** Prisma client, mappers, and — for batch sync — a `$transaction` **encapsulated inside
  the adapter** (ADR-0003).
- **Why deep:** the application layer never names Prisma; swapping the DB or transaction strategy is
  invisible to use cases.

#### DM-B4 · Use-case Decorator stack (`DecoradorCasoDeUso` + Metricas/Registro/Seguridad) — `src/application`
- **Interface:** `ICasoDeUso<E,S>.execute(E) → S`; decorators share that surface.
- **Hidden:** metrics (`IMedidorMetricas`), logging (`IRegistro`), security (`ProveedorSesion`) —
  all **ports**, real libs only in infra adapters (`RegistroConsola`, `MedidorMetricasSimple`).
- **Why deep:** cross-cutting is added by composition without editing use cases, and **no framework
  leaks into the domain** — the rubric's "AOP via SOLID, no library" showcase (ADR-0004).

#### DM-B5 · `IConsultaRanking` (CQRS-lite read) + `InterceptorCacheRanking` — leaderboard projection
- **Interface:** `obtenerTop(idNivel, limite) → RankingDto`.
- **Hidden:** read-optimized Prisma query (`ConsultaRankingPrisma`); transport-level cache, ~60s TTL
  keyed by `(idNivel, limite)`.
- **Why deep:** the leaderboard is a **read-only projection** over synced progress (no client write
  path); caching is an interceptor at the edge, invisible to the read port.

#### DM-B6 · HTTP transport (controllers, guards, interceptors, presenters) — `src/infrastructure/adapters/http`
- **Interface:** REST endpoints; DTO request/response contracts (Pact-tested against the client).
- **Hidden:** auth guards, access logging/correlation interceptors, global error→DTO mapping, presenters.
- **Why deep:** the wire contract is the only coupling to the client; internal use-case shapes change freely.

#### DM-B7 · `IPublicadorEventos` (backend domain events) — `src/domain/events` + `infrastructure/adapters/messaging`
- **Interface:** publish backend domain events (e.g. *player registered*).
- **Hidden:** dispatch/transport.
- **Why deep / disambiguation:** this is the **backend's own** publisher — **distinct** from the
  frontend `PublicadorEventosJuego`; keep both.

### 6.3 Persistence (Prisma / PostgreSQL on Supabase)

- Current schema: `User { id: Uuid @id, email @unique, passwordHash, createdAt }` (`@@map users`).
- **To add for MVP** (single-aggregate writes, no UoW): `Nivel`/level-definition tables (board,
  cells, scoring constants `baseNivel/Kmov/Ktiempo`, `umbralesEstrellas`, `limiteTiempo?`,
  `dificultad`), `Progreso` (per player/level run: `movimientos`, `segundosRestantes`, `puntaje`,
  `estrellas`, `completadoEn`), and the ranking read projection source.
- Level + cells persist via **one Prisma nested write**; progress sync persists via
  `RepositorioProgreso.guardarLote` inside a repository-scoped `$transaction`.

---

## 7. Acceptance Criteria for Automated Tests (TDD)

**Process:** every use case and domain rule is written **test-first** (red → green → refactor).
Tests target the **deep-module interfaces** (§6), not internals, so refactors don't break suites.
Domain + application layers target **≥ 90% line coverage**.

### 7.1 Test layers

| Layer | Frontend (Dart / `flutter_test`) | Backend (Jest) |
|---|---|---|
| **Unit (domain)** | Solver, raycast/`Tablero`, `EstadoSesion`, scoring strategies, factory | Solver invariant, value objects, aggregates |
| **Unit (application)** | use cases (move, undo, generate, score) with fake ports | use cases with fake repositories/ports |
| **Integration** | repositories ↔ datasources/mappers; DI wiring | repositories ↔ Prisma (test DB); HTTP e2e |
| **Contract** | Pact consumer (DTO shapes) | Pact provider verification |
| **Golden (cross-repo)** | Dart solver vs shared fixtures | TS solver vs **same** shared fixtures |

### 7.2 Move mechanic (DM-F2 / DM-F1)

- ✅ Clear head ray → **whole path** removed (every segment `CeldaVacia`), `movimientos == 1`,
  events include `FlechaEliminada`. Tapping any segment of the path resolves it.
- ✅ Head ray blocked by wall **and** blocked by another path's segment (two cases) → board
  byte-identical, path present, `movimientos == 1`, `ResultadoMovimiento` has **no** board delta,
  history holds a no-delta +1.
- ✅ `CeldaVacia` is transparent: ray flies over it without interacting.
- ✅ `Coleccionable` on a clear ray → not blocked, `ColeccionableRecogido` adds seconds; victory
  never requires it.
- ✅ Tap-any-order: tapping paths in arbitrary sequences resolves with no reachability error.
- ✅ Edge case: a path whose head is already adjacent to the edge with a clear ray → exits in one tap.
- ✅ Geometry: `Trayectoria` reports straight vs corner connections and the single head; a path
  segment chain is validated as contiguous (non-contiguous data fails loudly).
- ✅ Full coverage + solvability: the demo board covers every cell at start and a greedy sequence
  of valid moves empties it.

### 7.3 Win / lose / session (DM-F5)

- ✅ Last arrow exits → `EstadoVictoria`, `Victoria` event, final `Puntaje`/`Estrellas` computed.
- ✅ Timed level: timer to 0 before clear → `EstadoDerrota`.
- ✅ Move-budget defeat: budget (`nFlechas + margen`) reaching 0 before clear → `EstadoDerrota`
  on **both** timed and untimed levels; clearing on the last allowed move → victory (victory
  wins ties). *(Supersedes the former "untimed level can never reach `EstadoDerrota`" test as of
  §12 / 2026-06-24.)*
- ✅ Undo cap: at most **3** undos per level; a 4th is a no-op; the counter resets per level; an
  undo restores one move-budget unit (counters never drift).
- ✅ `EstadoPausado`: taps rejected; timer frozen; resume returns to `EstadoJugando`.
- ✅ Undo reverses delta (or no-delta +1), decrements `movimientos`, keeps counters consistent.

### 7.4 Generation & solvability (DM-F3 / DM-F4 / DM-B1 / DM-B2)

- ✅ `GeneradorNivelBase.generar` always runs `validarSolvencia` (assert it cannot be bypassed; an
  injected unsolvable `poblar()` causes generation to fail, never render).
- ✅ Solver is **order-independent**: same verdict across shuffled removal orders (property test).
- ✅ Greedy completeness: known-solvable golden boards → `true`; known-unsolvable → `false`.
- ✅ **Backend gate:** `CrearNivel`/`ActualizarNivel` reject an unsolvable board → nothing persisted
  (assert repository never called).
- ✅ **Cross-repo golden agreement:** Dart and TS solvers return identical verdicts on every shared
  fixture (CI fails on drift — ADR-0001).

### 7.5 Scoring & stars (DM-F6)

- ✅ `Puntaje == max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo)` (timed).
- ✅ Untimed drops the time term; floor at 0 verified (large `movimientos` → 0, never negative).
- ✅ Strategy selection: timed→`PuntuacionMixta`, untimed→`PuntuacionPorMovimientos`; no
  `PuntuacionPorTiempo` exists.
- ✅ Stars: boundary tests at each of the three `umbralesEstrellas` (just below/at/above).
- ✅ **Agreement:** identical inputs → identical `{Puntaje, Estrellas}` on client and backend.

### 7.6 Observer & decorators (DM-F7 / DM-F9 / DM-B4)

- ✅ After a move, each registered `ObservadorJuego` receives the emitted events; the use case has
  **no** direct reference to audio/UI (verified via fakes/spies).
- ✅ Decorator stack: a use case wrapped by `DecoradorMetricas/Registro/Seguridad` still returns the
  same result; metrics/logging/security ports are invoked; **no logging/metrics library imported**
  in the decorator (static import assertion / dependency-direction lint).
- ✅ `DecoradorSeguridad` reads session via injected `ProveedorSesion`, never a static accessor.

### 7.7 Identity, sync, leaderboard (DM-B2 / DM-B3 / DM-B5)

- ✅ Register persists `User` (unique email enforced; duplicate → domain exception; password hashed).
- ✅ Progress sync: a batch persists atomically via `RepositorioProgreso.guardarLote` (`$transaction`
  inside the adapter); a mid-batch failure rolls back all (assert no partial rows).
- ✅ Application layer **never imports Prisma** (dependency-rule lint test, both repos).
- ✅ Leaderboard returns top-N per `(idNivel, limite)`; second call within TTL is served from
  `InterceptorCacheRanking` (DB query not re-issued — spy on the read port).
- ✅ Leaderboard is read-only: no client write path / no `RankingRepository.publicar` usage.

### 7.8 Contract & architecture guards

- ✅ Pact: every client↔server DTO (auth, level fetch, progress sync, ranking) has consumer +
  provider verification; CI fails on shape drift.
- ✅ **Domain purity:** automated check that `domain` imports no Flutter/Nest/Prisma/logging/metrics
  symbols (ADR-0004).
- ✅ Ubiquitous-language guard: lint/test forbids avoid-list identifiers (`CeldaSalida`,
  `*Decorator` cells, `Composite`, `NivelFacil/Medio/Dificil`, `PuntuacionPorTiempo`, plural
  `CargadorNiveles`).

---

## 8. Non-Functional Requirements

- **Performance:** a tap resolves and renders within one frame (≤ 16 ms target); raycast is O(path length).
- **Offline-first:** full play, generation, validation, and scoring work with no network; progress queues for sync.
- **Security:** hashed passwords; auth via guards; session through injected `ProveedorSesion` (no global token).
- **Portability/Extensibility (OCP):** 3D board, new generation/scoring strategies, and new cell
  types are additive (new `Tablero`/Strategy/Factory product) with no caller changes.
- **Observability:** transport metrics/logging at the HTTP edge; app-level metrics/logging via the
  Decorator stack — both off the domain.
- **CI quality gates:** ≥ 90% domain/application coverage, golden-board solver agreement, Pact,
  domain-purity and language-guard checks all green before merge.

---

## 9. Open Risks & Deliberate Deviations (defend, don't "fix")

1. **"Flechas rotables" rubric wording** (DIAGRAM-RECONCILIATION §6.1) conflicts with the Q1
   tap-to-shoot, no-rotation mechanic. This is an intentional divergence; have a one-sentence
   justification ready. Do **not** add rotation or edit the requirements text.
2. **One Singleton, not three** (ADR-0002): only `AudioServiceImp` is a GoF Singleton;
   `ConfiguracionManager`/session are DI-lifetime via injected ports. Intentional — defend, don't revert.
3. **No Unit of Work** (ADR-0003): atomicity from Prisma nested writes + adapter-scoped
   `$transaction`. Reintroduce a *correctly scoped* UoW only if a real cross-aggregate transaction appears.
4. **Two solver implementations** (Dart + TS) risk drift; mitigated by shared golden boards in both
   CIs (ADR-0001). Pact tests verify JSON shape, **not** solver agreement.
5. **`RankingRepository.publicar()`** (frontend) is dead weight under the read-only projection model
   — candidate for removal (keep `obtenerTop(...)`).

---

## 10. Out of Scope (MVP)

Arrow rotation; traveling-token movement; deadlock defeat; exit/target tiles; real-time
multiplayer; social features beyond the read-only leaderboard; cell decorators / Composite board
structure; difficulty subclasses.

---

## 11. Traceability Matrix (story → deep module → tests)

| Story | Deep module(s) | Tests (§7) |
|---|---|---|
| A1–A4 | DM-F1, DM-F2 | §7.2 |
| B1–B4 | DM-F5, DM-F2 | §7.3 |
| C1–C2 | DM-F3, DM-F4, DM-F9 | §7.4 |
| C3 | DM-B1, DM-B2 | §7.4 |
| D1–D3 | DM-F6 | §7.5 |
| E1 | DM-B2, DM-B3 | §7.7 |
| E2 | DM-B3 | §7.7 |
| E3 | DM-B5 | §7.7 |
| F1 | DM-F7, DM-F9, DM-B4 | §7.6 |
| (all) | DM-B6, DM-F8 | §7.8 |

---

## 12. Enhancement Batch 2 — New Requirements (2026-06-24)

> A second batch of product requirements, integrated into the sections above and decomposed into
> tickets (`arrowmaze-frontend/.issues/22…30`, `arrowmaze-backend/.issues/18`). Each item keeps
> the project's non-negotiables: **strict TDD** (§7), **Clean Architecture / MVVM** (§5,
> CLAUDE.md), the **ubiquitous language** (§4), and **solvability-before-render** (§1.4).

### 12.1 Gameplay & Session rules

1. **Path-following (snake-like) exit animation** *(FE-22, §1.4 rule 6)* — a resolving
   `Trayectoria` animates head-first along its own multi-cell path to the edge; tail segments
   follow the identical curve via Flutter animation controllers (arc-length tween). **Never** a
   rigid whole-shape slide. Purely presentational; decoupled from the (already atomic) rule.
12. **Move countdown & Game Over** *(FE-30, §3 B2/B5)* — the counter **counts down** from
    `presupuestoMovimientos = nFlechas + margen`; each tap (valid or invalid) decrements it;
    hitting 0 before clearing → **Game Over** (`EstadoDerrota`) on timed **and** untimed levels.
    **Deliberate invariant change:** the prior "untimed levels can never lose" rule (§3 B2, §7.3)
    is retired. Game Over reuses the GoF **State** `EstadoDerrota` — no ad-hoc state.
8.  **Undo cap = 3 per level** *(FE-30, §3 B4)* — undo is no longer unlimited; max 3 uses per
    level, control disabled afterwards, counter resets per level, each undo restores one
    move-budget unit.

### 12.2 Levels, Generation & Difficulty

2. **Aggressive difficulty scaling** *(FE-23)* — a steep, monotonic `PerfilDificultad` (data, not
   subclasses) grows grid size, arrow count, and **move budget** (FE-30) sharply; late levels are
   large, dense, and complex. **Raised baseline floor (2026-06-24):** the **minimum board size is
   7×7 from Level 1** — no level is smaller. Rationale: 5×5 grids could not legibly render shape
   masks (hearts, stars) and made early levels trivially easy; a 7×7 floor accommodates every shape
   in the repertoire and lifts the baseline cognitive load. The authored bands are raised
   accordingly (1–5 → 7×7, 6–10 → 8×8, 11–15 → 9×9; retrofit via FE-31), and the endless curve
   climbs aggressively from that floor. The difficulty curve is **orthogonal to board shape**
   (req 3): a given shape recurs at ever-higher difficulty.
3. **Endless in-app level generation with shape rotation** *(FE-23)* — past the authored catalog the
   app procedurally generates fresh, always-solvable levels indefinitely (offline-first), so
   difficulty scales **without app-store updates**. Generated levels are **never square-only**: a
   **fixed, ordered shape repertoire** — `Cuadrado, Corazón, Triángulo, Cruz, Estrella` — is applied
   as a board mask, selected **deterministically by rotating on the level index**
   (1→Cuadrado, 2→Corazón, 3→Triángulo, 4→Cruz, 5→Estrella, 6→Cuadrado, wrapping…). Shape
   (`RepertorioFormas.formaParaIndice`) and difficulty (`PerfilDificultad`) are **orthogonal axes**:
   shapes **repeat** as the player advances, but each recurrence sits at **strictly higher
   complexity** (grid, arrows, move budget) — complexity climbs *inside* the shape. The generator
   populates only in-mask cells (reusing FE-16's *absent* concept, no geometry re-derivation); the
   `validarSolvencia` template gate and arrow-length ≥ 2 invariant (FE-16) still cannot be bypassed.
6. **Irregular board shape rendering** *(FE-26 / FE-16, §1.4 rule 7)* — the Flutter UI renders
   non-rectangular (masked) boards the backend already serves: only playable cells are drawn and
   hit-tested; *absent* ≠ `CeldaVacia`.

### 12.3 Frontend UI / UX & Feedback

5.  **Softer SFX** *(FE-25)* — replace/retune sound effects to be softer and more pleasant; same
    Observer wiring (`TipoEvento → AudioServiceImp`); bounded polyphony so rapid repeats don't spam.
10. **Invalid-move feedback** *(FE-28, §3 A2)* — on tapping a blocked arrow the red alert fires
    **once per interaction** (debounced, no visual spam under rapid taps) **and** the device emits
    **haptic** vibration via an injected port (graceful where unavailable). Rule unchanged.
11. **15-second timer warning** *(FE-29)* — on timed levels, a distinct **visual + audio** warning
    fires **once** as the countdown crosses exactly 15 s (Observer-driven `AvisoTiempo`); never on
    untimed/bonus levels; resets per run.
9.  **Settings menu (post-login) + i18n** *(FE-27)* — a Settings button after login with **Sound
    (On/Off)** (mutes `AudioServiceImp`, no game-logic change) and **Language (English/Spanish)**
    via a real i18n implementation (no hard-coded UI strings). Both persist (`shared_preferences`,
    `ConfiguracionManager` DI-lifetime — ADR-0002) and apply on startup.

### 12.4 Backend & Cross-repo

4. **Progress state sync** *(FE-24 + BE-18)* —
   - *Back-navigation:* Level Select **re-reads progression on every appearance** (not only via
     "Next Level" after a win), so locks/stars are never stale.
   - *Login restore:* a new **`GET /progress`** endpoint (BE-18, JWT-guarded, read-only) returns
     the player's **best result per level**; the client calls it on login (FE-24), hydrates local
     progression (merge keeps the best), and restores previously unlocked levels instead of
     starting from scratch. The read path stays separate from the offline upload queue.
7. **High-score persistence (validated)** *(BE-18 + BE-13)* — the DB keeps only the player's
   **strictly-higher** score per `(jugador, nivel)` (BE-13's upsert + `@@unique`); BE-18 validates
   this **from the read side** (`GET /progress`/leaderboard surface only the single best row), and
   re-confirms server-side score recomputation (BE-05) agreement.

### 12.5 Traceability (req → ticket)

| Req | Summary | Ticket(s) |
|---|---|---|
| 1  | Path-following snake-like exit animation | FE-22 |
| 2  | Aggressive difficulty scaling | FE-23 |
| 3  | Endless in-app level generation + shape rotation | FE-23 (authored-catalog retrofit: FE-31) |
| 4  | Progress sync (back-nav refresh + login restore) | FE-24, BE-18 |
| 5  | Softer SFX | FE-25 |
| 6  | Irregular board shape rendering | FE-26 (FE-16, BE-14) |
| 7  | High-score rule (validated) | BE-18, BE-13 |
| 8  | Undo cap (3/level) | FE-30 |
| 9  | Settings menu (sound + EN/ES i18n) | FE-27 |
| 10 | Invalid-move single alert + haptics | FE-28 |
| 11 | 15-second timer warning | FE-29 |
| 12 | Move countdown + Game Over | FE-30 |

---

*End of PRD. Derived autonomously from `CONTEXT.md`, `DIAGRAM-RECONCILIATION.md`, and ADR-0001…0004.*
