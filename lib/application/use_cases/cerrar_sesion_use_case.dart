import '../ports/proveedor_sesion.dart';
import 'limpiar_progreso_local_use_case.dart';

/// Clears the user's session token via [ProveedorSesion.cerrarSesion] and wipes
/// their device-local progression so it cannot leak into the next account.
///
/// This use case exists so that the application layer owns the logout
/// contract; Views and ViewModels never touch the port directly (DIP). Both
/// logout entry points route through here, so wiping local state in one place
/// covers them all.
class CerrarSesionUseCase {
  const CerrarSesionUseCase({
    required this.proveedorSesion,
    this.limpiarProgresoLocal,
  });

  final ProveedorSesion proveedorSesion;

  /// Wipes device-local progression on logout; when omitted, only the session
  /// token is cleared (kept optional so token-only tests need not wire it).
  final LimpiarProgresoLocalUseCase? limpiarProgresoLocal;

  /// Clears the stored session token and the user's local progression — the
  /// user is signed out and no progress carries over to the next sign-in.
  Future<void> ejecutar() async {
    await proveedorSesion.cerrarSesion();
    await limpiarProgresoLocal?.ejecutar();
  }
}
