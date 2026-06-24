import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/fuente_niveles.dart';
import '../../core/config/api_config.dart';
import '../../domain/niveles/definicion_nivel_remota.dart';
import '../../domain/niveles/nivel_creado.dart';
import '../dtos/crear_nivel_request_dto.dart';
import '../dtos/nivel_creado_response_dto.dart';

/// HTTP implementation of [FuenteNiveles] — `POST /levels` (protected) (AC2).
///
/// Sends the level definition and parses the created level. The injected
/// [http.Client] is expected to be a `ClienteHttpAutenticado`, so the Bearer
/// token is attached transparently.
class NivelesDataSourceHttp implements FuenteNiveles {
  /// Creates the HTTP levels data source. Tests inject a mock/authenticated
  /// [client].
  NivelesDataSourceHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<NivelCreado> crear(DefinicionNivelRemota definicion) async {
    final dto = CrearNivelRequestDto(definicion);

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.levelsPath}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return NivelCreadoResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).nivel;
    }

    throw Exception(
      'No se pudo crear el nivel (HTTP ${response.statusCode}).',
    );
  }
}
