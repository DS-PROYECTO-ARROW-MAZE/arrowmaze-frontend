import '../../domain/evento_juego.dart';
import '../../domain/observador_juego.dart';

/// The one honest GoF Singleton for audio (DM-F7, ticket 07).
///
/// Reacts to game events that carry an audio cue — [TipoEvento.flechaEliminada]
/// (arrow-exit sound) and [TipoEvento.victoria] (victory fanfare) — without
/// knowing anything about the game rules that produced those events.
///
/// Registered with the [PublicadorEventosJuego] at the composition root
/// (`Inyeccion`). All other event types are silently ignored, which keeps the
/// switch exhaustive as new event kinds are added.
///
/// **No audio package is bundled yet.** The play methods are stubs that will be
/// wired to an asset-based player in a later infrastructure ticket. The
/// Singleton shell and the Observer wiring are the deliverables for ticket 07.
class AudioServiceImp implements ObservadorJuego {
  AudioServiceImp._();

  /// The single shared instance across the app's lifetime.
  static final AudioServiceImp instance = AudioServiceImp._();

  @override
  void alOcurrirEvento(EventoJuego evento) {
    switch (evento.tipo) {
      case TipoEvento.flechaEliminada:
        _reproducirSonidoFlecha();
      case TipoEvento.victoria:
        _reproducirSonidoVictoria();
      case TipoEvento.movimientoRealizado:
      case TipoEvento.movimientoInvalido:
      case TipoEvento.coleccionableRecogido:
        // No audio cue for these event kinds.
        break;
    }
  }

  // Plays the short arrow-exit clip. Wired to an asset player in a later
  // ticket; stubbed here so the Observer chain is complete.
  void _reproducirSonidoFlecha() {}

  // Plays the victory fanfare. Wired to an asset player in a later ticket.
  void _reproducirSonidoVictoria() {}
}
