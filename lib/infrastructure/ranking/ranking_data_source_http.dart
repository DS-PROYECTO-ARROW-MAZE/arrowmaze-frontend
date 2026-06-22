import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_consulta_ranking.dart';
import '../../core/config/api_config.dart';
import '../../domain/ranking/ranking_dto.dart';
import '../dtos/ranking_response_dto.dart';

/// HTTP implementation of [IConsultaRanking] — read-only (DM-B5, E3).
///
/// Fetches top-N scores per level from `GET /leaderboard?idNivel=&limite=`
/// using `package:http` (cross-platform, web included). The injected
/// [http.Client] is expected to be a `ClienteHttpAutenticado`, so the Bearer
/// token is attached transparently. No write path exists (AC2). On any failure
/// it degrades to an empty ranking rather than throwing at the UI.
class RankingDataSourceHttp implements IConsultaRanking {
  /// Creates the HTTP ranking data source. Tests inject a mock/authenticated
  /// [client].
  RankingDataSourceHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<RankingDto> obtenerTop(String nivelId, int limite) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboardPath}')
          .replace(queryParameters: {
        'idNivel': nivelId,
        'limite': '$limite',
      });

      final response = await _client.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return const RankingDto(entradas: []);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final dto = RankingResponseDto.fromJson(json);

      return RankingDto(
        entradas: dto.entradas.map((e) => e.toEntidad()).toList(),
      );
    } catch (_) {
      return const RankingDto(entradas: []);
    }
  }
}
