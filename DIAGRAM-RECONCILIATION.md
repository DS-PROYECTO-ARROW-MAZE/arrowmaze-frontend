# ArrowMaze — Diagram Reconciliation Checklist

Brings the Lucidchart **ARROWMAZE** doc (id `b5803118-add6-4eb7-b210-35363ea1af77`) into
agreement with the architecture decisions Q1–Q18 (see `CONTEXT.md` and `arrowmaze-backend/docs/adr/`).
Every item below says **exactly** what class/interface/method/relationship to add, delete,
rename, or retype. Action this in Lucid yourself — nothing here edits the chart.

## How the document is laid out (the duplication trap)

The class detail is repeated across pages. **Apply each change in every place it appears:**

| Page | Content | A change here also lives on… |
|---|---|---|
| **P1** | BACKEND | P3 r4 (backend copy) |
| **P2** | FRONTEND | P3 r5 / r7 / r8 (frontend copy), P4 (extra frontend detail) |
| **P3 r1** | Requirements text (PDF copy) | — (don't edit; see Caveats) |

So: **frontend change → P2 + P3 r5/r7/r8 + P4**; **backend change → P1 + P3 r4**.

## UML relationship vocabulary used below

- **realizes** (`..|>`, dashed + hollow triangle): a class implements an «interface».
- **extends** (`--|>`, solid + hollow triangle): a class generalizes an «Abstract» base.
- **has / association** (`-->`): the source holds the target as a field.
- **uses / dependency** (`..>`, dashed arrow): the source references the target in a method
  signature or transiently, without holding it.

---

## 1. DELETE — elements that contradict decisions

### 1.1 Frontend (P2 + P3 r5/r7/r8 + P4)

1. **`CeldaSalida` «Modelo»** — *Q3, no exit cell.*
   Delete the box and every relationship into it (any `Tablero`/factory reference).
2. **`CeldaDecorator` «Abstract»** — *Q8, no cell decorators.*
   Delete the box; delete its `# celda: Celda` field and the `realizes Celda` /
   `has Celda` (wrapped-cell) relationships.
3. **`CeldaBloqueadaDecorator`** — *Q8.* Delete box + methods `esTransitable(): bool`,
   `desbloquear(): Celda`, and its `extends CeldaDecorator` relationship.
4. **`CeldaColeccionableDecorator`** — *Q8.* Delete box + methods
   `obtenerColeccionable(): Coleccionable`, `recolectar(): Celda`, the field
   `- coleccionable: Coleccionable`, and its `extends CeldaDecorator` relationship.
   (The `Coleccionable` model itself is **kept** — re-wired in §4.1.)
5. **`ComponenteTablero` «interface»** — *Q8, no Composite.* Delete box + members
   `hijos: List<ComponenteTablero>`, `agregar(c)`, `remover(c)`, `totalCeldas()`,
   `recorrer(): List<Celda>` and all realizes/association arrows into it.
6. **`GrupoCeldas`** — *Q8.* Delete box and its `realizes ComponenteTablero` relationship.
7. **`NivelFacil`, `NivelMedio`, `NivelDificil` «Modelo»** — *Q11, difficulty is data.*
   Delete all three boxes and their `extends`/generalization arrows to the abstract `Nivel`
   base (the base itself is collapsed in §2).
8. **`PuntuacionPorTiempo`** — *Q9, dead strategy.* Delete box + its
   `realizes EstrategiaPuntuacion` relationship. (Keep `PuntuacionPorMovimientos` and
   `PuntuacionMixta`.)

### 1.2 Backend (P1 + P3 r4)

9. **`IUnidadDeTrabajo` «interface»** and **`UnidadDeTrabajoPrisma` «adapter»** — *Q15 / ADR-0003.*
   Delete both boxes and the `realizes` arrow between them.

### 1.3 Field-level removals

- **`Tablero` «Modelo»**: delete the field `- estructura: GrupoCeldas` (keep `- grafo: GrafoTablero`). — *Q8*
- **Every backend use case** holding `- unidadDeTrabajo: IUnidadDeTrabajo` — remove that field
  and the association arrow to the (now deleted) UoW. Confirmed on:
  `RegistrarJugadorCasoDeUso`, `CrearNivelCasoDeUso`, `ActualizarNivelCasoDeUso`
  (scan P1/P3 r4 for any others). — *Q15*

---

## 2. COLLAPSE — the abstract `Nivel` Template Method (Q11)

The abstract `Nivel` base carried `+ iniciar(): Tablero`, `# construirTablero(): Tablero`,
`# tieneLimiteTiempo(): bool`, `# evaluarDerrota(sesion: SesionJuego): bool` to support the
three difficulty subclasses. Difficulty is now data, so:

1. **Delete** the abstract base and (already in §1.1.7) its subclasses.
2. **Create one concrete `Nivel` «Modelo»** with fields:
   - `+ id: IdNivel`
   - `+ dificultad: Dificultad`  *(enum — value, not subtype)*
   - `+ definicion: DefinicionNivel`
3. **Relocate the runtime hooks** (they are not generation logic):
   - `evaluarDerrota(sesion): bool` → method on **`EvaluadorFinJuego`** (pure Layer-1).
   - `tieneLimiteTiempo(): bool` → a read on **`DefinicionNivel`**.
   - `construirTablero(): Tablero` → **`ConstructorTablero`** (Builder, already present).
4. The Template Method itself reappears in generation as **`GeneradorNivelBase`** (§4.2).

---

## 3. RENAME / RE-STEREOTYPE

### 3.1 Singletons (Q12 / ADR-0002)

- **`AudioServiceImp`** — **KEEP** `«Service» «Adapter» «Singleton»`. This is the single
  showcase GoF Singleton (private ctor + static accessor). No change.
- **`ConfiguracionManager`** —
  - Remove the `«Singleton»` stereotype.
  - Delete field `- _instancia: ConfiguracionManager` and method `+ instancia(): ConfiguracionManager`.
  - Tag it as DI-injected (singleton *lifetime* via the `Inyector`), not a static global.
  - Change field `- _cargador: CargadorNiveles` → `- _cargador: CargadorNivel` (§3.2).
- **`SesionManager`** — replace with a port:
  - Create **`ProveedorSesion` «interface»** with methods `obtenerToken(): TokenDto`,
    `guardarToken(t: TokenDto): void`, `cerrarSesion(): void`.
  - Create impl **`ProveedorSesionImpl`** that `realizes ProveedorSesion` (holds `_token: TokenDto`).
  - Delete the old `SesionManager` box (its `«Singleton»`, `_instancia`, `instancia()`).
  - Re-point **`DecoradorSeguridadUseCase`**: replace any `SesionManager.instancia()` use with
    an injected field `- _sesion: ProveedorSesion` (dependency `..> ProveedorSesion`, not a global).

### 3.2 Level loader (Q13)

- **`CargadorNivel`** — change stereotype **«Service» → «interface»**. Methods:
  `+ cargar(ruta: String): Future<DefinicionNivelDto>`.
- Add infra adapter **`CargadorNivelArchivo`** (`realizes CargadorNivel`, bundled asset).
  Optionally **`CargadorNivelHttp`** for the backend-served path.
- **`GeneracionPorArchivoNivel`**: field `- _cargador: CargadorNivel` typed to the interface;
  relationship `..> CargadorNivel` (dependency on the port, never a concrete).
- Fix the plural drift everywhere: `CargadorNiveles` → `CargadorNivel`. Only introduce a
  separate `CatalogoNiveles` port if a list-loading need is real.

### 3.3 "State" disambiguation (GoF State showcase confirmed)

- **KEEP as the GoF State pattern** (this is the answer to "show me State"):
  - `EstadoSesion` «interface» with `tocarCelda(pos): ResultadoMovimiento`, `pausar()`,
    `reanudar()`, `cambiarEstado(e: EstadoSesion)`, `estaTerminada(): bool`.
  - Concrete states `EstadoJugando`, `EstadoPausado`, `EstadoVictoria`, `EstadoDerrota`,
    each `realizes EstadoSesion`.
  - `SesionJuego` holds `- estado: EstadoSesion` and switches via `cambiarEstado(...)`.
- **Rename the MVVM view-state classes** so they don't read as the pattern (drop the
  `«State»` stereotype; rename where it collides):
  - `JuegoState → JuegoViewState`
  - `VictoriaState → VictoriaViewState`  *(critical: collides with GoF `EstadoVictoria`)*
  - `SeleccionNivelState → SeleccionNivelViewState`
  - `TableroUI`, `CeldaUI`, `NivelResumenUI`: keep names, just remove the `«State»` stereotype
    (mark them `«ViewState»` or `«MVVM»` if you want an explicit tag).

