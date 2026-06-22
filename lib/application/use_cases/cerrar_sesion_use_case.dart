import '../ports/proveedor_sesion.dart';

/// Clears the user's session token via [ProveedorSesion.cerrarSesion].
///
/// This use case exists so that the application layer owns the logout
/// contract; Views and ViewModels never touch the port directly (DIP).
class CerrarSesionUseCase {
  const CerrarSesionUseCase({required this.proveedorSesion});

  final ProveedorSesion proveedorSesion;

  /// Clears any stored session token — the user is signed out.
  Future<void> ejecutar() => proveedorSesion.cerrarSesion();
}
