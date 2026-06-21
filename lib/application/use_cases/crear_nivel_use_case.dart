import '../../domain/niveles/definicion_nivel_remota.dart';
import '../../domain/niveles/nivel_creado.dart';
import '../ports/fuente_niveles.dart';

/// Use case: create a level on the backend (`POST /levels`).
///
/// Delegates to [FuenteNiveles.crear]. The Bearer token is attached by the
/// HTTP interceptor, so this use case stays free of any auth concern.
class CrearNivelUseCase {
  /// Creates the use case with an injected levels port.
  const CrearNivelUseCase({required this.fuenteNiveles});

  /// The remote levels port.
  final FuenteNiveles fuenteNiveles;

  /// Creates the given level definition and returns the created level.
  Future<NivelCreado> ejecutar(DefinicionNivelRemota definicion) =>
      fuenteNiveles.crear(definicion);
}