---

## 4. ADD — required elements currently missing

### 4.1 `Coleccionable` becomes a cell (Q8)

Re-wire the existing `Coleccionable` «Modelo» into one of the four Factory cell products:
- `Coleccionable` **realizes `Celda`** and **realizes `Interactuable`** (NOT `Colisionable`).
- Methods: `tipo(): TipoCelda`, `esTransitable(): bool` *(true — transparent)*,
  `estaOcupada(): bool`, `interactuar(): EventoJuego` *(returns a `ColeccionableRecogido`
  event, adds seconds to the timer)*.
- It is produced by `FabricaCeldasEstandar.crear(tipo, datos)` like the other three cells.
- This is also a clean ISP example: a wall realizes `Colisionable` but not `Interactuable`;
  a collectible realizes `Interactuable` but not `Colisionable`.

### 4.2 `GeneradorNivelBase` Template Method (Q11)

- Create **`GeneradorNivelBase` «Abstract»** that **realizes `EstrategiaGeneracionNivel`**.
- Public template (final, not overridable): `generar(config: ConfigGeneracion): DefinicionNivel`
  implemented as the fixed skeleton:
  `crearTableroVacío() → poblar() → validarSolvencia() → entregar()`.
- Hooks: `# poblar(): void` is the **only** abstract/overridable step;
  `# crearTableroVacío()`, `# validarSolvencia()`, `# entregar()` are concrete in the base.
