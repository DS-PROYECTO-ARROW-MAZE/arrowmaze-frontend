import '../../domain/ranking/ranking_dto.dart';
import '../ports/i_consulta_ranking.dart';

/// Use case: fetch the top-N leaderboard for a level (DM-B5, E3).
///
/// Read-only — delegates to [IConsultaRanking.obtenerTop].
/// No write path exists on the client (AC2).
class ConsultarRankingUseCase {
  /// Creates the use case with an injected read port.
  ConsultarRankingUseCase({required IConsultaRanking consulta})
      : _consulta = consulta;

  final IConsultaRanking _consulta;

  /// Returns the top [limite] scores for level [nivelId].
  Future<RankingDto> obtenerTop({
    required String nivelId,
    required int limite,
  }) {
    return _consulta.obtenerTop(nivelId, limite);
  }
}
