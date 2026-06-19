import 'entities/celda.dart';
import 'entities/trayectoria.dart';
import 'value_objects/direccion.dart';
import 'value_objects/posicion.dart';

/// The outcome of firing a ray across the board from one cell.
///
/// A move is valid only when the ray reaches a board edge with nothing in the
/// way ([despejadoHastaBorde] is `true`); otherwise [obstaculo] names the first
/// blocking cell that stopped it.
class ResultadoRaycast {
  /// A ray that flew clear off the board edge.
  const ResultadoRaycast.despejado()
      : despejadoHastaBorde = true,
        obstaculo = null;

  /// A ray stopped at [obstaculo] before reaching the edge.
  const ResultadoRaycast.bloqueado(Posicion this.obstaculo)
      : despejadoHastaBorde = false;

  /// Whether the ray reached the edge unobstructed.
  final bool despejadoHastaBorde;

  /// The first blocking cell hit, or `null` when the ray was clear.
  final Posicion? obstaculo;
}

/// The board *port* — the only thing use cases and the solver depend on.
///
/// It is a deliberately narrow, deep interface: query a cell ([celdaEn]) or the
/// path covering it ([trayectoriaEn]), test a ray ([raycast]) and remove a whole
/// arrow path ([eliminarTrayectoria]). The concrete board — a `GrafoTablero`
/// mutated incrementally — is an implementation detail behind this contract,
/// which is the OCP seam that lets a future 3D board be a new implementation with
/// no change to callers (see `Tablero` in `CONTEXT.md`).
abstract interface class Tablero {
  /// Number of rows.
  int get filas;

  /// Number of columns.
  int get columnas;

  /// The cell currently at [posicion].
  Celda celdaEn(Posicion posicion);

  /// The arrow path covering [posicion], or `null` when the cell is empty or a
  /// wall. Any segment of a path returns the same `Trayectoria`, so a tap on any
  /// part of an arrow resolves the whole arrow.
  Trayectoria? trayectoriaEn(Posicion posicion);

  /// Fires a ray from [origen] along [direccion] and reports whether it reaches
  /// the edge. The origin cell itself is excluded — the ray starts at the next
  /// cell along the direction.
  ResultadoRaycast raycast(Posicion origen, Direccion direccion);

  /// Removes the whole arrow path [idFlecha], leaving transparent empty space in
  /// every cell it covered.
  ///
  /// The change is incremental: only the affected nodes and their immediate
  /// neighbours are re-wired — never a full rebuild.
  void eliminarTrayectoria(int idFlecha);
}
