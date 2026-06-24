/// DTO for the `POST /auth/register` request body.
///
/// The real backend expects only `{ email, password }` — no username.
class AuthRequestRegistroDto {
  /// Creates a register request DTO.
  const AuthRequestRegistroDto({
    required this.email,
    required this.password,
  });

  /// The new account's email.
  final String email;

  /// The new account's password.
  final String password;

  /// Serializes to the request JSON shape.
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// DTO for the `POST /auth/login` request body.
class AuthRequestLoginDto {
  /// Creates a login request DTO.
  const AuthRequestLoginDto({
    required this.email,
    required this.password,
  });

  /// The account's email.
  final String email;

  /// The account's password.
  final String password;

  /// Serializes to the request JSON shape.
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}
