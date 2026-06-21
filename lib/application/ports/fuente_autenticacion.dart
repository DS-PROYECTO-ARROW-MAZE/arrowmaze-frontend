import '../../domain/sesion/perfil.dart';
import '../../domain/sesion/usuario_registrado.dart';

/// Port for the remote authentication API.
///
/// The concrete implementation (HTTP) lives in infrastructure. Use cases
/// depend on this port so they never reference HTTP or platform details.
abstract interface class FuenteAutenticacion {
  /// Sends a register request (`POST /auth/register`).
  ///
  /// Returns the created [UsuarioRegistrado] on success — the endpoint does
  /// **not** issue a token, so callers must log in afterwards. Throws
  /// [AutenticacionException] on failure (e.g. duplicate email).
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  });

  /// Sends a login request (`POST /auth/login`).
  ///
  /// Returns a session token on success. Throws [AutenticacionException] on
  /// failure (e.g. wrong credentials).
  Future<String> iniciarSesion({
    required String email,
    required String password,
  });

  /// Reads the authenticated principal (`GET /auth/me`).
  ///
  /// Requires a valid session token (attached by the HTTP interceptor). Throws
  /// [AutenticacionException] when unauthenticated or on a server error.
  Future<Perfil> obtenerPerfil();
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
