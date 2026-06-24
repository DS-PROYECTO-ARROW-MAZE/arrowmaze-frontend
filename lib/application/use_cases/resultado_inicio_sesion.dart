/// The result of [IniciarSesionUseCase.ejecutar].
sealed class ResultadoInicioSesion {
  const ResultadoInicioSesion();
}

/// Login succeeded; a session token was stored.
final class InicioSesionExitoso extends ResultadoInicioSesion {
  const InicioSesionExitoso();
}

/// The credentials are invalid (wrong email or password).
final class InicioSesionCredencialesInvalidas extends ResultadoInicioSesion {
  const InicioSesionCredencialesInvalidas();
}

/// An unexpected error occurred during login.
final class InicioSesionError extends ResultadoInicioSesion {
  const InicioSesionError(this.mensaje);

  final String mensaje;
}
