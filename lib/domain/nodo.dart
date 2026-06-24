import 'entities/celda.dart';
import 'value_objects/direccion.dart';

/// A single board cell as a graph node, wired to its immediate neighbours.
///
/// `Nodo` is the building block of [GrafoTablero]'s incremental structure: each
/// node knows the adjacent node in every [Direccion] (only the in-bounds ones
/// are present in [vecinos]). Removing an arrow re-wires the affected node's
/// neighbours to each other and clears its links — a local edit, never a rebuild
/// — so untouched nodes keep their identity. The neighbour table is keyed by
/// `Direccion`, which is what keeps the walk dimension-agnostic.
class Nodo {
  /// Creates a node holding [celda] with no neighbours linked yet.
  Nodo(this.celda);

  /// The cell currently occupying this position (mutable: an arrow becomes
  /// empty when removed).
  Celda celda;

  /// Adjacent nodes by direction; absent keys mean a board edge.
  final Map<Direccion, Nodo> vecinos = <Direccion, Nodo>{};
}
