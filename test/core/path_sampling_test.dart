import 'package:arrowmaze/core/animacion/muestreador_trayectoria.dart';
import 'package:arrowmaze/core/animacion/punto2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 22 — pure arc-length path sampler (core, no Flutter).
///
/// The exit animation is a *snake gait*: the head advances along the path's own
/// bending polyline toward the edge, and every tail segment follows the identical
/// curve one cell of arc-length behind the one ahead. These tests pin that
/// behaviour on the pure sampler, independent of any widget or controller.
void main() {
  /// Matches a [Punto2D] against expected coordinates within a small tolerance.
  void esperarPunto(Punto2D real, double x, double y) {
    expect(real.x, closeTo(x, 1e-9), reason: 'x of $real');
    expect(real.y, closeTo(y, 1e-9), reason: 'y of $real');
  }

  group('MuestreadorTrayectoria — arc-length snake sampling', () {
    // An L-shaped, unit-spaced polyline bending 90° at the corner (2,0):
    // (0,0)→(1,0)→(2,0)┐
    //                  (2,1)→(2,2)
    final polilineaL = <Punto2D>[
      const Punto2D(0, 0),
      const Punto2D(1, 0),
      const Punto2D(2, 0),
      const Punto2D(2, 1),
      const Punto2D(2, 2),
    ];

    test(
      'should_place_tail_segments_one_cell_behind_head_along_curve_when_sampled_at_t',
      () {
        // Arrange
        final muestreador = MuestreadorTrayectoria(polilineaL);

        // Act — head sitting on the corner's far arm, two tails trailing it.
        final segmentos = muestreador.segmentosDesde(
          longitudCabeza: 3.0,
          cantidad: 3,
        );

        // Assert — head on the vertical arm, the next segment ON the corner,
        // the last on the horizontal arm: the tail turns where the head turned,
        // never a rigid diagonal offset.
        expect(segmentos, hasLength(3));
        esperarPunto(segmentos[0], 2, 1); // head
        esperarPunto(segmentos[1], 2, 0); // one cell of arc behind: the corner
        esperarPunto(segmentos[2], 1, 0); // two cells behind: horizontal arm

        // Act — a fractional head position straddling the bend.
        final aMedias = muestreador.segmentosDesde(
          longitudCabeza: 2.5,
          cantidad: 3,
        );

        // Assert — each tail is one unit of *arc-length* behind, so the segment
        // behind the corner is on the horizontal arm (1.5,0), NOT the rigid
        // straight-line offset (1,0.5) a whole-shape slide would give.
        esperarPunto(aMedias[0], 2, 0.5);
        esperarPunto(aMedias[1], 1.5, 0);
        esperarPunto(aMedias[2], 0.5, 0);

        // Assert — on a straight stretch the inter-segment spacing is exactly one
        // cell (constant gait), here along the horizontal arm.
        final recto = muestreador.segmentosDesde(
          longitudCabeza: 2.0,
          cantidad: 3,
        );
        esperarPunto(recto[0], 2, 0);
        esperarPunto(recto[1], 1, 0);
        esperarPunto(recto[2], 0, 0);
      },
    );

    test('should_reach_edge_target_when_t_equals_one', () {
      // Arrange — a straight path of 3 body cells extended two cells past the
      // head to the off-board edge target (4,0).
      final polilinea = <Punto2D>[
        const Punto2D(0, 0),
        const Punto2D(1, 0),
        const Punto2D(2, 0), // head's starting cell
        const Punto2D(3, 0),
        const Punto2D(4, 0), // edge target (off-board)
      ];
      final muestreador = MuestreadorTrayectoria(polilinea);

      // Act — full progress.
      final segmentos = muestreador.posicionesSegmentos(t: 1.0, cantidad: 3);

      // Assert — at t = 1 the head has reached the edge target.
      esperarPunto(segmentos.first, 4, 0);

      // And at t = 0 it sits back on its starting cell (arc-length cantidad-1).
      final inicio = muestreador.posicionesSegmentos(t: 0.0, cantidad: 3);
      esperarPunto(inicio.first, 2, 0);
    });
  });
}
