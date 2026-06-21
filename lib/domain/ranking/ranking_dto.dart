import 'fila_ranking.dart';

/// The read-only projection returned by [IConsultaRanking.obtenerTop] (DM-B5, E3).
///
/// Carries the top-N entries for a given `(nivelId, limite)` request.
/// Immutable, no Flutter dependency — lives in the domain layer.
class RankingDto {
  /// Creates a ranking DTO.
  const RankingDto({required this.entradas});

  /// The ordered list of ranking entries (position 1 = best score).
  final List<FilaRanking> entradas;
}
