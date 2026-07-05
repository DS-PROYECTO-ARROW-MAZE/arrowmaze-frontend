import 'package:arrowmaze/application/ports/i_registro.dart';
import 'package:arrowmaze/application/ports/i_repositorio_progreso.dart';
import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/application/use_cases/sincronizar_progreso_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/progreso/i_cola_sincronizacion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 15 — RED phase: on victory, JuegoViewModel enqueues a RunCompletado
/// and triggers a flush via SincronizarProgresoUseCase.
///
/// This test should FAIL today because no flush is wired.
void main() {
  const definicion = DefinicionNivel(
    id: 1,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,

    limiteTiempo: Duration(seconds: 90),
  );

  GrafoTablero tableroDeUnaFlecha() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
      );

  test(
    'should_enqueue_run_and_trigger_flush_when_victory',
    () async {
      // Arrange — fake queue + fake repo wired into a real use case.
      final cola = _ColaSincronizacionFake();
      final repo = _RepositorioProgresoFake(exito: true);
      final sincronizar = SincronizarProgresoUseCase(
        cola: cola,
        repositorio: repo,
      );
      final tablero = tableroDeUnaFlecha();
      final moverFlecha = MoverFlechaUseCase(tablero);
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: moverFlecha,
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        idNivel: 1,
        nivelIdRemoto: 'uuid-nivel-1',
        sincronizar: sincronizar,
      );

      // Act — clear the only arrow to trigger victory.
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

      // Assert — the move was registered and victory state exposed.
      expect(viewModel.estado.movimientos, 1);
      expect(viewModel.estado.victoria, isNotNull,
          reason: 'Victory should be reached after clearing the only arrow');
      expect(viewModel.estado.victoria!.movimientos, 1);

      // Wait for the fire-and-forget async chain (enqueue → flush) to complete.
      for (var i = 0; i < 10; i++) {
        await Future(() {});
      }

      // Assert — the flush was triggered: repo received the batch with the run
      // and the queue was cleared (flush vacuums on success).
      expect(repo.llamadasGuardarLote, greaterThan(0));
      final lote = repo.ultimaLote;
      expect(lote, isNotNull);
      expect(lote!.length, 1);
      // The run is keyed by the backend UUID, not the local ordinal.
      expect(lote.first.nivelId, 'uuid-nivel-1');
      // Session is untimed (default from MoverFlechaUseCase), so segundosRestantes
      // is null.
      expect(lote.first.segundosRestantes, isNull);

      // Queue should be empty after a successful flush.
      final pendientes = await cola.obtenerPendientes();
      expect(pendientes, isEmpty);
    },
  );

  test(
    'should_not_call_sincronizar_when_no_sync_injected',
    () async {
      // Arrange — no sync use case injected.
      final tablero = tableroDeUnaFlecha();
      final moverFlecha = MoverFlechaUseCase(tablero);
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: moverFlecha,
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        idNivel: 1,
      );

      // Act — victory should not throw without sync wired.
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

      // Assert — no crash, victory state still exposed.
      expect(viewModel.estado.victoria, isNotNull);
    },
  );

  test(
    'should_expose_successful_sync_future_for_leaderboard_to_await',
    () async {
      // Arrange — sync wired with a backend UUID and a repo that succeeds.
      final sincronizar = SincronizarProgresoUseCase(
        cola: _ColaSincronizacionFake(),
        repositorio: _RepositorioProgresoFake(exito: true),
      );
      final tablero = tableroDeUnaFlecha();
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        idNivel: 1,
        nivelIdRemoto: 'uuid-nivel-1',
        sincronizar: sincronizar,
      );

      // Act — win, then await the exposed sync future (what the leaderboard does).
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));
      final resultado = await viewModel.sincronizacionEnCurso;

      // Assert — the future is exposed and reports success.
      expect(resultado, isTrue);
    },
  );

  test(
    'should_report_failure_and_log_when_sync_rejected',
    () async {
      // Arrange — repo rejects the batch (e.g. 401/400 surfaces as a failed
      // upload), and a logger is injected to capture the failure.
      final registro = _RegistroFake();
      final sincronizar = SincronizarProgresoUseCase(
        cola: _ColaSincronizacionFake(),
        repositorio: _RepositorioProgresoFake(exito: false),
      );
      final tablero = tableroDeUnaFlecha();
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        idNivel: 1,
        nivelIdRemoto: 'uuid-nivel-1',
        sincronizar: sincronizar,
        registro: registro,
      );

      // Act
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));
      final resultado = await viewModel.sincronizacionEnCurso;

      // Assert — failure is surfaced to the awaiter and logged, not swallowed.
      expect(resultado, isFalse);
      expect(registro.errores, isNotEmpty);
    },
  );

  test(
    'should_skip_sync_when_no_remote_uuid_known',
    () async {
      // Arrange — sync is wired, but the level has no backend UUID (offline /
      // bundled catalog), so there is no server level to attribute the run to.
      final cola = _ColaSincronizacionFake();
      final repo = _RepositorioProgresoFake(exito: true);
      final sincronizar = SincronizarProgresoUseCase(
        cola: cola,
        repositorio: repo,
      );
      final tablero = tableroDeUnaFlecha();
      final moverFlecha = MoverFlechaUseCase(tablero);
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: moverFlecha,
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        idNivel: 1,
        // nivelIdRemoto intentionally omitted (null).
        sincronizar: sincronizar,
      );

      // Act — reach victory.
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));
      for (var i = 0; i < 10; i++) {
        await Future(() {});
      }

      // Assert — victory still happens, but nothing is enqueued or uploaded.
      expect(viewModel.estado.victoria, isNotNull);
      expect(repo.llamadasGuardarLote, 0);
      expect(await cola.cantidadPendientes(), 0);
    },
  );
}

class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

class _RegistroFake implements IRegistro {
  final List<String> infos = [];
  final List<String> errores = [];

  @override
  void info(String mensaje) => infos.add(mensaje);

  @override
  void error(String mensaje) => errores.add(mensaje);
}

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