- **`GeneracionAleatoriaNivel`** and **`GeneracionPorArchivoNivel`** now **extend
  `GeneradorNivelBase`** (generalization) and override only `poblar()`. `validarSolvencia`
  cannot be skipped — every client-generated board is proven solvable before render.

### 4.3 Real Observer (Q14)

- Create **`PublicadorEventosJuego`** (the Subject): `suscribir(o: ObservadorJuego)`,
  `desuscribir(o: ObservadorJuego)`, `publicar(evento: EventoJuego)`. Holds
  `- _observadores: List<ObservadorJuego>`.
- Create **`ObservadorJuego` «interface»**: `alOcurrirEvento(evento: EventoJuego): void`.
- Concrete observers, each `realizes ObservadorJuego`:
  - `AudioServiceImp` (plays sound on `FlechaEliminada` / `Victoria`),
  - the score ViewModel (reacts to `PuntajeActualizado`),
  - the HUD/board ViewModel (reacts to `MovimientoRealizado`).
- `EventoJuego` «Modelo»: add discriminator `+ tipo: TipoEvento` (enum:
  `MovimientoRealizado`, `FlechaEliminada`, `ColeccionableRecogido`, `Victoria`,
  `PuntajeActualizado`). Keep it a pure value object.
- Wiring: after a move, the use case feeds `resultado.eventos: List<EventoJuego>` to
  `PublicadorEventosJuego.publicar(...)`; the use case has a dependency `..> PublicadorEventosJuego`
  and does **not** reference audio/UI directly.

### 4.4 Backend use-case Decorator stack (Q17 / ADR-0004)

