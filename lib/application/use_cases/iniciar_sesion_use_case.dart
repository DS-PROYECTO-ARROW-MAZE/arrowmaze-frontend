import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'activar_progreso_usuario_use_case.dart';
import 'resultado_inicio_sesion.dart';

/// Authenticates an existing user.
///
/// On success it activates this account's device-local progression (switching
/// the progress namespace to the user, so their own retained unlocks show and no
/// other account's leak in) and stores the session token via the injected
/// [ProveedorSesion]. On wrong credentials it surfaces a clean
/// [InicioSesionCredencialesInvalidas].
class IniciarSesionUseCase {
  const IniciarSesionUseCase({
    required this.fuenteAutenticacion,
    required this.proveedorSesion,
    this.activarProgreso,
  });

  final FuenteAutenticacion fuenteAutenticacion;
  final ProveedorSesion proveedorSesion;

  /// Switches device-local progression to this account on login so their own
  /// unlocks are restored; optional so token-only tests need not wire it.
  final ActivarProgresoUsuarioUseCase? activarProgreso;

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
      // Switch to this account's own retained progression before the session
      // begins (per-user local progress, Ticket 24).
      await activarProgreso?.ejecutar(email);
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
