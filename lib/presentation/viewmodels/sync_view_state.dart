/// The sync status exposed to the View by [SyncViewModel].
enum SyncStatus {
  /// Completed runs are queued offline, waiting for sync.
  enCola,

  /// A batch sync is in progress.
  sincronizando,

  /// The batch sync succeeded; queue is now empty.
  sincronizado,

  /// The batch sync failed; queue is intact for retry.
  error,
}

/// The immutable state the [SyncViewModel] exposes to the View.
class SyncViewState {
  /// Creates a sync view state.
  const SyncViewState({
    this.status = SyncStatus.enCola,
    this.pendientes = 0,
    this.mensajeError,
  });

  /// Current sync lifecycle phase.
  final SyncStatus status;

  /// Number of runs waiting in the offline queue.
  final int pendientes;

  /// A user-facing error message, or `null` when no error.
  final String? mensajeError;

  /// Produces a new state with the specified overrides.
  SyncViewState copyWith({
    SyncStatus? status,
    int? pendientes,
    String? mensajeError,
  }) {
    return SyncViewState(
      status: status ?? this.status,
      pendientes: pendientes ?? this.pendientes,
      mensajeError: mensajeError,
    );
  }
}
