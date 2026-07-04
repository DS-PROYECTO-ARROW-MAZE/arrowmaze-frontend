import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/preferencias_usuario.dart';

/// `shared_preferences`-backed [PreferenciasUsuario] (Ticket 27).
///
/// Stores two entries under stable keys:
/// * `arrowmaze.config.sonido` — `bool`, defaults to `true` on first run.
/// * `arrowmaze.config.idioma` — `String`, absent on first run (null return).
///
/// An existing [SharedPreferences] may be injected for tests to avoid platform
/// channel dependencies — same pattern used by [ProgresoLocalPersistente].
class PreferenciasUsuarioPersistente implements PreferenciasUsuario {
  /// Creates the adapter. Pass [prefs] in tests; production uses lazy init.
  PreferenciasUsuarioPersistente({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const String _claveSonido = 'arrowmaze.config.sonido';
  static const String _claveIdioma = 'arrowmaze.config.idioma';

  Future<SharedPreferences> get _instancia async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<bool> leerSonidoHabilitado() async {
    final prefs = await _instancia;
    return prefs.getBool(_claveSonido) ?? true;
  }

  @override
  Future<String?> leerIdioma() async {
    final prefs = await _instancia;
    return prefs.getString(_claveIdioma);
  }

  @override
  Future<void> guardarSonidoHabilitado(bool habilitado) async {
    final prefs = await _instancia;
    await prefs.setBool(_claveSonido, habilitado);
  }

  @override
  Future<void> guardarIdioma(String idioma) async {
    final prefs = await _instancia;
    await prefs.setString(_claveIdioma, idioma);
  }
}
