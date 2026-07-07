import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/consulta_progreso_local.dart';
import '../../application/ports/selector_usuario_progreso.dart';

/// `shared_preferences`-backed [ConsultaProgresoLocal] (Ticket 13, DM §10.1),
/// namespaced **per user** (Ticket 24).
///
/// Progression survives restarts and account switches: each cleared level stores
/// its best star count under `arrowmaze.progreso.<usuario>.estrellas.<id>`, where
/// `<usuario>` is the active account set via [establecerUsuario]. A level is
/// "completed" iff such a key exists, so the set of completed ids is derived from
/// the keys — there is no separate completed list to keep in sync.
///
/// Because progress is keyed by user, one account never sees another's unlocks
/// and a user's own progress is retained across logout/login on the device — the
/// login flow only *switches* the active user, it does not wipe. The active user
/// is itself persisted, so a restart (auto-login) reads the right namespace.
class ProgresoLocalPersistente
    implements ConsultaProgresoLocal, SelectorUsuarioProgreso {
  /// Creates the store. An existing [SharedPreferences] may be injected (tests);
  /// otherwise the shared instance is obtained lazily on first use.
  ProgresoLocalPersistente({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// Root prefix under which every progression key (and the active-user pointer)
  /// lives.
  static const String _raiz = 'arrowmaze.progreso.';

  /// Key holding the active account's namespace, so it survives restarts.
  static const String claveUsuarioActivo = '${_raiz}usuarioActivo';

  /// Namespace used before any account is selected (e.g. offline/no login).
  static const String usuarioAnonimo = '_anon';

  /// Cached active user; resolved lazily from storage on first use.
  String? _usuario;

  Future<SharedPreferences> get _instancia async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// The active account namespace, defaulting to [usuarioAnonimo].
  Future<String> _usuarioActivo() async {
    if (_usuario != null) return _usuario!;
    final prefs = await _instancia;
    return _usuario = prefs.getString(claveUsuarioActivo) ?? usuarioAnonimo;
  }

  /// The per-level key prefix for the active account.
  Future<String> _prefijoEstrellas() async =>
      '$_raiz${await _usuarioActivo()}.estrellas.';

  @override
  Future<void> establecerUsuario(String usuario) async {
    final prefs = await _instancia;
    final normalizado = usuario.trim().toLowerCase();
    _usuario = normalizado.isEmpty ? usuarioAnonimo : normalizado;
    await prefs.setString(claveUsuarioActivo, _usuario!);
  }

  @override
  Future<Set<int>> nivelesCompletados() async {
    final prefs = await _instancia;
    final prefijo = await _prefijoEstrellas();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(prefijo))
        .map((k) => int.tryParse(k.substring(prefijo.length)))
        .whereType<int>()
        .toSet();
  }

  @override
  Future<int> mejorEstrellas(int idNivel) async {
    final prefs = await _instancia;
    return prefs.getInt('${await _prefijoEstrellas()}$idNivel') ?? 0;
  }

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {
    final prefs = await _instancia;
    final clave = '${await _prefijoEstrellas()}$idNivel';
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
    final prefijo = await _prefijoEstrellas();
    // Snapshot the keys first — removing entries mutates the key set. Only the
    // active user's entries are cleared; other accounts are left intact.
    final claves =
        prefs.getKeys().where((k) => k.startsWith(prefijo)).toList();
    for (final clave in claves) {
      await prefs.remove(clave);
    }
  }
}
