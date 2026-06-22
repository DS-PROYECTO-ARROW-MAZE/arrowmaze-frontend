/// Port for **local** progression state — the unlock source of truth
/// (Ticket 13, DM §10.1).
///
/// Deliberately separate from the offline-sync upload path
/// ([IRepositorioProgreso] / [IColaSincronizacion], which only *push* completed
/// runs to the server): this port answers "which levels are done and with how
/// many stars" for the Level Selection screen. The DM doc named this
/// `ConsultaProgresoLocal`.
///
/// It intentionally does **not** take a `RunCompletado` on write — progression
/// only needs the level id and its star count, so it stays decoupled from the
/// sync value object.
abstract interface class ConsultaProgresoLocal {
  /// The set of level ids the player has cleared at least once.
  Future<Set<int>> nivelesCompletados();

  /// The best star rating (0–3) recorded for [idNivel]; `0` if never cleared.
  Future<int> mejorEstrellas(int idNivel);

  /// Records a clear of [idNivel] with [estrellas], keeping the best result.
  ///
  /// A first clear with 0 stars still marks the level completed (so the next
  /// level unlocks); a later clear only raises the stored star count.
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  });

  /// Wipes **all** recorded progression (every completed level and star count).
  ///
  /// Called on logout and on a fresh login/register so one account's unlocks
  /// never leak into another's: progression is device-local (there is no
  /// server-side read path), so a clean slate is the only way to guarantee the
  /// next session renders solely the signed-in user's progress.
  Future<void> limpiar();
}
