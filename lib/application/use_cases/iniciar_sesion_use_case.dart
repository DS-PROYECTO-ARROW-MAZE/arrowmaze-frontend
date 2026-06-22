import '../ports/fuente_autenticacion.dart';
import '../ports/proveedor_sesion.dart';
import 'limpiar_progreso_local_use_case.dart';
import 'resultado_inicio_sesion.dart';

/// Authenticates an existing user.
///
/// On success it wipes any leftover device-local progression (so a previous
/// account's unlocks never leak in) and stores the session token via the
/// injected [ProveedorSesion]. On wrong credentials it surfaces a clean
/// [InicioSesionCredencialesInvalidas].
class IniciarSesionUseCase {
  const IniciarSesionUseCase({
    required this.fuenteAutenticacion,
    required this.proveedorSesion,
    this.limpiarProgresoLocal,
  });

  final FuenteAutenticacion fuenteAutenticacion;
  final ProveedorSesion proveedorSesion;

  /// Wipes device-local progression on a fresh login so no ghost data carries
  /// over from a prior account; optional so token-only tests need not wire it.
  final LimpiarProgresoLocalUseCase? limpiarProgresoLocal;

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
      // Start from a clean slate: drop any progression left on the device from
      // a prior account before this user's session begins.
      await limpiarProgresoLocal?.ejecutar();
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
