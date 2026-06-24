/// The authenticated principal returned by `GET /auth/me`.
///
/// Pure domain value object — no Flutter, no infrastructure.
class Perfil {
  /// Creates a profile.
  const Perfil({required this.id, required this.email});

  /// The user's unique identifier (server UUID).
  final String id;

  /// The user's email address.
  final String email;
}
