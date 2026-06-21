import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_consulta_ranking.dart';
import '../../application/ports/proveedor_sesion.dart';
import '../../core/config/api_config.dart';
import '../../domain/ranking/fila_ranking.dart';
import '../../domain/ranking/ranking_dto.dart';
import '../dtos/ranking_response_dto.dart';

/// HTTP implementation of [IConsultaRanking] — read-only (DM-B5, E3).
///
/// Fetches top-N scores per level from the backend ranking endpoint using
/// `package:http` (cross-platform, web included).
/// Requires a valid session token from [ProveedorSesion].
/// No write path exists (AC2).
class RankingDataSourceHttp implements IConsultaRanking {
  /// Creates the HTTP ranking data source.
  RankingDataSourceHttp({
    required ProveedorSesion proveedorSesion,
    http.Client? client,
  })  : _proveedorSesion = proveedorSesion,
        _client = client ?? http.Client();

  final ProveedorSesion _proveedorSesion;
  final http.Client _client;

  @override
  Future<RankingDto> obtenerTop(int idNivel, int limite) async {
    final token = await _proveedorSesion.obtenerToken();
    if (token == null) {
      return const RankingDto(filas: []);
    }

    try {
      final response = await _client.get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.rankingPath}/$idNivel?limite=$limite',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        return const RankingDto(filas: []);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final dto = RankingResponseDto.fromJson(json);

      return RankingDto(
        filas: dto.filas
            .map((f) => FilaRanking(
                  posicion: f.posicion,
                  nombreJugador: f.nombreJugador,
                  puntaje: f.puntaje,
                  estrellas: f.estrellas,
                ))
            .toList(),
      );
    } catch (_) {
      return const RankingDto(filas: []);
    }
  }
}
