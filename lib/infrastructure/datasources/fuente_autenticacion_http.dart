import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/fuente_autenticacion.dart';
import '../../core/config/api_config.dart';
import '../../core/errors/auth_errors.dart';
import '../dtos/auth_request_dto.dart';
import '../dtos/auth_response_dto.dart';

/// HTTP implementation of [FuenteAutenticacion].
///
/// Makes real HTTP calls to the ArrowMaze backend using `package:http`'s
/// [http.Client], which works on every Flutter target (mobile, desktop and
/// web). Parses JSON responses and maps errors to typed
/// [AutenticacionException]s so the use case can surface them cleanly.
class FuenteAutenticacionHttp implements FuenteAutenticacion {
  FuenteAutenticacionHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

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

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerPath}'),
      headers: _jsonHeaders,
      body: body,
    );

    if (response.statusCode == 201) {
      final responseDto = AuthResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      return responseDto.token;
    }

    throw _mapearError(response.statusCode, response.body);
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

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginPath}'),
      headers: _jsonHeaders,
      body: body,
    );

    if (response.statusCode == 200) {
      final responseDto = AuthResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      return responseDto.token;
    }

    throw _mapearError(response.statusCode, response.body);
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
