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
    this.idRemoto,
    this.es3D = false,
  });

  /// The level's sequential ordinal (1, 2, 3, …) — the `numero`. Drives local
  /// asset loading, unlock order, and progression. This is **not** the backend
  /// primary key.
  final int id;

  /// The backend level **UUID**, when this entry came from the remote catalog
  /// (`GET /levels`). Used as the identity for progress sync and the
  /// leaderboard, which key by UUID. `null` for the bundled/offline catalog,
  /// in which case those server features are unavailable for the level.
  final String? idRemoto;

  /// The human-readable level name shown on the card.
  final String nombre;

  /// The level's difficulty (a value, not a subtype).
  final Dificultad dificultad;

  /// Whether this is a depth-aware (3D) board — the rotatable-cube view
  /// (ticket 36), not a difficulty tier. Kept separate from [dificultad] on
  /// purpose: a 3D board still has an ordinary [dificultad] for internal
  /// tuning (timer, hint gate); the Level Selection card shows "3D" here
  /// *instead of* the difficulty label, which is a presentation choice, not a
  /// reason to invent a fake difficulty value.
  final bool es3D;
}
