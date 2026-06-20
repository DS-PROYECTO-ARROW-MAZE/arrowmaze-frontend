import 'evento_juego.dart';

/// The Observer role in the game-event Observer pattern (DM-F7, GoF).
///
/// Any component that wants to react to game events — audio, score, HUD —
/// implements this interface and registers with a [PublicadorEventosJuego].
/// The use case that *produces* events knows nothing about its observers:
/// it only holds a reference to the publisher and calls `publicar`.
///
/// This contract is **distinct** from the MVVM data-binding: `ChangeNotifier`
/// / `notifyListeners()` is the View↔ViewModel channel, not this interface.
abstract interface class ObservadorJuego {
  /// Called by the publisher each time a [EventoJuego] is emitted.
  void alOcurrirEvento(EventoJuego evento);
}
