import '../ports/i_medidor_metricas.dart';
import 'decorador_caso_de_uso.dart';

/// Decorator that times the wrapped use case (DM-F9).
///
/// Measures wall-clock duration with a plain [Stopwatch] (pure `dart:core`) and
/// reports it through the injected [IMedidorMetricas] port — no metrics library
/// is imported here (AC2). The timing is recorded for both success and failure,
/// and the result/exception of [envuelto] is passed through unchanged (AC1).
class DecoradorMetricasCasoDeUso<E, S> extends DecoradorCasoDeUso<E, S> {
  /// Wraps [envuelto], reporting under the label [nombre] via [metricas].
  const DecoradorMetricasCasoDeUso(
    super.envuelto, {
    required IMedidorMetricas metricas,
    required String nombre,
  })  : _metricas = metricas,
        _nombre = nombre;

  final IMedidorMetricas _metricas;
  final String _nombre;

  @override
  Future<S> ejecutar(E entrada) async {
    final cronometro = Stopwatch()..start();
    try {
      final salida = await envuelto.ejecutar(entrada);
      cronometro.stop();
      _metricas.registrar(_nombre, duracion: cronometro.elapsed, exito: true);
      return salida;
    } catch (_) {
      cronometro.stop();
      _metricas.registrar(_nombre, duracion: cronometro.elapsed, exito: false);
      rethrow;
    }
  }
}
