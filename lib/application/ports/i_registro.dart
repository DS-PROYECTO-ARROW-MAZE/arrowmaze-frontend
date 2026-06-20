/// Port for structured logging (DIP).
///
/// The application layer logs through this abstraction; the concrete sink
/// (console, file, remote) lives in infrastructure (e.g. `RegistroConsola`).
/// No logging library ever reaches the application or domain layers (AC2).
abstract interface class IRegistro {
  /// Records an informational [mensaje] (normal flow).
  void info(String mensaje);

  /// Records an error [mensaje] (a use case threw).
  void error(String mensaje);
}
