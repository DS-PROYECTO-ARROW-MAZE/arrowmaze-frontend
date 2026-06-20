import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'resultado_registro.dart';

/// Registers a new user account.
///
/// On success it stores the session token via the injected [ProveedorSesion].
/// On a duplicate email it surfaces a clean [RegistroEmailDuplicado] — never an
/// unhandled exception.
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
    required String username,
  }) async {
    try {
      final token = await fuenteAutenticacion.registrar(
        email: email,
        password: password,
        username: username,
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
