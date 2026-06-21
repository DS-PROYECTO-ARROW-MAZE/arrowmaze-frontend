import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/i_repositorio_progreso.dart';
import '../../core/config/api_config.dart';
import '../../domain/progreso/run_completado.dart';
import '../../application/ports/proveedor_sesion.dart';
import '../dtos/sync_request_dto.dart';
import '../dtos/sync_run_dto.dart';

/// HTTP implementation of [IRepositorioProgreso].
///
/// Sends a single POST with the full batch of queued runs using `package:http`
/// (cross-platform, web included).
/// Requires a valid session token from [ProveedorSesion].
class ProgresoDataSourceHttp implements IRepositorioProgreso {
  /// Creates the HTTP progress data source.
  ProgresoDataSourceHttp({
    required ProveedorSesion proveedorSesion,
    http.Client? client,
  })  : _proveedorSesion = proveedorSesion,
        _client = client ?? http.Client();

  final ProveedorSesion _proveedorSesion;
  final http.Client _client;

  @override
  Future<bool> guardarLote(List<RunCompletado> runs) async {
    final token = await _proveedorSesion.obtenerToken();
    if (token == null) return false;

    final runDtos = runs
        .map((r) => SyncRunDto(
              nivelId: r.nivelId,
              movimientos: r.movimientos,
              segundosRestantes: r.segundosRestantes,
              puntaje: r.puntaje,
              estrellas: r.estrellas,
              completadoEn: r.completadoEn.toUtc().toIso8601String(),
            ))
        .toList();

    final syncDto = SyncRequestDto(runs: runDtos);
    final body = jsonEncode(syncDto.toJson());

    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.syncPath}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
