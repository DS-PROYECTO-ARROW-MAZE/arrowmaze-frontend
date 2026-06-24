import '../../domain/niveles/resumen_nivel.dart';

/// A catalog [ResumenNivel] joined with the player's progression state
/// (Ticket 13, DM §10.3).
///
/// Output of [ObtenerNivelesUseCase]: the View renders one card per entry,
/// showing the lock affordance from [desbloqueado], a "done" mark from
/// [completado], and the badge from [estrellas].
class NivelConEstado {
  /// Creates a level entry decorated with progression state.
  const NivelConEstado({
    required this.resumen,
    required this.desbloqueado,
    required this.completado,
    required this.estrellas,
  });

  /// The level's catalog metadata (id, name, difficulty).
  final ResumenNivel resumen;

  /// Whether the player may open this level now.
  final bool desbloqueado;

  /// Whether the player has cleared this level at least once (true even for a
  /// zero-star clear).
  final bool completado;

  /// Best stars earned on this level (0–3); `0` when not yet cleared.
  final int estrellas;
}
