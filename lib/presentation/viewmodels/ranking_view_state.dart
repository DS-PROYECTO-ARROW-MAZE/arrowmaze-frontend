import '../../domain/ranking/fila_ranking.dart';

/// Ranking status exposed to the View by [RankingViewModel].
enum RankingStatus {
  /// Initial / idle state.
  inicial,

  /// A ranking request is in flight.
  cargando,

  /// Ranking data loaded successfully.
  cargado,

  /// The ranking request failed.
  error,
}

/// The immutable state the [RankingViewModel] exposes to its View.
class RankingViewState {
  /// Creates a ranking view state.
  const RankingViewState({
    this.nivelId = '',
    this.status = RankingStatus.inicial,
    this.entradas = const [],
    this.mensajeError,
    this.mensajeAdvertencia,
  });

  /// The level UUID this ranking is for.
  final String nivelId;

  /// Current ranking lifecycle phase.
  final RankingStatus status;

  /// The ordered ranking entries.
  final List<FilaRanking> entradas;

  /// A user-facing error message, or `null` when no error.
  final String? mensajeError;

  /// A non-blocking warning shown above an otherwise-loaded leaderboard — e.g.
  /// the latest run's upload failed, so the board may be missing it. `null` when
  /// there is nothing to warn about.
  final String? mensajeAdvertencia;

  /// Produces a new state with the specified overrides.
  RankingViewState copyWith({
    String? nivelId,
    RankingStatus? status,
    List<FilaRanking>? entradas,
    String? mensajeError,
    String? mensajeAdvertencia,
  }) {
    return RankingViewState(
      nivelId: nivelId ?? this.nivelId,
      status: status ?? this.status,
      entradas: entradas ?? this.entradas,
      mensajeError: mensajeError,
      mensajeAdvertencia: mensajeAdvertencia,
    );
  }
}
