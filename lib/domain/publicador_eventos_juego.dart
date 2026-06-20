import 'evento_juego.dart';
import 'observador_juego.dart';

/// The Subject in the game-event Observer pattern (DM-F7, GoF).
///
/// Maintains a registry of [ObservadorJuego]s and fans out each [EventoJuego]
/// to every registered observer. Pure Dart — no Flutter, no audio, no UI.
///
/// The use case holds a reference to the publisher and calls [publicar] after
/// each move; audio, score, and HUD observers register themselves at the
/// composition root (see `Inyeccion`).
class PublicadorEventosJuego {
  final List<ObservadorJuego> _observadores = [];

  /// Adds [observador] to the registry; it will receive all future events.
  void suscribir(ObservadorJuego observador) => _observadores.add(observador);

  /// Removes [observador] from the registry; it will receive no further events.
  void desuscribir(ObservadorJuego observador) =>
      _observadores.remove(observador);

  /// Delivers [evento] to every currently subscribed [ObservadorJuego].
  ///
  /// Iterates a snapshot of the registry so observers may safely unsubscribe
  /// from within their own [ObservadorJuego.alOcurrirEvento] callback.
  void publicar(EventoJuego evento) {
    for (final observador in List.of(_observadores)) {
      observador.alOcurrirEvento(evento);
    }
  }
}
