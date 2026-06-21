import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/fuente_autenticacion.dart';
import '../../core/config/api_config.dart';
import '../../core/errors/auth_errors.dart';
import '../../domain/sesion/perfil.dart';
import '../../domain/sesion/usuario_registrado.dart';
import '../dtos/auth_request_dto.dart';
import '../dtos/auth_response_dto.dart';

/// HTTP implementation of [FuenteAutenticacion].
///
/// Makes real HTTP calls to the ArrowMaze NestJS backend using `package:http`'s
/// [http.Client], which works on every Flutter target (mobile, desktop and
/// web). Parses JSON responses and maps errors to typed
/// [AutenticacionException]s so the use cases can surface them cleanly.
///
/// The injected client may be a [ClienteHttpAutenticado]; `/auth/me` is
/// protected, so the interceptor attaches the Bearer token transparently —
/// this data source never reads the token itself.
class FuenteAutenticacionHttp implements FuenteAutenticacion {
  /// Creates the HTTP auth data source. Tests inject a mock [client].
  FuenteAutenticacionHttp({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  @override
  Future<UsuarioRegistrado> registrar({
    required String email,
    required String password,
  }) async {
    final dto = AuthRequestRegistroDto(email: email, password: password);

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerPath}'),
      headers: _jsonHeaders,
      body: jsonEncode(dto.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return RegistroResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).usuario;
    }

    throw _mapearError(response.statusCode, response.body);
  }

  @override
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final dto = AuthRequestLoginDto(email: email, password: password);

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginPath}'),
      headers: _jsonHeaders,
      body: jsonEncode(dto.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AuthResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).token;
    }

    throw _mapearError(response.statusCode, response.body);
  }

  @override
  Future<Perfil> obtenerPerfil() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.mePath}'),
      headers: _jsonHeaders,
    );

    if (response.statusCode == 200) {
      return PerfilResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).perfil;
    }

    throw _mapearError(response.statusCode, response.body);
  }

  /// Maps an HTTP failure to a typed [AutenticacionException].
  ///
  /// The error code is derived from the status code so it does not depend on a
  /// particular backend error envelope; the human message is taken from the
  /// body's `message` field when present.
  AutenticacionException _mapearError(int statusCode, String body) {
    final codigo = switch (statusCode) {
      409 => AuthErrorCode.emailDuplicado,
      401 || 403 => AuthErrorCode.credencialesInvalidas,
      _ => AuthErrorCode.servidorError,
    };
    return AutenticacionException(codigo, _extraerMensaje(body, statusCode));
  }

  /// Pulls a display message out of a NestJS-style error body, where `message`
  /// may be a string or a list of strings.
  String _extraerMensaje(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final mensaje = json['message'];
      if (mensaje is String) return mensaje;
      if (mensaje is List && mensaje.isNotEmpty) return mensaje.join(', ');
    } catch (_) {
      // Body was not JSON — fall through to a generic message.
    }
    return 'Server error (HTTP $statusCode)';
  }
}
