# ArrowMaze — Game Domain

Shared ubiquitous language for the ArrowMaze clone, used by both the game client
(`arrowmaze-frontend`) and the backend API (`arrowmaze-backend`). This file is a
glossary only — no implementation details.

## Language

**Movimiento (Move)**:
A single player action: tapping any segment of an arrow `Trayectoria` makes the
whole path try to exit in its head's `Direccion`. If every cell along the head's
ray to the board edge is clear, the **entire path** exits and all of its cells
become empty (a *valid* move). If the head's ray hits any wall or other arrow, the
path retreats unchanged and the move is *invalid* (rejected). One tap produces
exactly one `ResultadoMovimiento`. There is no traveling token and no "stop in the
middle" — exit is all-or-nothing, and a path leaves as a whole, never cell-by-cell.
_Avoid_: rotación (arrows are never rotated), token, turno, deslizar una sola celda

**Flecha / Trayectoria (Arrow / Path)**:
An arrow is a **continuous, possibly bending path** of one or more orthogonally
adjacent cells (`Trayectoria`), with exactly one arrowhead at its head pointing in
one `Direccion` (the path's exit direction). The path may turn 90° at corners; it
is never rotated. Each cell it covers is a `CeldaFlecha` segment tagged with the
path's `idFlecha`; the whole path is removed together when it exits. A board starts
**fully covered** — every cell belongs to some path, so there are zero empty cells
until paths are resolved.
_Avoid_: rotable, dirección activable, flecha de una sola celda (a 1×1 arrow is just
the degenerate one-segment path), bloque cuadrado

**Movimiento inválido (Invalid move)**:
A tap whose ray is blocked by a wall or another arrow. The board is unchanged and the
arrow is not consumed, but it **does** increment `movimientos` — invalid taps are
deliberately penalized so the move count is a true skill signal. It still produces a
`ResultadoMovimiento` and is recorded in `CommandHistory` (a no-board-delta,
+1-counter command) so undo stays consistent.
_Avoid_: movimiento fallido, error

**Victoria (Victory)**:
Reached when every arrow has been removed and the board is empty.
_Avoid_: nivel completado (reserve for the event name), meta

**Tap any order**:
Every arrow on the board is tappable at any time, in any order. There is no player
position or reachability constraint.

**Derrota (Defeat)**:
Reached only when a level's `limiteTiempo` runs out. Levels without a time limit
cannot be lost. There is no deadlock-based defeat.
_Avoid_: game over, derrota por bloqueo

**Tablero (Board)**:
The play space, depended on by use cases and the solver only through a `Tablero` port
(`celdaEn`, `trayectoriaEn`, `raycast(origen, Direccion)`, `eliminarTrayectoria`). The
concrete implementation (`GrafoTablero`, mutated incrementally — removing a path
unlinks each of its nodes, never a full rebuild) is an implementation detail. The port is the OCP seam that lets a future 3D board be a new
implementation with no change to callers.
_Avoid_: grid (reserve for the visual layout), matriz

**Posicion / Vector3 (Position)**:
A dimension-agnostic coordinate; `Direccion` is a vector. 2D uses 4 directions, a
future 3D board 6, without changing the `Tablero` contract.

**Celda (Cell)**:
A board position. Exactly four kinds exist (produced by `FabricaCeldasEstandar`):
`CeldaFlecha`, `CeldaPared`, `CeldaVacia`, `Coleccionable`. A `CeldaFlecha` is one
**segment** of an arrow `Trayectoria` (tagged with its `idFlecha`), not a
standalone 1×1 arrow. There is no exit cell — victory is reaching a board edge, not
a target tile.
_Avoid_: CeldaSalida / ExitCell (removed — vestige of the maze-escape interpretation).
Cell variants are Factory products, not decorators — there are no cell decorators
(`CeldaColeccionableDecorator`, `CeldaBloqueadaDecorator` and `ComponenteTablero` /
`GrupoCeldas` Composite were removed). Decorator is used only on use cases.

**CeldaPared (Wall)**:
A static, permanent, blocking obstacle. Never removed; always stops a ray.

**CeldaVacia (Empty)**:
A fully transparent cell. Arrow rays fly over it without interacting.

**Coleccionable (Collectible)**:
An optional, transparent bonus element. It never blocks a ray and is never required
for victory. It is collected automatically by pass-through when a *valid* move's ray
crosses its cell, and its effect is to add seconds to the level timer.
_Avoid_: power-up, ítem

**Nivel (Level)**:
A single, data-driven entity carrying a `Dificultad` (enum) and a `DefinicionNivel`.
Difficulty is content (board size/shape, arrow & wall layout, `limiteTiempo`, scoring
constants, star thresholds), never a subtype.
_Avoid_: NivelFacil / NivelMedio / NivelDificil (removed — difficulty is data, not a
type hierarchy)

**Generación de nivel (Level generation)**:
Selecting a generator is a Strategy (`EstrategiaGeneracionNivel`); the shared skeleton
is a Template Method on `GeneradorNivelBase`: `crearTableroVacío → poblar() (the only
overridable hook) → validarSolvencia → entregar`. `GeneracionAleatoriaNivel` and
`GeneracionPorArchivoNivel` override only `poblar()`; `validarSolvencia` cannot be
skipped, so every client-generated board is proven solvable before render.

**CargadorNivel (Level loader)**:
The port (interface, application-owned) that loads a single level definition by id.
`GeneracionPorArchivoNivel` depends on this port, never on a concrete loader; the
concretes (bundled-asset, backend-served) are infrastructure adapters. A distinct
`CatalogoNiveles` port covers list/catalog loading if that need is real — the loader is
single-level only.
_Avoid_: CargadorNiveles (plural — was diagram drift; "load one level" is `CargadorNivel`,
"load the catalog" is `CatalogoNiveles`). `CargadorNivel` is never a concrete `«Service»`
a strategy depends on.

**Movimientos (Move count)**:
The count of taps the player has made on a level — both valid and invalid taps count.
Lower is better and feeds scoring.

**Puntaje (Score)**:
`max(0, baseNivel − movimientos·Kmov + segundosRestantes·Ktiempo)`. The time term is
dropped on untimed levels. `baseNivel`, `Kmov`, `Ktiempo` live in `DefinicionNivel`
so scoring is tuned as data (OCP).
_Avoid_: puntuación cruda, score

**EstrategiaPuntuacion (Scoring strategy)**:
The scoring algorithm, selected at runtime by whether the level has a `limiteTiempo`.
Exactly two live strategies exist: `PuntuacionPorMovimientos` (untimed) and
`PuntuacionMixta` (timed). `PuntuacionPorTiempo` was removed as dead code.

**Estrellas (Stars)**:
A 1–3 rating derived purely from `Puntaje` against three thresholds stored in
`DefinicionNivel`. `CalcularPuntuacionUseCase` returns both `Puntaje` and `Estrellas`
so client and backend always agree.

**Solvencia (Solvability)**:
A board is solvable if some sequence of valid moves empties it. Two invariants hold:
(1) solvability is independent of tap order — the player can never make a solvable
board unsolvable, since removals only clear cells; (2) a greedy check (repeatedly
remove any arrow with a clear ray; succeed iff the board empties) is a complete,
polynomial decision procedure — no backtracking needed. Every board must be proven
solvable before it is shown to the player.
_Avoid_: nivel válido, factibilidad

**EventoJuego (Game event)**:
A value object describing something that happened during play — typed by `TipoEvento`
(e.g. `MovimientoRealizado`, `FlechaEliminada`, `ColeccionableRecogido`, `Victoria`,
`PuntajeActualizado`). A move produces a `List<EventoJuego>` on its result. Events are a
record of what occurred, never a command telling a layer what to do.
_Avoid_: mensaje, comando

**PublicadorEventosJuego (Game-event Subject) / ObservadorJuego (Observer)**:
The real GoF Observer. After a move, the `PublicadorEventosJuego` (Subject) dispatches
each `EventoJuego` from the result to registered `ObservadorJuego`s. Concrete observers
react without the use case knowing them: the audio service plays sounds, the score and
HUD view models update. This keeps reactions decoupled from the domain — a use case
emits events, it never calls audio or UI directly.
_Avoid_: calling MVVM `notifyListeners()` "the Observer" — that is View↔ViewModel data
binding, a separate mechanism, not the game-event Subject.

**EstadoSesion (Session state)**:
The GoF State pattern. `SesionJuego` holds an `EstadoSesion` and delegates behaviour to it,
switching via `cambiarEstado(...)`. The concrete states are exactly four: `EstadoJugando`,
`EstadoPausado`, `EstadoVictoria`, `EstadoDerrota`. This — not any MVVM view model — is the
State pattern: when asked "where is State", point here.
_Avoid_: confusing it with the MVVM view-state classes (`JuegoViewState`, `VictoriaViewState`,
`TableroUI`, `CeldaUI`, …). Those are immutable UI snapshots (`copyWith`), not the GoF State;
in particular `VictoriaViewState` (UI) is not `EstadoVictoria` (the session state).
