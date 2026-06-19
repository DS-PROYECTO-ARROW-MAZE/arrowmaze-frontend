import '../../domain/value_objects/direccion.dart';
import '../../domain/value_objects/posicion.dart';

/// The visual kind of a board cell, decoupled from the domain `Celda` types so
/// the View never imports the domain hierarchy.
enum TipoCeldaUI {
  /// An interactive arrow.
  flecha,

  /// A blocking wall.
  pared,

  /// Transparent empty space.
  vacia,
}

/// An immutable UI snapshot of one cell.
///
/// This is a render model (not the GoF State and not a domain entity): a flat,
/// theme-free description the `GameView` paints with `GameTheme` tokens.
class CeldaUI {
  /// Creates a cell snapshot.
  const CeldaUI({
    required this.posicion,
    required this.tipo,
    this.direccion,
  });

  /// Where the cell sits.
  final Posicion posicion;

  /// What to draw.
  final TipoCeldaUI tipo;

  /// For [TipoCeldaUI.flecha], which way the arrow points; otherwise `null`.
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
