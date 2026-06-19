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
  });

  /// The board snapshot to render.
  final TableroUI tablero;

  /// The move counter shown in the HUD.
  final int movimientos;

  /// Returns a copy with the given fields replaced.
  JuegoViewState copyWith({
    TableroUI? tablero,
    int? movimientos,
  }) {
    return JuegoViewState(
      tablero: tablero ?? this.tablero,
      movimientos: movimientos ?? this.movimientos,
    );
  }
}
