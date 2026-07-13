import '../../domain/value_objects/direccion.dart';
import '../../domain/value_objects/posicion.dart';

/// The visual kind of a board cell, decoupled from the domain `Celda` types so
/// the View never imports the domain hierarchy.
enum TipoCeldaUI {
  /// A cell covered by a segment of an arrow path.
  flecha,

  /// A blocking wall.
  pared,

  /// Transparent empty space (drawn as a subtle dot).
  vacia,

  /// A bonus collectible (transparent to rays, grants timer seconds).
  coleccionable,

  /// An absent position — outside the playable region of a shaped board.
  /// Not rendered and not hit-testable.
  ausente,
}

/// An immutable UI snapshot of one cell.
///
/// This is a render model (not the GoF State and not a domain entity): a flat,
/// theme-free description the `GameView` paints with `GameTheme` tokens. For a
/// [TipoCeldaUI.flecha] cell it also carries the geometry the painter needs to
/// draw a *continuous, bending* path: [conexiones] are the directions toward the
/// connected path neighbours (so the painter knows whether this segment is a
/// straight or a corner), [esCabeza] marks where the single arrowhead is drawn,
/// and [idFlecha] selects the path's colour.
class CeldaUI {
  /// Creates a cell snapshot.
  const CeldaUI({
    required this.posicion,
    required this.tipo,
    this.idFlecha,
    this.conexiones = const <Direccion>{},
    this.esCabeza = false,
    this.direccion,
  });

  /// Where the cell sits.
  final Posicion posicion;

  /// What to draw.
  final TipoCeldaUI tipo;

  /// For a path segment, the id of the owning path (used to pick its colour).
  final int? idFlecha;

  /// For a path segment, the directions toward its connected neighbours: one for
  /// an endpoint, two for a middle segment (a corner when perpendicular).
  final Set<Direccion> conexiones;

  /// Whether this segment is the head, where the arrowhead is drawn.
  final bool esCabeza;

  /// For the head segment, which way the arrowhead points; otherwise `null`.
  final Direccion? direccion;

  /// Whether this cell belongs to the board's **playable region** — the single
  /// named concept that threads the model's absent-mask into the View (ticket
  /// 26). It is `false` only for [TipoCeldaUI.ausente] positions, which sit
  /// outside a shaped board: the painter draws nothing for them and hit-testing
  /// ignores them. Every other kind — including a transparent [TipoCeldaUI.vacia]
  /// cell — is playable (present), so "absent ≠ empty" (AC2) is one comparison,
  /// not a scattered null check.
  bool get esJugable => tipo != TipoCeldaUI.ausente;
}

/// An immutable UI snapshot of the whole board — every cell of every depth
/// layer (`filas × columnas × profundo`), not just one layer's slice: the
/// rotatable 3D cube view renders and hit-tests the whole board at once.
/// [profundo] is `1` for a flat 2D board, in which case this holds exactly
/// `filas × columnas` cells and behaves exactly as a flat board always has.
class TableroUI {
  /// Creates a board snapshot of [filas] × [columnas] × [profundo] holding
  /// [celdas].
  const TableroUI({
    required this.filas,
    required this.columnas,
    required this.celdas,
    this.profundo = 1,
  });

  /// Row count.
  final int filas;

  /// Column count.
  final int columnas;

  /// Depth layer count; `1` for a flat 2D board.
  final int profundo;

  /// All cells, one per `(fila, columna, capa)`.
  final List<CeldaUI> celdas;

  /// The cell snapshot at the exact [posicion] (including `capa`).
  CeldaUI celdaEn(Posicion posicion) =>
      celdas.firstWhere((c) => c.posicion == posicion);

  /// The board's **hit-test seam**: resolves a tapped [posicion] to the
  /// playable cell there, or `null` when the tap lands off the board or on an
  /// absent (non-playable) position (ticket 26, AC4).
  ///
  /// The View maps a touch point to a grid position (a flat 2D tap, or a
  /// resolved cell from the 3D cube's projection hit-test — ticket 36) and
  /// asks here whether it owns a playable cell — a tap on the void outside a
  /// shaped board resolves to nothing (no hit-test target), while a present
  /// [TipoCeldaUI.vacia] cell resolves normally. Because "playable" is read
  /// straight from [CeldaUI.esJugable], the View never re-derives which cells
  /// exist (AC5).
  CeldaUI? celdaJugableEn(Posicion posicion) {
    if (posicion.fila < 0 ||
        posicion.columna < 0 ||
        posicion.capa < 0 ||
        posicion.fila >= filas ||
        posicion.columna >= columnas ||
        posicion.capa >= profundo) {
      return null;
    }
    final celda = celdaEn(posicion);
    return celda.esJugable ? celda : null;
  }
}

