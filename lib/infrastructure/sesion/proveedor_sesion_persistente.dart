import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/proveedor_sesion.dart';

/// `shared_preferences`-backed [ProveedorSesion] (Issue 14, AC3).
///
/// Persists the JWT session token so it survives app restarts, satisfying the
/// "store the token" requirement without leaking the storage mechanism to the
/// use cases — DIP holds. The same [ProveedorSesion] abstraction is read by the
/// [ClienteHttpAutenticado] interceptor on every protected request.
class ProveedorSesionPersistente implements ProveedorSesion {
  /// Creates the store. An existing [SharedPreferences] may be injected (tests);
  /// otherwise the shared instance is obtained lazily on first use.
  ProveedorSesionPersistente({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// Storage key for the session token.
  static const String claveToken = 'arrowmaze.sesion.token';

  Future<SharedPreferences> get _instancia async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> obtenerToken() async {
    final prefs = await _instancia;
    return prefs.getString(claveToken);
  }

  @override
  Future<void> guardarToken(String token) async {
    final prefs = await _instancia;
    await prefs.setString(claveToken, token);
  }

  @override
  Future<void> cerrarSesion() async {
    final prefs = await _instancia;
    await prefs.remove(claveToken);
  }
}
