import '../../domain/niveles/dificultad.dart';

/// One level card's render model for the Level Selection screen
/// (Ticket 13, DM §10.4).
///
/// A theme-free MVVM ViewState: the View turns [desbloqueado]/[completado]/
/// [estrellas] into the lock and star affordances. Mapped by
/// [SeleccionNivelesViewModel] from the application's `NivelConEstado`.
class NivelResumenUI {
  /// Creates a level card model.
  const NivelResumenUI({
    required this.id,
    required this.nombre,
    required this.dificultad,
    required this.desbloqueado,
    required this.completado,
    required this.estrellas,
    this.idRemoto,
    this.es3D = false,
  });

  /// The level's sequential id (ordinal). Drives asset loading and unlocks.
  final int id;

  /// The backend level UUID, used as the identity for progress sync and the
  /// leaderboard. `null` when the catalog came from the offline bundle.
  final String? idRemoto;

  /// The level's display name.
  final String nombre;

  /// The level's difficulty.
  final Dificultad dificultad;

  /// Whether this is a depth-aware (3D) board — the card shows "3D" instead
  /// of the difficulty label when this is `true` (ticket 36).
  final bool es3D;

  /// Whether the level can be played now (otherwise it renders locked).
  final bool desbloqueado;

  /// Whether the level has been cleared at least once.
  final bool completado;

  /// Best stars earned (0–3).
  final int estrellas;
}

/// Immutable state for the Level Selection screen.
class SeleccionNivelesViewState {
  /// Creates the selection state.
  const SeleccionNivelesViewState({
    this.cargando = false,
    this.niveles = const [],
    this.mensajeError,
  });

  /// Whether the catalog is loading.
  final bool cargando;

  /// The ordered level cards.
  final List<NivelResumenUI> niveles;

  /// A user-facing error message, or `null` when none.
  final String? mensajeError;

  /// Returns a copy with the given fields replaced.
  SeleccionNivelesViewState copyWith({
    bool? cargando,
    List<NivelResumenUI>? niveles,
    String? mensajeError,
  }) {
    return SeleccionNivelesViewState(
      cargando: cargando ?? this.cargando,
      niveles: niveles ?? this.niveles,
      mensajeError: mensajeError,
    );
  }
}
