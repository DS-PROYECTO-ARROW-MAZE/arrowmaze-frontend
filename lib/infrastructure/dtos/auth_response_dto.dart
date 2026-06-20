/// DTO for the auth response body.
///
/// Expected shape:
/// ```json
/// { "token": "eyJhbGci..." }
/// ```
class AuthResponseDto {
  const AuthResponseDto({required this.token});

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String,
    );
  }

  final String token;
}
