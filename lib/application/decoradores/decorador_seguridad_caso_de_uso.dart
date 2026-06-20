import '../ports/proveedor_sesion.dart';
import 'decorador_caso_de_uso.dart';
import 'sesion_requerida_exception.dart';

/// Decorator that guards the wrapped use case behind an active session (DM-F9).
///
/// Reads the token through the **injected** [ProveedorSesion] port — never a
/// static/global accessor (AC3). If no token is present the use case is not
/// executed and a [SesionRequeridaException] is thrown; otherwise [envuelto]
/// runs and its result is returned unchanged (AC1).
class DecoradorSeguridadCasoDeUso<E, S> extends DecoradorCasoDeUso<E, S> {
  /// Wraps [envuelto], reading the session through [sesion].
  const DecoradorSeguridadCasoDeUso(
    super.envuelto, {
    required ProveedorSesion sesion,
  }) : _sesion = sesion;

  final ProveedorSesion _sesion;

  @override
  Future<S> ejecutar(E entrada) async {
    final token = await _sesion.obtenerToken();
    if (token == null || token.isEmpty) {
      throw const SesionRequeridaException();
    }
    return envuelto.ejecutar(entrada);
  }
}
