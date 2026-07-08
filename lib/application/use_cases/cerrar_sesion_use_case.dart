import '../ports/proveedor_sesion.dart';

/// Clears the user's session token via [ProveedorSesion.cerrarSesion].
///
/// This use case exists so that the application layer owns the logout contract;
/// Views and ViewModels never touch the port directly (DIP). Both logout entry
/// points route through here.
///
/// It deliberately does **not** wipe device-local progression: progress is
/// namespaced per user (Ticket 24), so it is retained on the device and shown
/// again when the same account logs back in. Switching accounts on the next
/// login activates the new user's own namespace, so nothing leaks across.
class CerrarSesionUseCase {
  const CerrarSesionUseCase({required this.proveedorSesion});

  final ProveedorSesion proveedorSesion;

  /// Clears the stored session token — the user is signed out, while their
  /// device-local progress is preserved for their next sign-in.
  Future<void> ejecutar() async {
    await proveedorSesion.cerrarSesion();
  }
}
