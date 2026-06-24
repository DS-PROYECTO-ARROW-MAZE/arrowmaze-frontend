import 'package:flutter/foundation.dart';

import '../../application/use_cases/sincronizar_progreso_use_case.dart';
import '../../domain/progreso/run_completado.dart';
import 'sync_view_state.dart';

/// The View's only collaborator for offline progress sync (DM-B3, E2).
///
/// Manages the sync lifecycle: enqueue on victory, upload on user action.
/// Publishes [SyncViewState] snapshots — the View never calls the use case
/// directly (MVVM strict).
class SyncViewModel extends ChangeNotifier {
  /// Creates the sync ViewModel with injected use case.
  SyncViewModel({required SincronizarProgresoUseCase sincronizarProgreso})
      : _sincronizarProgreso = sincronizarProgreso {
    _actualizarPendientes();
  }

  final SincronizarProgresoUseCase _sincronizarProgreso;

  SyncViewState _estado = const SyncViewState();

  /// The current immutable state the View renders.
  SyncViewState get estado => _estado;

  /// Enqueues a completed run for later batch upload.
  Future<void> encolar(RunCompletado run) async {
    await _sincronizarProgreso.encolar(run);
    await _actualizarPendientes();
  }

  /// Triggers a batch sync of all queued runs.
  Future<void> sincronizar() async {
    _estado = _estado.copyWith(
      status: SyncStatus.sincronizando,
      mensajeError: null,
    );
    notifyListeners();

    final resultado = await _sincronizarProgreso.sincronizar();

    if (resultado.exitoso) {
      _estado = _estado.copyWith(status: SyncStatus.sincronizado);
    } else {
      _estado = _estado.copyWith(
        status: SyncStatus.error,
        mensajeError: resultado.mensajeError,
      );
    }

    await _actualizarPendientes();
  }

  Future<void> _actualizarPendientes() async {
    final count = await _sincronizarProgreso.pendientes();
    _estado = _estado.copyWith(pendientes: count);

    if (count == 0 && _estado.status != SyncStatus.sincronizando) {
      _estado = _estado.copyWith(status: SyncStatus.sincronizado);
    } else if (count > 0 &&
        _estado.status != SyncStatus.sincronizando &&
        _estado.status != SyncStatus.error) {
      _estado = _estado.copyWith(status: SyncStatus.enCola);
    }

    notifyListeners();
  }
}
