/// Port for the remote authentication API.
///
/// The concrete implementation (HTTP) lives in infrastructure. Use cases
/// depend on this port so they never reference HTTP or platform details.
abstract interface class FuenteAutenticacion {
  /// Sends a register request.
  ///
  /// Returns a session token on success. Throws [AutenticacionException] on
  /// failure (e.g. duplicate email, validation error).
  Future<String> registrar({
    required String email,
    required String password,
    required String username,
  });

  /// Sends a login request.
  ///
  /// Returns a session token on success. Throws [AutenticacionException] on
  /// failure (e.g. wrong credentials).
  Future<String> iniciarSesion({
    required String email,
    required String password,
  });
}

/// A mapped authentication error surfaced by the data source.
///
/// [codigo] allows the use case to distinguish specific failures (duplicate
/// email, wrong password, server error) without coupling to HTTP status codes.
class AutenticacionException implements Exception {
  const AutenticacionException(this.codigo, this.mensaje);

  final String codigo;
  final String mensaje;

  @override
  String toString() => 'AutenticacionException($codigo): $mensaje';
}
