import 'dart:math';

import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/sesion/estado_sesion.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/presupuesto_movimientos.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 04 (DM-F5) — the GoF **State** machine of a play session.
///
/// These tests drive a real [GrafoTablero] through a [SesionJuego] and assert the
/// session transitions between `EstadoJugando/Pausado/Victoria/Derrota` purely by
/// the rules of PRD §3 B1–B3. The four `EstadoSesion` subclasses encode tap and
/// timer legality **by type**, not by scattered `if`s.
void main() {
  /// A 3×3 board whose only arrow sits at (2,1) and exits cleanly upward — one
  /// valid tap empties the whole board.
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

  /// A 3×3 board with two independent arrows, so a single tap never empties it
  /// (used to exercise long move/time sequences without a quick victory).
  GrafoTablero tableroDeDosFlechas() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 0)],
          ),
          Trayectoria(
            id: 2,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 2)],
          ),
        ],
      );

  test('should_transition_to_EstadoVictoria_when_last_arrow_exits', () {
    // Arrange — an untimed session sitting on a one-arrow board.
    final sesion = SesionJuego(tablero: tableroDeUnaFlecha());
    expect(sesion.estado, isA<EstadoJugando>());

    // Act — tap the only arrow; its clear ray empties the board.
    sesion.tocarCelda(const Posicion.en(fila: 2, columna: 1));

    // Assert — the board is empty, so the session is now a victory.
    expect(sesion.estado, isA<EstadoVictoria>());
    expect(sesion.estaTerminada, isTrue);
  });

  test('should_transition_to_EstadoDerrota_when_timer_reaches_zero_on_timed_level',
      () {
    // Arrange — a timed session with ten seconds on the clock.
    final sesion = SesionJuego(
      tablero: tableroDeDosFlechas(),
      limiteTiempo: const Duration(seconds: 10),
    );

    // Act — let the whole limit elapse before any arrow clears.
    sesion.avanzarTiempo(const Duration(seconds: 10));

    // Assert — running out of time is a defeat.
    expect(sesion.estado, isA<EstadoDerrota>());
    expect(sesion.estaTerminada, isTrue);
  });

  test('should_never_reach_EstadoDerrota_via_time_when_level_is_untimed', () {
    // Arrange — an untimed session with a deterministic time sequence.
    final sesion = SesionJuego(tablero: tableroDeDosFlechas());
    final aleatorio = Random(7);

    // Act + Assert — arbitrary elapsed time never triggers defeat on an
    // untimed level (PRD §3 B2). Defeat via move exhaustion is tested
    // separately (Ticket 30 — AC3).
    for (var i = 0; i < 500; i++) {
      sesion.avanzarTiempo(Duration(seconds: aleatorio.nextInt(10_000)));
      expect(sesion.estado, isNot(isA<EstadoDerrota>()));
    }
  });

  test(
      'should_transition_to_EstadoDerrota_on_untimed_level_when_budget_exhausted',
      () {
    // Arrange — an untimed session with a finite move budget on a two-arrow
    // board, and only one registered tap possible (the other positions are
    // not on arrows and are ignored).
    const presupuesto = PresupuestoMovimientos(1);
    final sesion = SesionJuego(
      tablero: tableroDeDosFlechas(),
      presupuestoMovimientos: presupuesto,
    );

    // Act — one valid tap clears one arrow; the budget is now 0 but the
    // board still has one arrow left.
    sesion.tocarCelda(const Posicion.en(fila: 2, columna: 0));
    sesion.registrarMovimiento();

    // Assert — budget exhausted with non-empty board → defeat (AC3).
    expect(sesion.estado, isA<EstadoDerrota>());
    expect(sesion.estaTerminada, isTrue);
  });

  test('should_win_when_board_cleared_on_last_allowed_move', () {
    // Arrange — one-arrow board with budget of exactly 1.
    const presupuesto = PresupuestoMovimientos(1);
    final sesion = SesionJuego(
      tablero: tableroDeUnaFlecha(),
      presupuestoMovimientos: presupuesto,
    );

    // Act — the only arrow exits, emptying the board (victory). Then the
    // budget would be exhausted, but victory already happened.
    sesion.tocarCelda(const Posicion.en(fila: 2, columna: 1));
    sesion.registrarMovimiento();

    // Assert — victory, not defeat (victory wins ties, AC2).
    expect(sesion.estado, isA<EstadoVictoria>());
    expect(sesion.estaTerminada, isTrue);
  });

  test('should_reject_tap_when_EstadoPausado', () {
    // Arrange — pause a session whose arrow is still on the board.
    final tablero = tableroDeUnaFlecha();
    final sesion = SesionJuego(tablero: tablero);
    sesion.pausar();
    expect(sesion.estado, isA<EstadoPausado>());

    // Act — tap the arrow while paused.
    const tap = Posicion.en(fila: 2, columna: 1);
    sesion.tocarCelda(tap);

    // Assert — the tap is rejected: the arrow is untouched and we stay paused.
    expect(tablero.trayectoriaEn(tap), isNotNull);
    expect(sesion.estado, isA<EstadoPausado>());
  });

  test('should_freeze_timer_and_resume_to_EstadoJugando_when_paused_then_resumed', () {
    // Arrange — a timed session with time on the clock, then paused.
    final sesion = SesionJuego(
      tablero: tableroDeDosFlechas(),
      limiteTiempo: const Duration(seconds: 10),
    );
    sesion.pausar();
    final restanteAlPausar = sesion.tiempoRestante;

    // Act — time "passes" while paused; the frozen clock must ignore it.
    sesion.avanzarTiempo(const Duration(seconds: 30));

    // Assert — the clock did not advance and the level was not lost.
    expect(sesion.tiempoRestante, restanteAlPausar);
    expect(sesion.estado, isA<EstadoPausado>());
    expect(sesion.estaTerminada, isFalse);

    // Act — resuming returns to play and re-arms the clock.
    sesion.reanudar();
    sesion.avanzarTiempo(const Duration(seconds: 4));

    // Assert — back in play and now the clock advances again.
    expect(sesion.estado, isA<EstadoJugando>());
    expect(sesion.tiempoRestante, const Duration(seconds: 6));
  });
}