Mirror the frontend Decorator stack on the backend so app-level cross-cutting is the same
pattern on both repos (P1 + P3 r4):
- **`DecoradorCasoDeUso<E,S>` «Abstract»** that **realizes `ICasoDeUso<E,S>`** and holds the
  wrapped `- _interno: ICasoDeUso<E,S>` (association to the interface — Decorator).
- **`DecoradorMetricasCasoDeUso`**, **`DecoradorRegistroCasoDeUso`**,
  **`DecoradorSeguridadCasoDeUso`**, each **extends `DecoradorCasoDeUso`**.
- These depend on **ports**, never libraries:
  `DecoradorRegistroCasoDeUso ..> IRegistro`, `DecoradorMetricasCasoDeUso ..> IMedidorMetricas`,
  `DecoradorSeguridadCasoDeUso ..> ProveedorSesion`.
- Add the ports `IRegistro` «interface» and `IMedidorMetricas` «interface», each realized by an
  infrastructure adapter (e.g. `RegistroConsola`, `MedidorMetricasSimple`).

### 4.5 Backend leaderboard cache aspect (Q16)

- Add **`InterceptorCacheRanking` «aspecto»** beside `InterceptorLogging` / `InterceptorMetricas`.
  It wraps the ranking read; TTL ~60s keyed by `(idNivel, limite)`.
- Keep `IConsultaRanking` / `ConsultaRankingPrisma` (CQRS-lite read port) unchanged.

### 4.6 `Tablero` as a port (Q11)

- Convert **`Tablero` «Modelo» → `Tablero` «interface»** (the OCP seam). Methods:
  `celdaEn(pos: Posicion): Celda`, `raycast(origen: Posicion, dir: Direccion): ResultadoRaycast`.
- **`GrafoTablero`** now **realizes `Tablero`** (the graph is an implementation detail, mutated
  incrementally). `GrafoTablero`/`Nodo` are not exposed to callers — use cases and the solver
  depend on `Tablero` only (`..> Tablero`).
- `DetectorColisiones.detectar(...)` may delegate to `tablero.raycast(...)`.

---

## 5. MODIFY fields

- **`DefinicionNivel` / `DefinicionTablero`**: add scoring constants `+ baseNivel: int`,
  `+ Kmov: int`, `+ Ktiempo: int`, and star thresholds `+ umbralesEstrellas: List<int>` (the
  three puntaje cutoffs). — *Q9.* (`Estrellas` value object already exists — keep.)
- **`EstrategiaPuntuacion`**: keep the «interface» + `PuntuacionPorMovimientos` +
  `PuntuacionMixta`; annotate the selector note as **timed vs untimed**. — *Q9*
- **`CalcularPuntuacionUseCase`**: returns both `Puntaje` and `Estrellas`. — *Q9*
- **Backend `InterceptorMetricas` / `InterceptorLogging`**: relabel scope to **transport-level**
  (HTTP access logging, request metrics). Use-case-level metrics/logging/security now live in
  the Decorator stack (§4.4). — *Q17*

---

## 6. Caveats — confirm before the defense (NOT diagram cleanup)

1. **⚠️ "flechas rotables".** P3 r1 requirements text says *"…tablero en cuadrícula, **flechas
   rotables**…"* (rotatable arrows), which conflicts with the Q1 mechanic (tap → shoot, no
   rotation). This is a deliberate divergence from the literal rubric wording and the most
   likely examiner challenge. Have a one-sentence justification ready, or reconsider Q1. Do
   **not** edit the requirements text.
2. **Backend `IPublicadorEventos`** (P1) is the backend's own domain-event publisher (e.g.
   player registered) — **keep it**; it is distinct from the new frontend `PublicadorEventosJuego`.
3. **`RankingRepository.publicar()`** (frontend) is dead weight under Q18's projection model
   (the leaderboard is a read-only projection over synced progress). Optional: drop `publicar()`
   and keep `obtenerTop(...)` only.

---

