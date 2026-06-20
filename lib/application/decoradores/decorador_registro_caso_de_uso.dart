import '../ports/i_registro.dart';
import 'decorador_caso_de_uso.dart';

/// Decorator that logs the lifecycle of the wrapped use case (DM-F9).
///
/// Logs through the injected [IRegistro] port only — no logging library is
/// imported here (AC2). On failure it logs the error and rethrows, leaving the
/// result and exception of [envuelto] untouched (AC1).
class DecoradorRegistroCasoDeUso<E, S> extends DecoradorCasoDeUso<E, S> {
  /// Wraps [envuelto], logging under the label [nombre] via [registro].
  const DecoradorRegistroCasoDeUso(
    super.envuelto, {
    required IRegistro registro,
    required String nombre,
  })  : _registro = registro,
        _nombre = nombre;

  final IRegistro _registro;
  final String _nombre;

  @override
  Future<S> ejecutar(E entrada) async {
    _registro.info('→ $_nombre');
    try {
      final salida = await envuelto.ejecutar(entrada);
      _registro.info('← $_nombre ok');
      return salida;
    } catch (e) {
      _registro.error('✗ $_nombre: $e');
      rethrow;
    }
  }
}
