/// Thrown by [DecoradorSeguridadCasoDeUso] when a guarded use case is invoked
/// without an active session token.
///
/// Pure Dart — carries no framework dependency, so it is safe to surface from
/// the application layer and translate in presentation.
class SesionRequeridaException implements Exception {
  /// Creates the exception with an optional human-readable [mensaje].
  const SesionRequeridaException([
    this.mensaje = 'Se requiere una sesión activa para ejecutar esta acción.',
  ]);

  /// A user-facing explanation of why execution was blocked.
  final String mensaje;

  @override
  String toString() => 'SesionRequeridaException: $mensaje';
}
