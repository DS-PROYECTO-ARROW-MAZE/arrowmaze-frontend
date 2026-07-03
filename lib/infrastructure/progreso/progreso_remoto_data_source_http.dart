import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_consulta_progreso_remoto.dart';
import '../../application/ports/progreso_remoto_item.dart';
import '../../core/config/api_config.dart';
import '../dtos/progreso_remoto_response_dto.dart';

/// HTTP implementation of [IConsultaProgresoRemoto] — `GET /progress` (Ticket 24).
///
/// Fetches the authenticated player's server-side progression using
/// `package:http`. The injected [http.Client] is expected to be a
/// `ClienteHttpAutenticado`, so the Bearer token is attached transparently.
/// On any failure (network, non-200, malformed JSON) it degrades gracefully to
/// an empty list rather than throwing at the UI.
class ProgresoRemotoDataSourceHttp implements IConsultaProgresoRemoto {
  /// Creates the HTTP progress-read data source. Tests inject a mock [client].
  ProgresoRemotoDataSourceHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<ProgresoRemotoItem>> obtenerProgreso() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.progressPath}');
      final response = await _client.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final dto = ProgresoRemotoResponseDto.fromJson(json);

      return dto.niveles.map((e) => e.toEntidad()).toList();
    } catch (_) {
      return [];
    }
  }
}