## 7. Quick pattern → "where do I point" crib (for the defense)

| Pattern | Where it lives after reconciliation |
|---|---|
| Singleton | `AudioServiceImp` (the one showcase) |
| Strategy | `EstrategiaGeneracionNivel` (generation), `EstrategiaPuntuacion` (scoring) |
| Template Method | `GeneradorNivelBase.generar()` (hook: `poblar()`) |
| Factory | `FabricaCeldas` / `FabricaCeldasEstandar` (4 cell products) |
| Builder | `ConstructorTablero` |
| Decorator | use-case stack `DecoradorMetricas/Registro/SeguridadCasoDeUso` (both repos) |
| Observer | `PublicadorEventosJuego` + `ObservadorJuego` (frontend); `IPublicadorEventos` (backend) |
| Command | `Command0`/`Command1`, `DeshacerMovimientoUseCase` (frontend only) |
| State | `EstadoSesion` + `EstadoJugando/Pausado/Victoria/Derrota` |
| Repository | `IRepositorioJugador/Nivel`, `ProgresoRepository`, `RankingRepository` |
| Adapter | `*Prisma` adapters, `CargadorNivelArchivo`, `AudioServiceImp` |
| ISP | `Celda` / `Colisionable` / `Interactuable` segregation |
| DIP | use cases depend on ports (`Tablero`, `CargadorNivel`, `ProveedorSesion`, `IConsultaRanking`) |

---

## 8. Continuous, bending-path paradigm shift (FRONTEND-01 refactor)

**Context.** The move mechanic changed from *one arrow = one 1×1 cell* to *one arrow = a
continuous, possibly bending multi-cell path* (`Trayectoria`) with a single arrowhead at its
head, on a board that is **fully covered** at start (zero empty cells). A move resolves the
**whole path** when the head's ray is clear to the edge. This section says exactly what to
add/modify in the Lucid **ARROWMAZE** doc so the diagrams match the code. Apply each frontend
change in every place the class appears: **P2 + P3 r5/r7/r8 + P4** (see §How the document is
laid out). Backend (P1/P3 r4) is **unaffected** — the contract/DTO surface did not change.

### 8.1 ADD — `Trayectoria` «Modelo» (the new core entity)

Create **`Trayectoria` «Modelo»** in the frontend domain package, next to `Celda`:
- Fields: `+ id: int`, `+ segmentos: List<Posicion>` *(ordered tail → head)*,
  `+ direccionCabeza: Direccion`.
- Methods: `+ cabeza(): Posicion`, `+ cola(): Posicion`, `+ esCabeza(p: Posicion): bool`,
  `+ conexionesEn(p: Posicion): Set<Direccion>` *(straight vs corner geometry for the renderer)*,
  `+ contiene(p: Posicion): bool`. Constructor validates contiguity (throws on non-adjacent cells).
- Relationships:
  - `Trayectoria --> Posicion` (has many, the segments) and `Trayectoria --> Direccion` (has, head dir).
  - `Tablero ..> Trayectoria` (the port returns it — §8.3) and `MoverFlechaUseCase ..> Trayectoria`.
  - `GrafoTablero --> Trayectoria` (association: holds the `idFlecha → Trayectoria` index).

### 8.2 MODIFY — `CeldaFlecha` becomes a path **segment**

- Add field **`+ idFlecha: int`** to `CeldaFlecha` (links the segment to its owning `Trayectoria`).
- Keep `+ direccion: Direccion` (now documented as the *path's exit direction*, shared by every
  segment of the path) and `bloqueaRayo(): bool = true`.
- Update the note on `CeldaFlecha`: "one segment of a `Trayectoria`, not a standalone 1×1 arrow."
- No change to `CeldaPared` / `CeldaVacia` / `Coleccionable`.

### 8.3 MODIFY — `Tablero` «interface» (port) gains two members

