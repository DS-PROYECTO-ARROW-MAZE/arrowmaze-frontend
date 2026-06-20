import '../../application/ports/proveedor_sesion.dart';

/// In-memory implementation of [ProveedorSesion].
///
/// Stores the session token in a simple field. Future versions may back this
/// with `flutter_secure_storage` or `shared_preferences` without changing the
/// use cases or views — DIP is satisfied.
class ProveedorSesionImpl implements ProveedorSesion {
  String? _token;

  @override
  Future<String?> obtenerToken() async => _token;

  @override
  Future<void> guardarToken(String token) async {
    _token = token;
  }

  @override
  Future<void> cerrarSesion() async {
    _token = null;
  }
}
