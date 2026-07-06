import '../../domain/niveles/resumen_nivel.dart';

/// Port for listing the available levels (Ticket 13, DM §10.2).
///
/// Returns the ordered catalog (by id ascending). The §3.2 reconciliation
/// reserved this port name for "a real list-loading need" — the Level Selection
/// screen is that need. The use case depends on this abstraction, never on
/// assets or HTTP.
///
/// Extended in Ticket 23 for the endless tail: past the last authored level,
/// [obtenerPorIndice] yields a procedurally-generated level summary.
abstract interface class CatalogoNiveles {
  /// Returns every known level summary, ordered by [ResumenNivel.id] ascending.
  Future<List<ResumenNivel>> listar();

  /// Returns the number of authored (pre-bundled) levels.
  Future<int> obtenerCantidadTotal();

  /// Returns a level summary for the given 1‑based [indice].
  ///
  /// When [indice] is within the authored catalog (≤ [obtenerCantidadTotal]),
  /// the authored summary is returned. Past the authored count, a
  /// procedurally-generated summary is returned (the endless tail).
  ///
  /// The supply is unbounded — any positive [indice] yields a result.
  Future<ResumenNivel> obtenerPorIndice(int indice);
}
