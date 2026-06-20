import 'run_completado.dart';

/// Port for the offline-first queue of completed runs (DM-B3, E2).
///
/// Implementations store [RunCompletado]s locally so they survive app restarts.
/// The use case calls [encolar] when a run finishes offline and [vaciar] when
/// uploading a batch; on failure the queue stays intact for retry (AC4).
abstract interface class IColaSincronizacion {
  /// Appends [run] to the pending queue.
  Future<void> encolar(RunCompletado run);

  /// Returns all pending runs in insertion order (oldest first).
  Future<List<RunCompletado>> obtenerPendientes();

  /// Removes all pending runs after a successful batch upload.
  Future<void> vaciar();

  /// The current number of pending runs (for UI badge / status).
  Future<int> cantidadPendientes();
}
