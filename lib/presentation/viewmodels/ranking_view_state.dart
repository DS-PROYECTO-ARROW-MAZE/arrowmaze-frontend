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
    this.idNivel = 0,
    this.status = RankingStatus.inicial,
    this.filas = const [],
    this.mensajeError,
  });

  /// The level ID this ranking is for.
  final int idNivel;

  /// Current ranking lifecycle phase.
  final RankingStatus status;

  /// The ordered ranking rows.
  final List<FilaRanking> filas;

  /// A user-facing error message, or `null` when no error.
  final String? mensajeError;

  /// Produces a new state with the specified overrides.
  RankingViewState copyWith({
    int? idNivel,
    RankingStatus? status,
    List<FilaRanking>? filas,
    String? mensajeError,
  }) {
    return RankingViewState(
      idNivel: idNivel ?? this.idNivel,
      status: status ?? this.status,
      filas: filas ?? this.filas,
      mensajeError: mensajeError,
    );
  }
}
