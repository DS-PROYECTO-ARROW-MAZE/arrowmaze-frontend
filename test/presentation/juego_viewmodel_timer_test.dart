import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelojGrabbed implements Reloj {
  bool iniciado = false;
  bool detenido = false;
  Duration? intervalo;
  void Function()? ticGrabado;

  @override
  void iniciar(Duration intervalo, void Function() tic) {
    iniciado = true;
    detenido = false;
    this.intervalo = intervalo;
    ticGrabado = tic;
  }

  @override
  void detener() {
    detenido = true;
    iniciado = false;
  }
}

/// Ticket 18 — ViewModel timer rules (AC1, AC2, AC3):
///
/// - Levels `numero 1–9` (non-bonus) → no timer started, HUD shows no countdown.
/// - Levels `numero ≥10` (non-bonus) → countdown from `limiteTiempo`, HUD shows clock.
/// - Bonus levels → no timer, no score on victory.
/// - Timeout → defeat transition.
void main() {
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

  test(
      'should_not_start_timer_when_level_numero_below_10', () {
    final reloj = _RelojGrabbed();
    final tablero = tableroDeUnaFlecha();
    const definicion = DefinicionNivel(
      id: 5,
      numero: 5,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 90),
      esBonus: false,
    );

    JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: reloj,
    );

    expect(reloj.iniciado, isFalse);
  });

  test(
      'should_start_countdown_when_level_numero_10_or_above', () {
    final reloj = _RelojGrabbed();
    final tablero = tableroDeUnaFlecha();
    const definicion = DefinicionNivel(
      id: 10,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 90),
      esBonus: false,
    );

    JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero, sesion: SesionJuego(tablero: tablero, limiteTiempo: const Duration(seconds: 90))),
      definicionNivel: definicion,
      reloj: reloj,
    );

    expect(reloj.iniciado, isTrue);
    expect(reloj.intervalo, const Duration(seconds: 1));
  });

  test(
      'should_transition_to_defeat_when_time_runs_out', () {
    final reloj = _RelojGrabbed();
    final tablero = tableroDeDosFlechas();
    final sesion = SesionJuego(tablero: tablero, limiteTiempo: const Duration(seconds: 3));
    const definicion = DefinicionNivel(
      id: 10,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 3),
      esBonus: false,
    );

    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero, sesion: sesion),
      definicionNivel: definicion,
      reloj: reloj,
    );

    expect(viewModel.estado.derrota, isFalse);

    reloj.ticGrabado!();
    reloj.ticGrabado!();
    reloj.ticGrabado!();

    expect(viewModel.estado.derrota, isTrue);
    expect(reloj.detenido, isTrue);
  });

  test(
      'should_not_time_or_score_when_level_is_bonus', () {
    final reloj = _RelojGrabbed();
    final tablero = tableroDeUnaFlecha();
    const definicion = DefinicionNivel(
      id: 20,
      numero: 20,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 90),
      esBonus: true,
    );

    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: reloj,
    );

    expect(reloj.iniciado, isFalse);
    expect(viewModel.estado.tiempoRestante, isNull);

    viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

    final victoria = viewModel.estado.victoria;
    expect(victoria, isNotNull);
    expect(victoria!.puntaje, 0);
    expect(victoria.estrellas, 0);
    expect(victoria.mostrarPuntuacion, isFalse);
  });

  test(
      'should_show_timer_in_HUD_when_level_numero_10_or_above', () {
    final tablero = tableroDeUnaFlecha();
    final sesion = SesionJuego(tablero: tablero, limiteTiempo: const Duration(seconds: 90));
    const definicion = DefinicionNivel(
      id: 10,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 90),
      esBonus: false,
    );

    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero, sesion: sesion),
      definicionNivel: definicion,
      reloj: _RelojGrabbed(),
    );

    expect(viewModel.estado.tiempoRestante, isNotNull);
    expect(viewModel.estado.tiempoRestante, const Duration(seconds: 90));
  });
}
