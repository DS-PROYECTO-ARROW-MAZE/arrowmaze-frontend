import '../../domain/sesion/perfil.dart';
import '../../domain/sesion/usuario_registrado.dart';

/// DTO for the `POST /auth/login` response body.
///
/// Expected shape: `{ "token": "eyJhbGci..." }`.
class AuthResponseDto {
  /// Creates a login response DTO.
  const AuthResponseDto({required this.token});

  /// Parses the login response JSON.
  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(token: json['token'] as String);
  }

  /// The issued JWT.
  final String token;
}

/// DTO for the `POST /auth/register` response body.
///
/// Expected shape:
/// ```json
/// { "message": "...", "user": { "id": "uuid", "email": "...", "createdAt": "date" } }
/// ```
class RegistroResponseDto {
  /// Creates a register response DTO.
  const RegistroResponseDto({required this.usuario});

  /// Parses the register response JSON.
  factory RegistroResponseDto.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return RegistroResponseDto(
      usuario: UsuarioRegistrado(
        id: user['id'] as String,
        email: user['email'] as String,
        createdAt: DateTime.parse(user['createdAt'] as String),
      ),
    );
  }

  /// The created user, mapped to the domain value object.
  final UsuarioRegistrado usuario;
}

/// DTO for the `GET /auth/me` response body.
///
/// Expected shape: `{ "principal": { "id": "uuid", "email": "..." } }`.
class PerfilResponseDto {
  /// Creates a profile response DTO.
  const PerfilResponseDto({required this.perfil});

  /// Parses the profile response JSON.
  factory PerfilResponseDto.fromJson(Map<String, dynamic> json) {
    final principal = json['principal'] as Map<String, dynamic>;
    return PerfilResponseDto(
      perfil: Perfil(
        id: principal['id'] as String,
        email: principal['email'] as String,
      ),
    );
  }

  /// The authenticated principal, mapped to the domain value object.
  final Perfil perfil;
}
