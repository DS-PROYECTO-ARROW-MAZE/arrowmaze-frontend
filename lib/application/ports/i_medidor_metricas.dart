/// Port for use-case telemetry (DIP).
///
/// The application layer records timings through this abstraction; the concrete
/// meter (in-memory, StatsD, …) lives in infrastructure (e.g.
/// `MedidorMetricasSimple`). No metrics library ever reaches the application or
/// domain layers (AC2).
abstract interface class IMedidorMetricas {
  /// Records that the use case named [operacion] finished, whether it succeeded
  /// ([exito]) and how long it took ([duracion]).
  void registrar(
    String operacion, {
    required Duration duracion,
    required bool exito,
  });
}
