import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/observador_juego.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// A clock whose one-second tick is driven **manually** from the test, so the
/// countdown can be advanced deterministically one second at a time. It captures
/// the callback the ViewModel arms so [tic] fires exactly one `_tic`.
class _RelojControlable implements Reloj {
  void Function()? _callback;
  bool iniciado = false;

  @override
  void iniciar(Duration intervalo, void Function() tic) {
    iniciado = true;
    _callback = tic;
  }

  @override
  void detener() {}

  /// Fires one countdown tick (advancing the session clock by a second).
  void tic() => _callback?.call();
}

/// A game-event observer that counts how many time-warning events it received,
/// standing in for the audio service subscribed to the same publisher.
class _ObservadorAviso implements ObservadorJuego {
  int avisos = 0;

  @override
  void alOcurrirEvento(EventoJuego evento) {
    if (evento.tipo == TipoEvento.avisoTiempo) avisos++;
  }
}

/// Verifies the MVVM binding: a tap on the VM runs the use case and publishes a
/// *new immutable* [JuegoViewState] (via `copyWith`) with the whole path now
/// empty, notifying listeners exactly once. Also checks the snapshot carries the
/// path geometry (corner connections, head) the painter needs.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,

    limiteTiempo: null,
  );

  GrafoTablero construirTablero() {
    // 3x3 with an L-shaped path: (2,1)->(1,1)->(1,0), head (1,0) exits left.
    return GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.izquierda,
          segmentos: const [
            Posicion.en(fila: 2, columna: 1),
            Posicion.en(fila: 1, columna: 1),
            Posicion.en(fila: 1, columna: 0),
          ],
        ),
      ],
    );
  }

  test('should_expose_path_geometry_when_building_initial_snapshot', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Assert — the bend at (1,1) is a corner; (1,0) is the head exiting left.
    final esquina =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 1));
    expect(esquina.tipo, TipoCeldaUI.flecha);
    expect(esquina.conexiones, {Direccion.abajo, Direccion.izquierda});

    final cabeza =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 0));
    expect(cabeza.esCabeza, isTrue);
    expect(cabeza.direccion, Direccion.izquierda);
  });

  test('should_expose_new_JuegoViewState_with_emptied_path_when_move_valid', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
    final JuegoViewState estadoInicial = viewModel.estado;
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    // Tap any segment of the path — the whole arrow should resolve.
    const tap = Posicion.en(fila: 2, columna: 1);
    expect(estadoInicial.tablero.celdaEn(tap).tipo, TipoCeldaUI.flecha);

    // Act
    viewModel.tocar(tap);

    // Assert — a brand new immutable state instance was published.
    expect(identical(viewModel.estado, estadoInicial), isFalse);
    final tablero2 = viewModel.estado.tablero;
    for (final p in const [
      Posicion.en(fila: 2, columna: 1),
      Posicion.en(fila: 1, columna: 1),
      Posicion.en(fila: 1, columna: 0),
    ]) {
      expect(tablero2.celdaEn(p).tipo, TipoCeldaUI.vacia);
    }
    expect(viewModel.estado.movimientos, 1);
    expect(notificaciones, 1);
  });

  test(
    'should_emit_exit_animation_descriptor_with_ordered_path_when_move_valid',
    () {
      // Arrange
      final tablero = construirTablero();
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
      );

      // Act — resolve the L-shaped path (head (1,0) exits left).
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

      // Assert — the transient descriptor carries the exiting cells in order
      // (tail → head), the exit direction and an off-board edge target so the
      // View can play the snake gait (AC1).
      final salida = viewModel.estado.animacionSalida;
      expect(salida, isNotNull);
      expect(salida!.idFlecha, 1);
      expect(salida.segmentos, const [
        Posicion.en(fila: 2, columna: 1),
        Posicion.en(fila: 1, columna: 1),
        Posicion.en(fila: 1, columna: 0),
      ]);
      expect(salida.direccionSalida, Direccion.izquierda);
      // Head at (1,0) exiting left ⇒ the edge target is off-board at column -1.
      expect(salida.objetivoBorde, const Posicion.en(fila: 1, columna: -1));

      // And it is transient: a later state (any other notification) clears it so
      // a finished animation never leaks into later frames (AC3, refactor note).
      viewModel.toggleMute();
      expect(viewModel.estado.animacionSalida, isNull);
    },
  );

  test('should_not_emit_exit_descriptor_when_move_invalid', () {
    // Arrange — a path whose head is boxed in by a wall so its ray is blocked.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 2)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.abajo,
          segmentos: const [Posicion.en(fila: 1, columna: 2)],
        ),
      ],
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Act — tap the arrow at (2,2): its upward ray is blocked by the arrow at
    // (1,2), so the move is penalized/invalid.
    viewModel.tocar(const Posicion.en(fila: 2, columna: 2));

    // Assert — an invalid move never emits an exit descriptor (AC3).
    expect(viewModel.estado.movimientoInvalido, isTrue);
    expect(viewModel.estado.animacionSalida, isNull);
  });

  group('15-second time warning (ticket 29)', () {
    // A timed level (numero >= 10, non-bonus, with a limit) — the only kind on
    // which the warning may fire (AC3).
    const definicionCronometrada = DefinicionNivel(
      id: 10,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 17),
    );

    /// Builds a timed ViewModel wired to a manual clock and a warning observer,
    /// with the session opened at [limite] so the test can tick down to 15s.
    ({
      JuegoViewModel vm,
      _RelojControlable reloj,
      _ObservadorAviso observador,
    }) construirCronometrado({
      Duration limite = const Duration(seconds: 17),
    }) {
      final tablero = construirTablero();
      final sesion = SesionJuego(tablero: tablero, limiteTiempo: limite);
      final mover = MoverFlechaUseCase(tablero, sesion: sesion);
      final observador = _ObservadorAviso();
      mover.publicador.suscribir(observador);
      final reloj = _RelojControlable();
      final vm = JuegoViewModel(
        tablero: tablero,
        moverFlecha: mover,
        definicionNivel: definicionCronometrada,
        reloj: reloj,
      );
      return (vm: vm, reloj: reloj, observador: observador);
    }

    test('should_fire_time_warning_once_when_remaining_reaches_15', () {
      // Arrange — a timed run starting at 17s.
      final ctx = construirCronometrado();

      // Act — 17→16: above threshold, no warning yet.
      ctx.reloj.tic();
      expect(ctx.observador.avisos, 0);
      expect(ctx.vm.estado.avisoTiempo, isFalse);

      // 16→15: crosses the threshold — the warning fires exactly once.
      ctx.reloj.tic();
      expect(ctx.observador.avisos, 1);
      expect(ctx.vm.estado.avisoTiempo, isTrue);

      // 15→14→13: the HUD stays in warning but no new event is emitted (AC1).
      ctx.reloj.tic();
      ctx.reloj.tic();
      expect(ctx.observador.avisos, 1);
      expect(ctx.vm.estado.avisoTiempo, isTrue);
    });

    test('should_not_warn_when_level_untimed_or_bonus', () {
      // Two non-timed shapes that must never warn (AC3): an untimed level (no
      // limit) and a bonus level (a limit is present but bonus levels aren't
      // timed). Both must leave the clock un-armed so no tick can ever occur.
      const sinTiempo = DefinicionNivel(
        id: 1,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        limiteTiempo: null,
      );
      const bonus = DefinicionNivel(
        id: 12,
        numero: 12,
        baseNivel: 1000,
        kmov: 10,
        ktiempo: 2,
        limiteTiempo: Duration(seconds: 17),
        esBonus: true,
      );

      for (final definicion in const [sinTiempo, bonus]) {
        final tablero = construirTablero();
        final mover = MoverFlechaUseCase(tablero);
        final observador = _ObservadorAviso();
        mover.publicador.suscribir(observador);
        final reloj = _RelojControlable();

        final vm = JuegoViewModel(
          tablero: tablero,
          moverFlecha: mover,
          definicionNivel: definicion,
          reloj: reloj,
        );

        // Assert — the clock is never armed and the warning never fires.
        expect(reloj.iniciado, isFalse, reason: 'nivel ${definicion.id}');
        expect(observador.avisos, 0, reason: 'nivel ${definicion.id}');
        expect(vm.estado.avisoTiempo, isFalse, reason: 'nivel ${definicion.id}');
      }
    });

    test('should_reset_warning_when_retrying', () {
      // Arrange — first run: drive it across 15s so the warning fires once.
      final primera = construirCronometrado();
      primera.reloj.tic(); // 17→16
      primera.reloj.tic(); // 16→15 (warns)
      expect(primera.observador.avisos, 1);

      // Act — a retry is a *fresh run* (a new session + ViewModel). The one-shot
      // guard must be per-run, not a leaked latch, so the new run warns again.
      final segunda = construirCronometrado();
      segunda.reloj.tic(); // 17→16
      segunda.reloj.tic(); // 16→15 (warns again)

      // Assert — the second run fires its own warning independently.
      expect(segunda.observador.avisos, 1);
      expect(segunda.vm.estado.avisoTiempo, isTrue);
    });

    test('should_not_refire_warning_when_paused_and_resumed', () {
      // Arrange — cross the threshold so the warning has already fired once.
      final ctx = construirCronometrado();
      ctx.reloj.tic(); // 17→16
      ctx.reloj.tic(); // 16→15 (warns)
      expect(ctx.observador.avisos, 1);

      // Act — pause then resume while already inside the final 15 seconds.
      ctx.vm.pausar();
      ctx.vm.reanudar();
      ctx.reloj.tic(); // 15→14

      // Assert — resuming re-arms the clock but never re-fires the warning (AC5),
      // and the HUD stays in its warning state throughout.
      expect(ctx.observador.avisos, 1);
      expect(ctx.vm.estado.avisoTiempo, isTrue);
    });
  });

  test('should_mark_absent_positions_as_non_playable_when_building_view_state', () {
    // Arrange — a shaped 2×2 board with one absent corner (outside the shape).
    final tablero = GrafoTablero.desde(
      filas: 2,
      columnas: 2,
      ausentes: {const Posicion.en(fila: 0, columna: 1)},
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Assert — the masked board flags the absent corner as non-playable, while
    // an in-shape cell stays playable (AC1). No UI-side re-derivation: the flag
    // comes straight from the model's `CeldaAusente`.
    final ausente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 1));
    expect(ausente.tipo, TipoCeldaUI.ausente);
    expect(ausente.esJugable, isFalse);

    final presente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 0));
    expect(presente.esJugable, isTrue);
  });

  test('should_distinguish_absent_from_empty_cell_when_building_view_state', () {
    // Arrange — (0,1) is absent; every other cell is present empty space.
    final tablero = GrafoTablero.desde(
      filas: 2,
      columnas: 2,
      ausentes: {const Posicion.en(fila: 0, columna: 1)},
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    final ausente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 1));
    final vacia = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 0));

    // Assert — absent ≠ empty: distinct kinds and distinct playability, so the
    // painter draws a dot for the empty cell but nothing for the absent one, and
    // only the empty cell is a hit-test target (AC2).
    expect(ausente.tipo, TipoCeldaUI.ausente);
    expect(vacia.tipo, TipoCeldaUI.vacia);
    expect(ausente.esJugable, isFalse);
    expect(vacia.esJugable, isTrue);
  });
}