/// The UI snapshot shown when the player wins — a **presentation** view state,
/// deliberately **not** the domain `EstadoVictoria` (DM-F8 naming guardrail).
///
/// The session's GoF State (`EstadoVictoria`) lives in the domain and drives the
/// rules; this immutable snapshot is what the victory overlay renders, and it
/// never leaks the domain type into the View (nor the reverse). It carries the
/// final HUD figures plus the scoring result (`puntaje` and `estrellas`) from
/// [CalcularPuntuacionUseCase] (ticket 06). For bonus levels
/// [mostrarPuntuacion] is `false`, so the overlay omits the score/stars section
/// without the View branching on level type.
class VictoriaViewState {
  /// Creates the victory snapshot with the final [movimientos] count and the
  /// computed [puntaje] and [estrellas]. Set [mostrarPuntuacion] to `false`
  /// for bonus-level clears where score/stars are suppressed.
  const VictoriaViewState({
    required this.movimientos,
    this.puntaje = 0,
    this.estrellas = 0,
    this.mostrarPuntuacion = true,
  });

  /// The move count the level was cleared in.
  final int movimientos;

  /// The computed score (floored at 0, from the scoring strategy).
  final int puntaje;

  /// The star rating: 0, 1, 2, or 3, determined by level thresholds.
  final int estrellas;

  /// Whether the overlay should display the score and star rating.
  /// `false` for bonus levels (Ticket 18), which carry no score/stars.
  final bool mostrarPuntuacion;
}

/// A transient descriptor of an arrow **exiting** the board, emitted for the one
/// state that a valid `FlechaEliminada` produces and cleared on the next.
///
/// The domain already removed the path atomically (the board snapshot on the
/// same state shows it gone); this descriptor is *purely visual* — it tells the
/// View which cells left, in order, and where they head so it can play the
/// snake-gait exit over time. It carries the ordered exiting cells (tail → head),
/// the head's exit [direccionSalida] and an off-board [objetivoBorde] the head
/// travels to. Because it rides only on the emitting state, a later state (with
/// no descriptor) means the animation input is spent — the running controller,
/// not this snapshot, owns the in-flight animation (rule/animation decoupling,
/// AC3).
class AnimacionSalida {
  /// Creates an exit descriptor for path [idFlecha] made of [segmentos]
  /// (tail → head), exiting along [direccionSalida] toward [objetivoBorde].
  const AnimacionSalida({
    required this.idFlecha,
    required this.segmentos,
    required this.direccionSalida,
    required this.objetivoBorde,
  });

  /// The id of the path that left — selects its colour when the View paints the
  /// exiting body.
  final int idFlecha;

  /// The exiting cells in order from tail to head (the head is [segmentos.last]).
  final List<Posicion> segmentos;

  /// The direction the head travels as it leaves the board.
  final Direccion direccionSalida;

  /// The off-board cell the head aims for — one step past the board edge along
  /// [direccionSalida], so the whole body clears the board.
  final Posicion objetivoBorde;
}

/// The immutable state the `JuegoViewModel` exposes to its View.
///
/// New states are produced with [copyWith] so the View can rely on instance
/// identity changing on every meaningful update (Observer/data-binding), and so
/// no UI mutation ever leaks back into the domain.
class JuegoViewState {
  /// Creates a game view state.
  const JuegoViewState({
    required this.tablero,
    required this.movimientos,
    this.movimientosRestantes = -1,
    this.coleccionables = 0,
    this.movimientoInvalido = false,
    this.alertaInvalida = false,
    this.pausado = false,
    this.derrota = false,
    this.derrotaPorTiempo = false,
    this.avisoTiempo = false,
    this.pistaHabilitadaEnNivel = false,
    this.pistaDisponible = false,
    this.pistaUsada = false,
    this.pistaSugerida,
    this.pistaBloqueadaSegundos,
    this.victoria,
    this.tiempoRestante,
    this.muted = false,
    this.usosUndoRestantes = 3,
    this.animacionSalida,
  });

