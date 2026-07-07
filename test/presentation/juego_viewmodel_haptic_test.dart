import 'package:arrowmaze/application/ports/haptic_feedback_port.dart';
import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [Reloj] that never ticks — the level under test is untimed.
class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// A [Reloj] whose one-second tick is fired manually from the test.
class _RelojControlable implements Reloj {
  void Function()? _callback;
  @override
  void iniciar(Duration intervalo, void Function() tic) => _callback = tic;
  @override
  void detener() {}
  void tic() => _callback?.call();
}

/// Records every buzz so a test can assert the port was (or was not) invoked.
class _HapticaFake implements HapticFeedbackPort {
  int vibraciones = 0;
  @override
  void vibrar() => vibraciones++;
}

/// Ticket 28 (A2, DM-F8) — an invalid tap fires **one** debounced red-alert
/// pulse and **one** haptic buzz per interaction; rapid invalid taps within the
/// debounce window coalesce, and a valid move stays completely quiet.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    limiteTiempo: null,
  );

  // 3x3: a blocked arrow at (1,0) aiming right into a wall at (1,2), plus a free
  // arrow at (2,1) aiming up with a clear ray to the top edge.
  GrafoTablero construirTablero() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.derecha,
            segmentos: const [Posicion.en(fila: 1, columna: 0)],
          ),
          Trayectoria(
            id: 2,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );

  const bloqueada = Posicion.en(fila: 1, columna: 0);
  const libre = Posicion.en(fila: 2, columna: 1);

  test('should_emit_single_invalid_alert_pulse_when_tapped_rapidly', () {
    // Arrange — a frozen clock so every tap lands inside the debounce window.
    final tablero = construirTablero();
    final haptica = _HapticaFake();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
      haptica: haptica,
      ahora: () => DateTime(2026, 7, 6, 12),
    );
    var pulsos = 0;
    viewModel.addListener(() {
      if (viewModel.estado.alertaInvalida) pulsos++;
    });

    // Act — hammer the blocked arrow five times in a row.
    for (var i = 0; i < 5; i++) {
      viewModel.tocar(bloqueada);
    }

    // Assert — exactly one alert pulse and one buzz; every tap still counted.
    expect(pulsos, 1);
    expect(haptica.vibraciones, 1);
    expect(viewModel.estado.movimientos, 5);
    expect(viewModel.estado.alertaInvalida, isFalse);
  });

  test('should_request_haptic_feedback_when_move_invalid', () {
    // Arrange
    final tablero = construirTablero();
    final haptica = _HapticaFake();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
      haptica: haptica,
    );

    // Act
    viewModel.tocar(bloqueada);

    // Assert
    expect(haptica.vibraciones, 1);
    expect(viewModel.estado.alertaInvalida, isTrue);
  });

  test('should_not_repeat_invalid_alert_on_later_state_updates', () {
    // Arrange — a timed level, so the countdown publishes new states after the
    // mistake (this is when the alert used to "keep beating" each second).
    final tablero = construirTablero();
    final haptica = _HapticaFake();
    final reloj = _RelojControlable();
    final sesion =
        SesionJuego(tablero: tablero, limiteTiempo: const Duration(seconds: 90));
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero, sesion: sesion),
      definicionNivel: definicion,
      reloj: reloj,
      haptica: haptica,
    );

    // Act — one invalid tap raises the one-shot alert, then the clock ticks.
    viewModel.tocar(bloqueada);
    expect(viewModel.estado.alertaInvalida, isTrue);
    reloj.tic();

    // Assert — the alert is a one-shot: it does NOT ride along on the tick's
    // state, so the View flashes exactly once and never re-fires each second.
    expect(viewModel.estado.alertaInvalida, isFalse);
    expect(haptica.vibraciones, 1);
  });

  test('should_not_alert_or_buzz_when_move_valid', () {
    // Arrange
    final tablero = construirTablero();
    final haptica = _HapticaFake();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
      haptica: haptica,
    );

    // Act — a clear move exits the board.
    viewModel.tocar(libre);

    // Assert — no red alert, no buzz.
    expect(viewModel.estado.alertaInvalida, isFalse);
    expect(haptica.vibraciones, 0);
  });
}
