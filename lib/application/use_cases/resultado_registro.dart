/// The result of [RegistrarUsuarioUseCase.ejecutar].
sealed class ResultadoRegistro {
  const ResultadoRegistro();
}

/// Registration succeeded; a session token was stored.
final class RegistroExitoso extends ResultadoRegistro {
  const RegistroExitoso();
}

/// The email is already taken.
final class RegistroEmailDuplicado extends ResultadoRegistro {
  const RegistroEmailDuplicado();
}

/// An unexpected error occurred during registration.
final class RegistroError extends ResultadoRegistro {
  const RegistroError(this.mensaje);

  final String mensaje;
}
