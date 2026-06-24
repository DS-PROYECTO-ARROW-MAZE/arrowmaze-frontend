/// Port for session token storage (DIP).
///
/// Injected into use cases — never accessed statically. Implementations
/// (e.g. [ProveedorSesionImpl]) live in infrastructure and handle platform-
/// specific secure storage.
abstract interface class ProveedorSesion {
  /// The stored session token, or `null` if no session exists.
  Future<String?> obtenerToken();

  /// Persists [token] for the current session.
  Future<void> guardarToken(String token);

  /// Clears any stored token — the user is signed out.
  Future<void> cerrarSesion();
}
