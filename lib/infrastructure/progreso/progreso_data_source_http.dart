import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_repositorio_progreso.dart';
import '../../core/config/api_config.dart';
import '../../domain/progreso/run_completado.dart';
import '../dtos/progreso_sync_dto.dart';
import '../dtos/sync_request_dto.dart';

/// HTTP implementation of [IRepositorioProgreso] — `POST /progress/sync`.
///
/// Sends a single POST with the full batch of queued runs using `package:http`
/// (cross-platform, web included). The injected [http.Client] is expected to be
/// a `ClienteHttpAutenticado`, so the Bearer token is attached transparently.
class ProgresoDataSourceHttp implements IRepositorioProgreso {
  /// Creates the HTTP progress data source. Tests inject a mock/authenticated
  /// [client].
  ProgresoDataSourceHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<bool> guardarLote(List<RunCompletado> runs) async {
    final progresos = runs
        .map((r) => ProgresoSyncDto(
              nivelId: r.nivelId,
              estrellas: r.estrellas,
              movimientos: r.movimientos,
              tiempoSegundos: r.tiempoSegundos,
              completadoEn: r.completadoEn.toUtc().toIso8601String(),
            ))
        .toList();

    final body = jsonEncode(SyncRequestDto(progresos: progresos).toJson());

    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.syncPath}'),
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
