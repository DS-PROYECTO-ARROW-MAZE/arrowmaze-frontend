import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_consulta_progreso_remoto.dart';
import '../../application/ports/i_registro.dart';
import '../../application/ports/progreso_remoto_item.dart';
import '../../core/config/api_config.dart';
import '../dtos/progreso_remoto_response_dto.dart';

/// HTTP implementation of [IConsultaProgresoRemoto] — `GET /progress` (Ticket 24).
///
/// Fetches the authenticated player's server-side progression using
/// `package:http`. The injected [http.Client] is expected to be a
/// `ClienteHttpAutenticado`, so the Bearer token is attached transparently.
/// On any failure (network, non-200, malformed JSON) it degrades gracefully to
/// an empty list rather than throwing at the UI — but the failure is reported
/// through the optional [IRegistro] so a silent restore never hides a real
/// break (a non-200 status or a response-shape drift) again.
class ProgresoRemotoDataSourceHttp implements IConsultaProgresoRemoto {
  /// Creates the HTTP progress-read data source. Tests inject a mock [client].
  ///
  /// [registro], when wired, receives an `error` log on a non-200 response or a
  /// thrown network/parse failure — the diagnostics that were previously
  /// swallowed silently.
  ProgresoRemotoDataSourceHttp({http.Client? client, IRegistro? registro})
      : _client = client ?? http.Client(),
        _registro = registro;

  final http.Client _client;
  final IRegistro? _registro;

  @override
  Future<List<ProgresoRemotoItem>> obtenerProgreso() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.progressPath}');
      final response = await _client.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        _registro?.error(
          'Restore of progress (GET ${ApiConfig.progressPath}) failed with '
          'status ${response.statusCode}.',
        );
        return [];
      }

      // The backend returns a bare JSON array (`ProgresoRespuestaDto[]`), not an
      // object envelope — decode it as a list and map each element.
      final lista = jsonDecode(response.body) as List<dynamic>;
      return lista
          .map((e) =>
              ProgresoRemotoItemDto.fromJson(e as Map<String, dynamic>).toEntidad())
          .toList();
    } catch (e) {
      _registro?.error(
        'Restore of progress (GET ${ApiConfig.progressPath}) threw '
        '(network error or response-shape mismatch): $e',
      );
      return [];
    }
  }
}