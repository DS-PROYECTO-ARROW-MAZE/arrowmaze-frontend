/// A freshly created account, as returned by `POST /auth/register`.
///
/// Pure domain value object — no Flutter, no infrastructure. The register
/// endpoint does not issue a token, so authentication happens on a subsequent
/// login.
class UsuarioRegistrado {
  /// Creates a registered-user value object.
  const UsuarioRegistrado({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  /// The new user's unique identifier (server UUID).
  final String id;

  /// The registered email address.
  final String email;

  /// When the account was created (server timestamp).
  final DateTime createdAt;
}
