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
}

/// An immutable UI snapshot of the whole board.
class TableroUI {
  /// Creates a board snapshot of [filas] × [columnas] holding [celdas].
  const TableroUI({
    required this.filas,
    required this.columnas,
    required this.celdas,
  });

  /// Row count.
  final int filas;

  /// Column count.
  final int columnas;

  /// All cells, row-major.
  final List<CeldaUI> celdas;

  /// The cell snapshot at [posicion].
  CeldaUI celdaEn(Posicion posicion) =>
      celdas.firstWhere((c) => c.posicion == posicion);
}

/// The UI snapshot shown when the player wins — a **presentation** view state,
/// deliberately **not** the domain `EstadoVictoria` (DM-F8 naming guardrail).
///
/// The session's GoF State (`EstadoVictoria`) lives in the domain and drives the
/// rules; this immutable snapshot is what the victory overlay renders, and it
/// never leaks the domain type into the View (nor the reverse). It carries the
/// final HUD figures the overlay shows; richer scoring (`Puntaje`/`Estrellas`)
/// arrives with ticket 06.
class VictoriaViewState {
  /// Creates the victory snapshot with the final [movimientos] count.
  const VictoriaViewState({required this.movimientos});

  /// The move count the level was cleared in.
  final int movimientos;
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
    this.movimientoInvalido = false,
    this.pausado = false,
    this.derrota = false,
    this.victoria,
    this.tiempoRestante,
  });

  /// The board snapshot to render.
  final TableroUI tablero;

  /// The move counter shown in the HUD.
  final int movimientos;

  /// Whether the last tap was a **penalized invalid** move: the board is left
  /// unchanged but the View should play the shake/flash feedback. The flag rides
  /// on each new state instance, so a repeated invalid tap re-triggers it.
  final bool movimientoInvalido;

  /// Whether the session is paused: the View dims the board and shows the resume
  /// overlay while taps are rejected (the domain `EstadoPausado`).
  final bool pausado;

  /// Whether the level was lost on the clock: the View shows the defeat overlay
  /// (the domain `EstadoDerrota`).
  final bool derrota;

  /// The victory snapshot to render, or `null` while the level is still in play.
  /// Distinct from the domain `EstadoVictoria`.
  final VictoriaViewState? victoria;

  /// Time left on the HUD clock for a timed level, or `null` when untimed.
  final Duration? tiempoRestante;

  /// Returns a copy with the given fields replaced.
  JuegoViewState copyWith({
    TableroUI? tablero,
    int? movimientos,
    bool? movimientoInvalido,
    bool? pausado,
    bool? derrota,
    VictoriaViewState? victoria,
    Duration? tiempoRestante,
  }) {
    return JuegoViewState(
      tablero: tablero ?? this.tablero,
      movimientos: movimientos ?? this.movimientos,
      movimientoInvalido: movimientoInvalido ?? this.movimientoInvalido,
      pausado: pausado ?? this.pausado,
      derrota: derrota ?? this.derrota,
      victoria: victoria ?? this.victoria,
      tiempoRestante: tiempoRestante ?? this.tiempoRestante,
    );
  }
}
