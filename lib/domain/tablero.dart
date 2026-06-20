import 'entities/celda.dart';
import 'entities/trayectoria.dart';
import 'value_objects/direccion.dart';
import 'value_objects/posicion.dart';

/// The outcome of firing a ray across the board from one cell.
///
/// A move is valid only when the ray reaches a board edge with nothing in the
/// way ([despejadoHastaBorde] is `true`); otherwise [obstaculo] names the first
/// blocking cell that stopped it. A clear ray also reports the [coleccionables]
/// it flew over (transparent bonus cells) so a valid move can collect them; a
/// blocked ray collects nothing, so its list is always empty.
class ResultadoRaycast {
  /// A ray that flew clear off the board edge, having crossed [coleccionables]
  /// (the positions of any collectibles on its way, in path order).
  const ResultadoRaycast.despejado({
    this.coleccionables = const <Posicion>[],
  })  : despejadoHastaBorde = true,
        obstaculo = null;

  /// A ray stopped at [obstaculo] before reaching the edge; nothing collected.
  const ResultadoRaycast.bloqueado(Posicion this.obstaculo)
      : despejadoHastaBorde = false,
        coleccionables = const <Posicion>[];

  /// Whether the ray reached the edge unobstructed.
  final bool despejadoHastaBorde;

  /// The first blocking cell hit, or `null` when the ray was clear.
  final Posicion? obstaculo;

  /// The collectibles the ray crossed on a clear path, in the order met. Empty
  /// for a blocked ray (a non-exiting move collects nothing).
  final List<Posicion> coleccionables;
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

  /// Whether the board holds no arrow paths left — every arrow has exited.
  ///
  /// This is the victory condition (`Victoria` in `CONTEXT.md`): a board is empty
  /// once its last `Trayectoria` is removed. Walls and empty space do not count.
  bool get estaVacio;

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

  /// Restores a whole arrow path previously taken off the board by
  /// [eliminarTrayectoria] — the **exact mirror** used to undo a valid move
  /// (ticket 09).
  ///
  /// Every segment cell becomes a `CeldaFlecha` again and each segment node is
  /// re-linked to the nearest still-present node in every direction, the inverse
  /// of removal's "wire the neighbours across the gap". The edit is incremental
  /// (only the restored nodes and their immediate links change) and preserves the
  /// identity of every untouched node. Undo must replay in reverse removal order
  /// for the re-link to land exactly where it was.
  void restaurarTrayectoria(Trayectoria trayectoria);

  /// Consumes the collectible at [posicion], turning it into transparent empty
  /// space so it is collected only once.
  ///
  /// A no-op when the cell is not a collectible. Collectibles never block a ray
  /// and never count toward [estaVacio], so this never affects victory.
  void recogerColeccionable(Posicion posicion);
}
