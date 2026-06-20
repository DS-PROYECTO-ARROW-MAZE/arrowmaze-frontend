import '../../domain/progreso/run_completado.dart';

/// Port for the remote progress API (DM-B3, E2).
///
/// Implementations make a single batch HTTP POST with the full queue payload.
/// The use case depends on this port — never on HTTP or infrastructure.
abstract interface class IRepositorioProgreso {
  /// Uploads [runs] as a single batch request. Returns `true` on success.
  ///
  /// On failure the caller is responsible for keeping the queue intact (AC4).
  Future<bool> guardarLote(List<RunCompletado> runs);
}
