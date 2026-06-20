/// DTO for the register request body.
class AuthRequestRegistroDto {
  const AuthRequestRegistroDto({
    required this.email,
    required this.password,
    required this.username,
  });

  final String email;
  final String password;
  final String username;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'username': username,
      };
}

/// DTO for the login request body.
class AuthRequestLoginDto {
  const AuthRequestLoginDto({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}