  /// The board snapshot to render. [TableroUI.profundo] drives whether the
  /// View renders the flat 2D board or the rotatable 3D cube (ticket 36).
  final TableroUI tablero;

  /// The move counter shown in the HUD (total registered taps).
  final int movimientos;

  /// Remaining moves before game over (countdown), or -1 when unlimited.
  final int movimientosRestantes;

  /// How many collectibles the player has picked up so far, shown in the HUD as
  /// the bonus-time tally.
  final int coleccionables;

  /// Whether the last tap was a **penalized invalid** move: the board is left
  /// unchanged but the View should play the shake/flash feedback. The flag rides
  /// on each new state instance, so a repeated invalid tap re-triggers it.
  final bool movimientoInvalido;

  /// The **debounced** red-alert pulse: `true` only on the *leading* invalid tap
  /// of an interaction, so the View flashes/buzzes exactly once even when the
  /// player taps a blocked arrow rapidly. Distinct from [movimientoInvalido]
  /// (which mirrors the rule and rides on *every* invalid tap): repeated invalid
  /// taps within [JuegoViewModel.ventanaAlertaInvalida] leave this `false` so the
  /// flash cannot strobe (Ticket 28, AC1).
  final bool alertaInvalida;

  /// Whether the session is paused: the View dims the board and shows the resume
  /// overlay while taps are rejected (the domain `EstadoPausado`).
  final bool pausado;

  /// Whether the level was lost: the View shows the defeat overlay
  /// (the domain `EstadoDerrota`).
  final bool derrota;

  /// Whether defeat was caused by timer timeout (as opposed to move
  /// exhaustion). Meaningful only when [derrota] is `true`.
  final bool derrotaPorTiempo;

  /// Whether the timed level is inside its final-warning window (≤ 15 s left):
  /// the HUD clock adopts a distinct, pulsing warning style while this is `true`
  /// (ticket 29, AC2). Latches on when the clock first crosses 15 s and stays on
  /// for the rest of the run; always `false` on untimed and bonus levels (AC3).
  /// Distinct from the one-shot `TipoEvento.avisoTiempo` audio cue, which the
  /// ViewModel emits exactly once as the threshold is crossed.
  final bool avisoTiempo;

  /// Whether this level offers a hint button at all — **Rule A** of the hint
  /// gate (ticket 35): `true` only on medium/hard levels. Stable for the whole
  /// run, so the View can decide whether to *build* the button (absent on easy)
  /// independently of whether it is currently usable ([pistaDisponible]).
  final bool pistaHabilitadaEnNivel;

  /// Whether the hint button is usable **right now** — the full gate (ticket 35):
  /// Rule A ([pistaHabilitadaEnNivel]) AND the time gate (`≤ 25 s` left) AND the
  /// session still playing AND the hint not yet spent ([pistaUsada]). Recomputed
  /// each tick alongside [avisoTiempo]; the View binds the button's *lit* look to
  /// it and never evaluates the rule.
  final bool pistaDisponible;

  /// Whether this level's **single** hint has already been spent — the once-per-
  /// level guard (ticket 35). Latches to `true` the moment [JuegoViewModel.pedirPista]
  /// delivers a suggestion and, unlike [pistaDisponible], is carried forward by
  /// [copyWith] so it survives later ticks. Once set, the hint button is disabled
  /// for the rest of the run: a hint can never be requested twice.
  final bool pistaUsada;

  /// The board cell to spotlight as a hint — the head of a currently-clearable
  /// arrow (ticket 35). **Transient**: it rides only on the state
  /// [JuegoViewModel.pedirPista] emits and is *not* carried forward by
  /// [copyWith], so the View captures it into a brief highlight pulse (as it does
  /// for [animacionSalida]) and it clears on the next state. `null` when no hint
  /// is being shown.
  final Posicion? pistaSugerida;

