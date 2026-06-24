/// A level created on the backend, as returned by `POST /levels`.
///
/// Pure domain value object — carries the server-assigned id.
class NivelCreado {
  /// Creates a created-level value object.
  const NivelCreado({required this.id, required this.nombre});

  /// The server-assigned level UUID.
  final String id;

  /// The level name echoed back by the server.
  final String nombre;
}
