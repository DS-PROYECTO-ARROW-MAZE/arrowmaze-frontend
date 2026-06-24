/// The difficulty of a level — a value, never a subtype (Q11, ADR §2).
///
/// Difficulty is *data*: it drives presentation (badges, ordering hints) but
/// never spawns `NivelFacil`/`NivelMedio`/`NivelDificil` classes.
enum Dificultad {
  /// Easy level.
  facil,

  /// Medium level.
  medio,

  /// Hard level.
  dificil;

  /// The token the backend API uses for this difficulty
  /// (`FACIL`/`MEDIO`/`DIFICIL`), as expected by `POST /levels`.
  String get apiToken => switch (this) {
        Dificultad.facil => 'FACIL',
        Dificultad.medio => 'MEDIO',
        Dificultad.dificil => 'DIFICIL',
      };

  /// Maps the JSON `difficulty` token (`easy`/`medium`/`hard`) to a [Dificultad].
  ///
  /// Unknown or missing tokens fall back to [Dificultad.facil] so a malformed
  /// level file degrades gracefully instead of crashing the catalog.
  static Dificultad desde(String? token) {
    switch (token?.toLowerCase()) {
      case 'medium':
      case 'medio':
        return Dificultad.medio;
      case 'hard':
      case 'dificil':
        return Dificultad.dificil;
      case 'easy':
      case 'facil':
      default:
        return Dificultad.facil;
    }
  }
}
