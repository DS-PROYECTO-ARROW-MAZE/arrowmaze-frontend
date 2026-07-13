import 'package:arrowmaze/core/animacion/orientacion_cubo.dart';
import 'package:arrowmaze/core/i18n/cadenas_en.dart';
import 'package:arrowmaze/core/i18n/cadenas_scope.dart';
import 'package:arrowmaze/core/theme/game_theme.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/views/game/cubo_3d_view.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 (redesign) — the rotatable 3D cube: a drag orbits the board, a
/// tap-without-drag resolves the **frontmost** visible cell under the tap
/// point via the exact same projection the painter draws with (never two
/// implementations to drift out of sync), and a drag that moves far enough
/// never resolves a tap at all.
void main() {
  Widget montar(TableroUI tablero, void Function(Posicion) onTap) {
    return MaterialApp(
      home: CadenasScope(
        cadenas: const CadenasEn(),
        child: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: Cubo3D(
              tablero: tablero,
              game: GameTheme.dark,
              onTap: onTap,
              // Identity orientation makes the projected screen position of
              // every cell trivially predictable by hand in these tests.
              orientacionInicial: const OrientacionCubo(),
            ),
          ),
        ),
      ),
    );
  }

  /// A 1x1 footprint, 2-layer stack: both cells share the same (fila,
  /// columna) and so project to the exact same screen point under an
  /// identity orientation — only their `capa` (and therefore projected
  /// scale) differs. `capa: 1` sits closer to the camera (larger scale) than
  /// `capa: 0`.
  TableroUI construirPila() {
    return const TableroUI(
      filas: 1,
      columnas: 1,
      profundo: 2,
      celdas: [
        CeldaUI(
          posicion: Posicion.en(fila: 0, columna: 0, capa: 0),
          tipo: TipoCeldaUI.flecha,
          idFlecha: 1,
          esCabeza: true,
          direccion: Direccion.adelante,
        ),
        CeldaUI(
          posicion: Posicion.en(fila: 0, columna: 0, capa: 1),
          tipo: TipoCeldaUI.flecha,
          idFlecha: 42,
          esCabeza: true,
          direccion: Direccion.adelante,
        ),
      ],
    );
  }

  testWidgets(
    'should_resolve_the_frontmost_cell_when_tapping_its_shared_projected_center',
    (tester) async {
      // Arrange
      Posicion? tocada;
      await tester.pumpWidget(montar(construirPila(), (p) => tocada = p));

      // Act — tap the exact widget centre (both cells project there).
      await tester.tapAt(const Offset(150, 150));
      await tester.pump();

      // Assert — the frontmost (capa: 1, larger scale) cell wins.
      expect(tocada, const Posicion.en(fila: 0, columna: 0, capa: 1));
    },
  );

  testWidgets('should_ignore_tap_when_outside_every_cells_hit_radius',
      (tester) async {
    // Arrange
    Posicion? tocada;
    await tester.pumpWidget(montar(construirPila(), (p) => tocada = p));

    // Act — tap a far corner, well outside any projected cell's hit radius.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    // Assert
    expect(tocada, isNull);
  });

  testWidgets(
    'should_not_resolve_a_tap_when_the_drag_exceeds_the_tap_threshold',
    (tester) async {
      // Arrange
      Posicion? tocada;
      await tester.pumpWidget(montar(construirPila(), (p) => tocada = p));

      // Act — a real drag (well past the tap-vs-drag threshold), starting on
      // the cell and ending elsewhere.
      await tester.dragFrom(const Offset(150, 150), const Offset(80, 40));
      await tester.pump();

      // Assert — rotating never resolves a tap.
      expect(tocada, isNull);
    },
  );

  testWidgets('should_render_a_drag_to_rotate_caption', (tester) async {
    // Arrange / Act
    await tester.pumpWidget(montar(construirPila(), (_) {}));

    // Assert — a discoverability hint is shown (ticket 36 redesign).
    expect(find.text(const CadenasEn().arrastrarParaRotar), findsOneWidget);
  });
}
