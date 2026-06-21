import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'resultado_registro.dart';

/// Registers a new user account.
///
/// The backend's `POST /auth/register` returns the created user but no token,
/// so this use case registers and then logs in to obtain and persist the
/// session token via the injected [ProveedorSesion]. On a duplicate email it
/// surfaces a clean [RegistroEmailDuplicado] — never an unhandled exception.
class RegistrarUsuarioUseCase {
  const RegistrarUsuarioUseCase({
    required this.fuenteAutenticacion,
    required this.proveedorSesion,
  });

  final FuenteAutenticacion fuenteAutenticacion;
  final ProveedorSesion proveedorSesion;

  /// Executes the registration flow.
  ///
  /// Returns a [ResultadoRegistro] — never throws.
  Future<ResultadoRegistro> ejecutar({
    required String email,
    required String password,
  }) async {
    try {
      await fuenteAutenticacion.registrar(email: email, password: password);
      final token = await fuenteAutenticacion.iniciarSesion(
        email: email,
        password: password,
      );
      await proveedorSesion.guardarToken(token);
      return const RegistroExitoso();
    } on AutenticacionException catch (e) {
      return switch (e.codigo) {
        'EMAIL_DUPLICATE' => const RegistroEmailDuplicado(),
        _ => RegistroError(e.mensaje),
      };
    } catch (e) {
      return RegistroError(e.toString());
    }
  }
}