  /// How many seconds remain until the hint **unlocks**, published only when the
  /// player taps the button *too early* — while Rule A holds but the `≤ 25 s`
  /// time gate is still shut (ticket 35). **Transient**: like [pistaSugerida] it
  /// rides only on the state [JuegoViewModel.pedirPista] emits and is *not*
  /// carried forward by [copyWith], so the View captures it into a one-shot
  /// "still locked for X s" message. `null` when no such feedback is pending.
  final int? pistaBloqueadaSegundos;

  /// Whether audio is globally muted (the View shows a mute/unmute icon).
  final bool muted;

  /// The victory snapshot to render, or `null` while the level is still in play.
  /// Distinct from the domain `EstadoVictoria`.
  final VictoriaViewState? victoria;

  /// Time left on the HUD clock for a timed level, or `null` when untimed.
  final Duration? tiempoRestante;

  /// How many undos remain this level (starts at 3, capped per Ticket 30).
  final int usosUndoRestantes;

  /// The exit animation to play, or `null` when nothing is exiting.
  ///
  /// **Transient**: it is present only on the state a valid move emits and is
  /// deliberately *not* carried forward by [copyWith], so it clears on the very
  /// next state and a finished animation never leaks into later frames.
  final AnimacionSalida? animacionSalida;

  /// Returns a copy with the given fields replaced.
  JuegoViewState copyWith({
    TableroUI? tablero,
    int? movimientos,
    int? movimientosRestantes,
    int? coleccionables,
    bool? movimientoInvalido,
    bool? alertaInvalida,
    bool? pausado,
    bool? derrota,
    bool? derrotaPorTiempo,
    bool? avisoTiempo,
    bool? pistaHabilitadaEnNivel,
    bool? pistaDisponible,
    bool? pistaUsada,
    Posicion? pistaSugerida,
    int? pistaBloqueadaSegundos,
    bool? muted,
    VictoriaViewState? victoria,
    Duration? tiempoRestante,
    int? usosUndoRestantes,
    AnimacionSalida? animacionSalida,
  }) {
    return JuegoViewState(
      tablero: tablero ?? this.tablero,
      movimientos: movimientos ?? this.movimientos,
      movimientosRestantes:
          movimientosRestantes ?? this.movimientosRestantes,
      coleccionables: coleccionables ?? this.coleccionables,
      movimientoInvalido: movimientoInvalido ?? this.movimientoInvalido,
      // Transient one-shot: a copy that doesn't explicitly raise it clears the
      // pulse, so the red flash never survives into a later state (e.g. a timer
      // tick) and re-fires. It is true only on the state the leading invalid tap
      // produces (Ticket 28/29).
      alertaInvalida: alertaInvalida ?? false,
      pausado: pausado ?? this.pausado,
      derrota: derrota ?? this.derrota,
      derrotaPorTiempo: derrotaPorTiempo ?? this.derrotaPorTiempo,
      avisoTiempo: avisoTiempo ?? this.avisoTiempo,
      pistaHabilitadaEnNivel:
          pistaHabilitadaEnNivel ?? this.pistaHabilitadaEnNivel,
      pistaDisponible: pistaDisponible ?? this.pistaDisponible,
      // Latches on purpose: once the single hint is spent it stays spent for the
      // whole run, so a later copy (e.g. a timer tick) never silently re-arms it.
      pistaUsada: pistaUsada ?? this.pistaUsada,
      // Transient on purpose: a copy that doesn't explicitly carry a suggestion
      // clears the highlight, so a hint spotlight never survives into the next
      // state (e.g. a timer tick) — the View captures it into its own pulse.
      pistaSugerida: pistaSugerida,
      // Transient on purpose (same as pistaSugerida): the "still locked" notice
      // rides only on the tap that raised it and clears on the next state.
      pistaBloqueadaSegundos: pistaBloqueadaSegundos,
      muted: muted ?? this.muted,
      victoria: victoria ?? this.victoria,
      tiempoRestante: tiempoRestante ?? this.tiempoRestante,
      usosUndoRestantes: usosUndoRestantes ?? this.usosUndoRestantes,
      // Transient on purpose: a copy without an explicit descriptor clears it,
      // so the exit animation input never survives into the next frame.
      animacionSalida: animacionSalida,
    );
  }
}
