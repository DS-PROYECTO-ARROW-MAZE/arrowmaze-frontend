import '../../domain/progreso/i_cola_sincronizacion.dart';
import '../../domain/progreso/run_completado.dart';

/// In-memory implementation of [IColaSincronizacion].
///
/// Stores completed runs in a list. Production versions will back this
/// with SQLite or shared_preferences without changing the use cases
/// or views — DIP is satisfied.
class ColaSincronizacionLocal implements IColaSincronizacion {
  final List<RunCompletado> _cola = [];

  @override
  Future<void> encolar(RunCompletado run) async {
    _cola.add(run);
  }

  @override
  Future<List<RunCompletado>> obtenerPendientes() async =>
      List.unmodifiable(_cola);

  @override
  Future<void> vaciar() async {
    _cola.clear();
  }

  @override
  Future<int> cantidadPendientes() async => _cola.length;
}
