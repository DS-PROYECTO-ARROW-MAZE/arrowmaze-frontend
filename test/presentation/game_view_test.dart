import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/core/i18n/cadenas_en.dart';
import 'package:arrowmaze/core/i18n/cadenas_scope.dart';
import 'package:arrowmaze/core/theme/game_theme.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/domain/value_objects/presupuesto_movimientos.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/views/game/confetti_overlay.dart';
import 'package:arrowmaze/presentation/views/game/game_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A no-op clock: these tests are about the victory overlay, not the countdown.
class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// Ticket 34 — the victory confetti fires exactly when the Level Complete UI
/// (`_VictoriaOverlay`) renders, on both scored and bonus wins, and never on
/// defeat.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
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
    limiteTiempo: null,
    esBonus: true,
  );

  /// A 3×3 board with a single L-shaped path; tapping it clears the board and
  /// wins the level.
  GrafoTablero construirTablero() {
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

  /// A board with two independent single-cell paths at opposite corners, each
  /// pointing off-board so a tap resolves it.
  GrafoTablero construirTableroDosCaminos() {
    return GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.izquierda,
          segmentos: const [Posicion.en(fila: 0, columna: 0)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.derecha,
          segmentos: const [Posicion.en(fila: 2, columna: 2)],
        ),
      ],
    );
  }

  Widget montarJuego(JuegoViewModel vm) {
    return MaterialApp(
      theme: ThemeData(extensions: const [GameTheme.dark]),
      home: CadenasScope(
        cadenas: const CadenasEn(),
        child: GameView(viewModel: vm),
      ),
    );
  }

  testWidgets(
    'should_show_confetti_when_victoria_present_and_not_on_derrota',
    (tester) async {
      // Arrange — a fresh, in-play level.
      final tablero = construirTablero();
      final vm = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
      );
      await tester.pumpWidget(montarJuego(vm));

      // While playing (victoria == null) there is no confetti (AC2).
      expect(find.byType(ConfettiOverlay), findsNothing);

      // Act — clear the only path to win.
      vm.tocar(const Posicion.en(fila: 2, columna: 1));
      await tester.pump();

      // Assert — the victory overlay renders and its confetti bursts (AC1).
      expect(vm.estado.victoria, isNotNull);
      expect(find.byType(ConfettiOverlay), findsOneWidget);
      await tester.pumpAndSettle();

      // And confetti never appears on defeat: a move-budget exhaustion loses
      // the level and shows the defeat overlay with no confetti (AC2).
      final tableroDerrota = construirTableroDosCaminos();
      final vmDerrota = JuegoViewModel(
        tablero: tableroDerrota,
        moverFlecha: MoverFlechaUseCase(
          tableroDerrota,
          sesion: SesionJuego(
            tablero: tableroDerrota,
            presupuestoMovimientos: const PresupuestoMovimientos(1),
          ),
        ),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
      );
      await tester.pumpWidget(montarJuego(vmDerrota));
      vmDerrota.tocar(const Posicion.en(fila: 0, columna: 0));
      await tester.pump();

      expect(vmDerrota.estado.derrota, isTrue);
      expect(vmDerrota.estado.victoria, isNull);
      expect(find.byType(ConfettiOverlay), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('should_show_confetti_on_bonus_victory', (tester) async {
    // Arrange — a bonus level (score/stars suppressed, mostrarPuntuacion false).
    final tablero = construirTablero();
    final vm = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: bonus,
      reloj: _RelojNulo(),
    );
    await tester.pumpWidget(montarJuego(vm));

    // Act — clear the path to win the bonus level.
    vm.tocar(const Posicion.en(fila: 2, columna: 1));
    await tester.pump();

    // Assert — winning is winning: confetti plays even when the score panel is
    // hidden (AC3).
    expect(vm.estado.victoria, isNotNull);
    expect(vm.estado.victoria!.mostrarPuntuacion, isFalse);
    expect(find.byType(ConfettiOverlay), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
