import '../../application/ports/i_medidor_metricas.dart';

/// A single recorded measurement: one use-case invocation.
class MuestraMetrica {
  /// Creates a measurement for [operacion].
  const MuestraMetrica({
    required this.operacion,
    required this.duracion,
    required this.exito,
  });

  /// The labelled use case that was timed.
  final String operacion;

  /// How long it took.
  final Duration duracion;

  /// Whether it completed without throwing.
  final bool exito;
}

/// Infrastructure adapter: an in-memory [IMedidorMetricas].
///
/// Accumulates [MuestraMetrica] samples — useful for tests, dev dashboards, and
/// as a seam that a real StatsD/OTel exporter can replace without touching the
/// application layer (AC2).
class MedidorMetricasSimple implements IMedidorMetricas {
  /// Creates an empty in-memory meter.
  MedidorMetricasSimple();

  final List<MuestraMetrica> _muestras = <MuestraMetrica>[];

  /// An unmodifiable view of every recorded sample.
  List<MuestraMetrica> get muestras => List.unmodifiable(_muestras);

  @override
  void registrar(
    String operacion, {
    required Duration duracion,
    required bool exito,
  }) {
    _muestras.add(
      MuestraMetrica(operacion: operacion, duracion: duracion, exito: exito),
    );
  }
}
