import 'dart:convert';
import 'dart:io';

import '../../application/ports/fuente_autenticacion.dart';
import '../../core/config/api_config.dart';
import '../../core/errors/auth_errors.dart';
import '../dtos/auth_request_dto.dart';
import '../dtos/auth_response_dto.dart';

/// HTTP implementation of [FuenteAutenticacion].
///
/// Makes real HTTP calls to the ArrowMaze backend using `dart:io`'s
/// [HttpClient]. Parses JSON responses and maps errors to typed
/// [AutenticacionException]s so the use case can surface them cleanly.
class FuenteAutenticacionHttp implements FuenteAutenticacion {
  FuenteAutenticacionHttp({HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<String> registrar({
    required String email,
    required String password,
    required String username,
  }) async {
    final dto = AuthRequestRegistroDto(
      email: email,
      password: password,
      username: username,
    );
    final body = jsonEncode(dto.toJson());

    final request = await _client.postUrl(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerPath}'),
    );
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 201) {
      final responseDto = AuthResponseDto.fromJson(
        jsonDecode(responseBody) as Map<String, dynamic>,
      );
      return responseDto.token;
    }

    throw _mapearError(response.statusCode, responseBody);
  }

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final dto = AuthRequestLoginDto(
      email: email,
      password: password,
    );
    final body = jsonEncode(dto.toJson());

    final request = await _client.postUrl(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginPath}'),
    );
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final responseDto = AuthResponseDto.fromJson(
        jsonDecode(responseBody) as Map<String, dynamic>,
      );
      return responseDto.token;
    }

    throw _mapearError(response.statusCode, responseBody);
  }

  AutenticacionException _mapearError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final codigo = json['code'] as String?;
      final mensaje = json['message'] as String? ?? 'Unknown error';
      return AutenticacionException(codigo ?? 'UNKNOWN', mensaje);
    } catch (_) {
      return AutenticacionException(
        AuthErrorCode.servidorError,
        'Server error (HTTP $statusCode)',
      );
    }
  }
}
