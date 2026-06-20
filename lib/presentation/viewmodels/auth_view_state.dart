/// The immutable state the [AuthViewModel] exposes to its View.
///
/// Covers the four auth flows: register, login, idle, and signed-in session
/// restoration. New states are produced with [copyWith].
class AuthViewState {
  const AuthViewState({
    this.email = '',
    this.password = '',
    this.username = '',
    this.cargando = false,
    this.autenticado = false,
    this.mensajeError,
    this.esRegistro = false,
  });

  /// Current email field value.
  final String email;

  /// Current password field value.
  final String password;

  /// Current username field value (register only).
  final String username;

  /// Whether an auth request is in flight.
  final bool cargando;

  /// Whether the user has a valid session.
  final bool autenticado;

  /// A user-facing error message, or `null` when no error.
  final String? mensajeError;

  /// Whether the form is in register mode (`true`) or login mode (`false`).
  final bool esRegistro;

  AuthViewState copyWith({
    String? email,
    String? password,
    String? username,
    bool? cargando,
    bool? autenticado,
    String? mensajeError,
    bool? esRegistro,
  }) {
    return AuthViewState(
      email: email ?? this.email,
      password: password ?? this.password,
      username: username ?? this.username,
      cargando: cargando ?? this.cargando,
      autenticado: autenticado ?? this.autenticado,
      mensajeError: mensajeError,
      esRegistro: esRegistro ?? this.esRegistro,
    );
  }
}
