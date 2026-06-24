/// A minimal clock abstraction the presentation layer uses to drive a level's
/// countdown timer (DM-F8). The concrete implementation lives in infrastructure
/// (e.g. `Timer.periodic`), so the ViewModel never depends on platform timers.
abstract interface class Reloj {
  /// Starts a periodic tick every [intervalo], calling [tic] on each pulse.
  /// Any previously running tick is stopped first.
  void iniciar(Duration intervalo, void Function() tic);

  /// Stops the running tick, if any. Safe to call when no tick is active.
  void detener();
}