Extend the port from §4.6 (it is still the OCP seam, still realized by `GrafoTablero`):
- Add `+ trayectoriaEn(pos: Posicion): Trayectoria?` *(the path covering a cell, or null)*.
- **Rename/replace** the old single-cell removal `eliminarFlecha(pos: Posicion)` →
  `+ eliminarTrayectoria(idFlecha: int): void` *(removes every segment of a path)*.
- Keep `celdaEn(pos): Celda` and `raycast(origen, dir): ResultadoRaycast`.
- `GrafoTablero` realizes all four; it now also holds `- _trayectorias: Map<int, Trayectoria>` and
  still mutates incrementally (each removed segment unlinks its `Nodo`; no full rebuild).

### 8.4 MODIFY — `FabricaCeldasEstandar` (Factory) gains a second product

The factory now produces **two** shapes, so the "4 cell products" crib (row 247 / §7) should read
"fixed cells + arrow paths":
- Keep `+ crear(json): Celda` but restrict it to fixed cells (`wall`, `empty`); `arrow` is no
  longer a single-cell product.
- Add `+ crearTrayectoria(json): Trayectoria` *(builds a whole path from `{id, head, cells[]}`)*.
- Relationship: `FabricaCeldasEstandar ..> Trayectoria` (creates) in addition to `..> Celda`.

### 8.5 MODIFY — MVVM render model (`CeldaUI`) carries path geometry

On the frontend MVVM detail (P2 / P4), extend **`CeldaUI` «ViewState»** so the `CustomPainter`
can draw continuous bending paths instead of tiles:
- Add `+ idFlecha: int?` *(colour selection)*, `+ conexiones: Set<Direccion>` *(straight/corner)*,
  `+ esCabeza: bool` *(where the single arrowhead is drawn)*; keep `+ direccion: Direccion?`.
- `TableroUI` is unchanged in shape (still `filas/columnas/celdas`).
- Add a `«ViewState»`/painter note: the board view is a `CustomPainter`, **not** a grid of
  per-cell widgets/tiles — empties render as dots, paths as one continuous stroke + arrowhead.
- `GameTheme` gains `+ arrowPalette: List<Color>` and `+ emptyDot: Color` tokens (theme, not domain).

### 8.6 Entity-relationship deltas (summary)

- **NEW** `Trayectoria 1 —— * Posicion` (segments, ordered) and `Trayectoria * —— 1 Direccion`.
- **NEW** `Trayectoria 1 —— * CeldaFlecha` *(conceptual: one path owns many segment cells, linked by
  `idFlecha`; model it as a note or a dependency, since the cells live in the `GrafoTablero` graph)*.
- **CHANGED** `GrafoTablero 1 —— * Trayectoria` (the path index) replaces any "arrow = single cell"
  reading.

### 8.7 State machine / sequence — **no structural change**

`EstadoSesion` (GoF State: `EstadoJugando/Pausado/Victoria/Derrota`) is **unchanged** — the legality
of a tap and session lifecycle are identical. Only the *move sequence* inside `EstadoJugando` differs;
update any move **sequence diagram** to the new flow:
`View.onTap(pos) → ViewModel.tocar(pos) → MoverFlechaUseCase.ejecutar(pos)
→ Tablero.trayectoriaEn(pos) → Tablero.raycast(traj.cabeza, traj.direccionCabeza)
→ Tablero.eliminarTrayectoria(traj.id) → ResultadoMovimiento{FlechaEliminada, MovimientoRealizado}`.
`Victoria` still fires when the board is empty; `Solvencia` (greedy, order-independent) is intact
because removing a whole path only clears cells.

### 8.8 Caveats

- The §6.1 "flechas rotables" caveat is **reinforced**, not resolved: paths are still never rotated
  (they bend by authoring, not by player action). Keep the existing one-sentence justification.
- Backend diagrams, DTO contracts and Pact tests are untouched: the path model is a client-side
  domain/representation change. If level **definitions** are later served with path data, revisit
  `DefinicionNivelDto` / `CargadorNivel` then (out of scope for FRONTEND-01).
