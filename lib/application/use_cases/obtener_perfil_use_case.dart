import '../../domain/sesion/perfil.dart';
import '../ports/fuente_autenticacion.dart';

/// Use case: read the authenticated principal (`GET /auth/me`).
///
/// Delegates to [FuenteAutenticacion.obtenerPerfil]. The session token is
/// attached transparently by the HTTP interceptor, so this use case stays free
/// of any auth-header concern.
class ObtenerPerfilUseCase {
  /// Creates the use case with an injected auth port.
  const ObtenerPerfilUseCase({required this.fuenteAutenticacion});

  /// The remote authentication port.
  final FuenteAutenticacion fuenteAutenticacion;

  /// Fetches the current user's profile.
  Future<Perfil> ejecutar() => fuenteAutenticacion.obtenerPerfil();
}
