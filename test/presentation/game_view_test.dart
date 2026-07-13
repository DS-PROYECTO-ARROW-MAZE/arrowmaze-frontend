import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/core/i18n/cadenas_en.dart';
import 'package:arrowmaze/core/i18n/cadenas_scope.dart';
import 'package:arrowmaze/core/theme/game_theme.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
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

/// A clock whose one-second tick is fired manually from the test, so a timed
/// level's countdown can be driven a second at a time across the hint window.
class _RelojControlable implements Reloj {
  void Function()? _callback;

  @override
  void iniciar(Duration intervalo, void Function() tic) => _callback = tic;

  @override
  void detener() {}

  /// Advances the session clock by one second.
  void tic() => _callback?.call();
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

  group('conditional hint button (ticket 35)', () {
    // A timed level (numero >= 10, non-bonus) — the only kind the time gate can
    // ever open on.
    const definicionMedia = DefinicionNivel(
      id: 10,
      numero: 10,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      limiteTiempo: Duration(seconds: 27),
    );

    // While time-locked the button wears a padlock; once unlocked (or spent) it
    // wears a lit bulb.
    final hintBloqueadoFinder =
        find.widgetWithIcon(IconButton, Icons.lock_outline);
    final hintDisponibleFinder =
        find.widgetWithIcon(IconButton, Icons.lightbulb);

    /// Builds a medium timed level whose clock the returned [_RelojControlable]
    /// drives a second at a time, so tests can cross the 25 s hint boundary.
    ({JuegoViewModel vm, _RelojControlable reloj}) montarMedio(
      WidgetTester tester, {
      required Duration limite,
    }) {
      final tablero = construirTablero();
      final reloj = _RelojControlable();
      final vm = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(
          tablero,
          sesion: SesionJuego(tablero: tablero, limiteTiempo: limite),
        ),
        definicionNivel: definicionMedia,
        reloj: reloj,
        dificultad: Dificultad.medio,
      );
      return (vm: vm, reloj: reloj);
    }

    testWidgets('should_not_build_hint_button_on_easy_level', (tester) async {
      // Arrange — an easy level: Rule A forbids the button entirely.
      final tablero = construirTablero();
      final vm = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
        dificultad: Dificultad.facil,
      );
      await tester.pumpWidget(montarJuego(vm));

      // Assert — the hint button is never built on easy (AC1), in either look.
      expect(hintBloqueadoFinder, findsNothing);
      expect(hintDisponibleFinder, findsNothing);
    });

    testWidgets(
      'should_render_hint_locked_then_unlocked_across_25s_boundary',
      (tester) async {
        // Arrange — a medium timed level starting one second above the window.
        final ctx = montarMedio(tester, limite: const Duration(seconds: 27));
        await tester.pumpWidget(montarJuego(ctx.vm));

        // The button participates (Rule A) but wears the padlock at start
        // (27 > 25, Rule B). It stays tappable so an early tap can explain it.
        expect(hintBloqueadoFinder, findsOneWidget);
        expect(hintDisponibleFinder, findsNothing);
        expect(
          tester.widget<IconButton>(hintBloqueadoFinder).onPressed,
          isNotNull,
        );

        // 27→26 is still above the threshold — still padlocked.
        ctx.reloj.tic();
        await tester.pump();
        expect(hintBloqueadoFinder, findsOneWidget);

        // 26→25 crosses the boundary — the bulb lights up (AC4).
        ctx.reloj.tic();
        await tester.pump();
        expect(hintBloqueadoFinder, findsNothing);
        expect(hintDisponibleFinder, findsOneWidget);
      },
    );

    testWidgets('should_spotlight_a_suggested_arrow_when_hint_tapped',
        (tester) async {
      // Arrange — a medium timed level driven into the hint window. The only
      // arrow's head (1,0) exits left with a clear ray.
      final ctx = montarMedio(tester, limite: const Duration(seconds: 26));
      await tester.pumpWidget(montarJuego(ctx.vm));
      ctx.reloj.tic(); // 26→25 unlocks the bulb
      await tester.pump();

      // No spotlight until the player asks.
      expect(find.byKey(const ValueKey('hint-spot')), findsNothing);

      // Act — tap the (now unlocked) hint button.
      await tester.tap(hintDisponibleFinder);
      await tester.pump();

      // Assert — the suggested arrow is spotlighted (something visibly happens).
      expect(ctx.vm.estado.pistaSugerida, const Posicion.en(fila: 1, columna: 0));
      expect(find.byKey(const ValueKey('hint-spot')), findsOneWidget);

      // Drain the pulse so no timers outlive the test.
      await tester.pumpAndSettle();
    });

    testWidgets('should_show_locked_notice_when_hint_tapped_too_early',
        (tester) async {
      // Arrange — a medium timed level still 40 s out (15 s before the 25 s gate).
      final ctx = montarMedio(tester, limite: const Duration(seconds: 40));
      await tester.pumpWidget(montarJuego(ctx.vm));

      // Act — tap the padlocked button before it unlocks.
      await tester.tap(hintBloqueadoFinder);
      await tester.pump();

      // Assert — a notice explains it is still locked for 15 s, and no hint fired.
      expect(ctx.vm.estado.pistaSugerida, isNull);
      expect(find.text('Hint locked — unlocks in 15s'), findsOneWidget);
      expect(find.byKey(const ValueKey('hint-spot')), findsNothing);
    });

    testWidgets('should_disable_hint_button_after_it_is_used_once',
        (tester) async {
      // Arrange — a medium timed level driven into the hint window.
      final ctx = montarMedio(tester, limite: const Duration(seconds: 26));
      await tester.pumpWidget(montarJuego(ctx.vm));
      ctx.reloj.tic(); // 26→25 unlocks the bulb
      await tester.pump();

      // Act — spend the single hint.
      await tester.tap(hintDisponibleFinder);
      await tester.pump();

      // Assert — the button remains (still a bulb) but is now disabled: the hint
      // is once-per-level and cannot be requested again.
      expect(ctx.vm.estado.pistaUsada, isTrue);
      expect(hintDisponibleFinder, findsOneWidget);
      expect(
        tester.widget<IconButton>(hintDisponibleFinder).onPressed,
        isNull,
      );

      await tester.pumpAndSettle();
    });
  });
}
