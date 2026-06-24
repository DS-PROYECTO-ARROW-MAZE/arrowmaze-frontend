import '../../domain/niveles/definicion_nivel_remota.dart';
import '../../domain/niveles/nivel_creado.dart';

/// Port for the remote level-authoring API (`POST /levels`).
///
/// The concrete implementation (HTTP) lives in infrastructure. Use cases depend
/// on this port so they never reference HTTP or platform details.
abstract interface class FuenteNiveles {
  /// Creates [definicion] on the backend and returns the created level.
  ///
  /// This is a protected route; the session token is attached by the HTTP
  /// interceptor.
  Future<NivelCreado> crear(DefinicionNivelRemota definicion);
}
