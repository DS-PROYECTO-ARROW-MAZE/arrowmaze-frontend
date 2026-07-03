import '../ports/catalogo_niveles.dart';
import '../ports/consulta_progreso_local.dart';
import '../ports/i_consulta_progreso_remoto.dart';

/// On login, reads the authenticated player's server-side progression via
/// `GET /progress` and merges it into the local store ([ConsultaProgresoLocal])
/// keeping the **best** per-level (AC2, AC3, Ticket 24).
///
/// Remote items are keyed by backend level UUID; the [CatalogoNiveles] maps them
/// to local ordinal ids. Unmapped UUIDs (e.g. levels removed from the catalog)
/// are silently skipped. A remote read failure (offline, 401, 500) degrades
/// gracefully to a no-op so the player reaches Level Select with whatever local
/// progress exists (AC4).
class RestaurarProgresoUseCase {
  const RestaurarProgresoUseCase({
    required IConsultaProgresoRemoto consultaRemoto,
    required ConsultaProgresoLocal progresoLocal,
    required CatalogoNiveles catalogo,
  })  : _consultaRemoto = consultaRemoto,
        _progresoLocal = progresoLocal,
        _catalogo = catalogo;

  final IConsultaProgresoRemoto _consultaRemoto;
  final ConsultaProgresoLocal _progresoLocal;
  final CatalogoNiveles _catalogo;

  /// Fetches remote progress and merges best-per-level into local storage.
  ///
  /// Safe to call multiple times (idempotent): re‑execution re‑merges with the
  /// same best-per-level policy.
  Future<void> ejecutar() async {
    List<_ProgresoItem> items;
    try {
      final remotos = await _consultaRemoto.obtenerProgreso();
      final catalogo = await _catalogo.listar();

      // Build a lookup: backend UUID → local ordinal id.
      final uuidToId = <String, int>{};
      for (final nivel in catalogo) {
        final uuid = nivel.idRemoto;
        if (uuid != null) {
          uuidToId[uuid] = nivel.id;
        }
      }

      items = [];
      for (final remoto in remotos) {
        final idNivel = uuidToId[remoto.nivelId];
        if (idNivel != null) {
          items.add(_ProgresoItem(idNivel: idNivel, estrellas: remoto.estrellas));
        }
      }
    } catch (_) {
      return;
    }

    for (final item in items) {
      await _progresoLocal.registrarCompletado(
        idNivel: item.idNivel,
        estrellas: item.estrellas,
      );
    }
  }
}

/// Internal helper bundling a resolved local level id with its star count.
class _ProgresoItem {
  const _ProgresoItem({required this.idNivel, required this.estrellas});

  final int idNivel;
  final int estrellas;
}