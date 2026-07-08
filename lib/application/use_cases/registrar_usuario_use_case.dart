import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'activar_progreso_usuario_use_case.dart';
import 'resultado_registro.dart';

/// Registers a new user account.
///
/// The backend's `POST /auth/register` returns the created user but no token,
/// so this use case registers and then logs in to obtain and persist the
/// session token via the injected [ProveedorSesion]. It activates this account's
/// device-local progression (a brand-new account simply has an empty namespace,
/// so it starts with no unlocks and never inherits another user's). On a
/// duplicate email it surfaces a clean [RegistroEmailDuplicado] — never an
/// unhandled exception.
class RegistrarUsuarioUseCase {
  const RegistrarUsuarioUseCase({
    required this.fuenteAutenticacion,
    required this.proveedorSesion,
    this.activarProgreso,
  });

  final FuenteAutenticacion fuenteAutenticacion;
  final ProveedorSesion proveedorSesion;

  /// Switches device-local progression to this account so a new user starts on
  /// their own (empty) namespace; optional so token-only tests need not wire it.
  final ActivarProgresoUsuarioUseCase? activarProgreso;

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
      // Switch to this account's own progression namespace before the session
      // begins (per-user local progress, Ticket 24).
      await activarProgreso?.ejecutar(email);
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
