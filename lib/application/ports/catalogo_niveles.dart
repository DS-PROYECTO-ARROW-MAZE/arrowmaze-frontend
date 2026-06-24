import '../../domain/niveles/resumen_nivel.dart';

/// Port for listing the available levels (Ticket 13, DM §10.2).
///
/// Returns the ordered catalog (by id ascending). The §3.2 reconciliation
/// reserved this port name for "a real list-loading need" — the Level Selection
/// screen is that need. The use case depends on this abstraction, never on
/// assets or HTTP.
abstract interface class CatalogoNiveles {
  /// Returns every known level summary, ordered by [ResumenNivel.id] ascending.
  Future<List<ResumenNivel>> listar();
}
