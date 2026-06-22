import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/consulta_progreso_local.dart';

/// `shared_preferences`-backed [ConsultaProgresoLocal] (Ticket 13, DM §10.1).
///
/// Progression survives restarts: each cleared level stores its best star count
/// under the key `arrowmaze.progreso.estrellas.<id>`. A level is "completed" iff
/// such a key exists, so the set of completed ids is derived from the keys —
/// there is no separate completed list to keep in sync.
///
/// This is the missing persistence layer; the in-memory `ColaSincronizacionLocal`
/// remains the upload queue and is a distinct concern.
class ProgresoLocalPersistente implements ConsultaProgresoLocal {
  /// Creates the store. An existing [SharedPreferences] may be injected (tests);
  /// otherwise the shared instance is obtained lazily on first use.
  ProgresoLocalPersistente({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// Key prefix for the per-level best-star entries.
  static const String prefijoEstrellas = 'arrowmaze.progreso.estrellas.';

  Future<SharedPreferences> get _instancia async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<Set<int>> nivelesCompletados() async {
    final prefs = await _instancia;
    return prefs
        .getKeys()
        .where((k) => k.startsWith(prefijoEstrellas))
        .map((k) => int.tryParse(k.substring(prefijoEstrellas.length)))
        .whereType<int>()
        .toSet();
  }

  @override
  Future<int> mejorEstrellas(int idNivel) async {
    final prefs = await _instancia;
    return prefs.getInt('$prefijoEstrellas$idNivel') ?? 0;
  }

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {
    final prefs = await _instancia;
    final clave = '$prefijoEstrellas$idNivel';
    // -1 sentinel means "no entry yet", so a first 0-star clear still writes
    // (marking the level completed) while later clears only raise the count.
    final actual = prefs.getInt(clave) ?? -1;
    if (estrellas > actual) {
      await prefs.setInt(clave, estrellas);
    }
  }

  @override
  Future<void> limpiar() async {
    final prefs = await _instancia;
    // Snapshot the keys first — removing entries mutates the key set.
    final claves =
        prefs.getKeys().where((k) => k.startsWith(prefijoEstrellas)).toList();
    for (final clave in claves) {
      await prefs.remove(clave);
    }
  }
}
