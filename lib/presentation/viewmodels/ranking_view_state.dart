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
  });

  /// The level UUID this ranking is for.
  final String nivelId;

  /// Current ranking lifecycle phase.
  final RankingStatus status;

  /// The ordered ranking entries.
  final List<FilaRanking> entradas;

  /// A user-facing error message, or `null` when no error.
  final String? mensajeError;

  /// Produces a new state with the specified overrides.
  RankingViewState copyWith({
    String? nivelId,
    RankingStatus? status,
    List<FilaRanking>? entradas,
    String? mensajeError,
  }) {
    return RankingViewState(
      nivelId: nivelId ?? this.nivelId,
      status: status ?? this.status,
      entradas: entradas ?? this.entradas,
      mensajeError: mensajeError,
    );
  }
}
