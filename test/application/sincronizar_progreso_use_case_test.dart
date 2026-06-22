import 'package:arrowmaze/application/ports/i_repositorio_progreso.dart';
import 'package:arrowmaze/domain/progreso/i_cola_sincronizacion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrowmaze/application/use_cases/sincronizar_progreso_use_case.dart';

/// Ticket 10 — RED phase: SincronizarProgresoUseCase (AC1, AC2, AC4).
///
/// All ports are faked so tests never touch HTTP, SQLite, or Flutter.
void main() {
  group('SincronizarProgresoUseCase', () {
    test(
      'should_queue_run_offline_when_no_network',
      () async {
        // Arrange — a fake queue that records enqueues.
        final cola = _ColaSincronizacionFake();
        final repo = _RepositorioProgresoFake(exito: false);
        final useCase = SincronizarProgresoUseCase(
          cola: cola,
          repositorio: repo,
        );

        final run = _runEjemplo();

        // Act — queue the run (simulates no network).
        await useCase.encolar(run);

        // Assert — the run is persisted in the local queue.
        final pendientes = await cola.obtenerPendientes();
        expect(pendientes, hasLength(1));
        expect(pendientes.first.nivelId, run.nivelId);
        expect(pendientes.first.movimientos, run.movimientos);
      },
    );

    test(
      'should_upload_all_queued_runs_as_single_batch_when_sync',
      () async {
        // Arrange — 3 runs queued offline, repo records what it receives.
        final cola = _ColaSincronizacionFake();
        final repo = _RepositorioProgresoFake(exito: true);
        final useCase = SincronizarProgresoUseCase(
          cola: cola,
          repositorio: repo,
        );

        final run1 = _runEjemplo(nivelId: 'uuid-1');
        final run2 = _runEjemplo(nivelId: 'uuid-2');
        final run3 = _runEjemplo(nivelId: 'uuid-3');
        await cola.encolar(run1);
        await cola.encolar(run2);
        await cola.encolar(run3);

        // Act — sync triggers a single batch upload.
        final resultado = await useCase.sincronizar();

        // Assert — one batch call with all 3 runs; queue is now empty.
        expect(resultado.exitoso, isTrue);
        expect(repo.llamadasGuardarLote, 1);
        expect(repo.ultimaLote!.length, 3);
        expect(repo.ultimaLote!.map((r) => r.nivelId),
            ['uuid-1', 'uuid-2', 'uuid-3']);
        expect(await cola.cantidadPendientes(), 0);
      },
    );

    test(
      'should_keep_queue_intact_when_sync_fails',
      () async {
        // Arrange — 2 runs queued, but the remote call will fail.
        final cola = _ColaSincronizacionFake();
        final repo = _RepositorioProgresoFake(exito: false);
        final useCase = SincronizarProgresoUseCase(
          cola: cola,
          repositorio: repo,
        );

        await cola.encolar(_runEjemplo(nivelId: 'uuid-1'));
        await cola.encolar(_runEjemplo(nivelId: 'uuid-2'));

        // Act
        final resultado = await useCase.sincronizar();

        // Assert — the sync failed, but the queue is untouched.
        expect(resultado.exitoso, isFalse);
        expect(await cola.cantidadPendientes(), 2);
        expect(repo.llamadasGuardarLote, 1);
      },
    );

    test(
      'should_not_call_repo_when_queue_is_empty',
      () async {
        // Arrange — empty queue.
        final cola = _ColaSincronizacionFake();
        final repo = _RepositorioProgresoFake(exito: true);
        final useCase = SincronizarProgresoUseCase(
          cola: cola,
          repositorio: repo,
        );

        // Act
        final resultado = await useCase.sincronizar();

        // Assert — no HTTP call was made; result is a no-op success.
        expect(resultado.exitoso, isTrue);
        expect(repo.llamadasGuardarLote, 0);
      },
    );
  });
}

RunCompletado _runEjemplo({String nivelId = 'uuid-1'}) {
  return RunCompletado(
    nivelId: nivelId,
    movimientos: 10,
    segundosRestantes: 60,
    completadoEn: DateTime.utc(2026, 1, 1),
  );
}

/// Fake in-memory queue for testing.
class _ColaSincronizacionFake implements IColaSincronizacion {
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

/// Fake repo that optionally succeeds or fails, and records calls.
class _RepositorioProgresoFake implements IRepositorioProgreso {
  _RepositorioProgresoFake({required this.exito});

  final bool exito;
  int llamadasGuardarLote = 0;
  List<RunCompletado>? ultimaLote;

  @override
  Future<bool> guardarLote(List<RunCompletado> runs) async {
    llamadasGuardarLote++;
    ultimaLote = List.of(runs);
    return exito;
  }
}
