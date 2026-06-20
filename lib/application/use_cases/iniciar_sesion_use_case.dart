import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'resultado_inicio_sesion.dart';

/// Authenticates an existing user.
///
/// On success it stores the session token via the injected [ProveedorSesion].
/// On wrong credentials it surfaces a clean [InicioSesionCredencialesInvalidas].
class IniciarSesionUseCase {
  const IniciarSesionUseCase({
    required this.fuenteAutenticacion,
    required this.proveedorSesion,
  });

  final FuenteAutenticacion fuenteAutenticacion;
  final ProveedorSesion proveedorSesion;

  /// Executes the login flow.
  ///
  /// Returns a [ResultadoInicioSesion] — never throws.
  Future<ResultadoInicioSesion> ejecutar({
    required String email,
    required String password,
  }) async {
    try {
      final token = await fuenteAutenticacion.iniciarSesion(
        email: email,
        password: password,
      );
      await proveedorSesion.guardarToken(token);
      return const InicioSesionExitoso();
    } on AutenticacionException catch (e) {
      return switch (e.codigo) {
        'INVALID_CREDENTIALS' => const InicioSesionCredencialesInvalidas(),
        _ => InicioSesionError(e.mensaje),
      };
    } catch (e) {
      return InicioSesionError(e.toString());
    }
  }
}
