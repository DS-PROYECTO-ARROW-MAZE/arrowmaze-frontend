import 'dificultad.dart';

/// A catalog entry for one level — pure metadata, no board (Ticket 13, DM §10.2).
///
/// This is what the Level Selection screen lists. It deliberately carries **no**
/// progression state (locked/stars): unlock and star data are layered on by the
/// application use case ([ObtenerNivelesUseCase]) so the domain summary stays a
/// free-standing value object. The playable [Tablero] is loaded separately via
/// [CargadorNivel] only once a level is chosen.
class ResumenNivel {
  /// Creates a level catalog entry.
  const ResumenNivel({
    required this.id,
    required this.nombre,
    required this.dificultad,
  });

  /// The level's unique, sequential identifier (1, 2, 3, …).
  final int id;

  /// The human-readable level name shown on the card.
  final String nombre;

  /// The level's difficulty (a value, not a subtype).
  final Dificultad dificultad;
}
