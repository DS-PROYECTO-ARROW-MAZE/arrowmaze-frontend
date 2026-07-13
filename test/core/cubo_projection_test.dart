import 'dart:math' as math;

import 'package:arrowmaze/core/animacion/orientacion_cubo.dart';
import 'package:arrowmaze/core/animacion/punto2d.dart';
import 'package:arrowmaze/core/animacion/punto3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure 3D rotation/projection math behind the depth-aware board's rotatable
/// cube view. No Flutter dependency — the View converts the resulting
/// [Punto2D] to pixel `Offset`s when it paints.
void main() {
  void esperarPunto3D(Punto3D real, double x, double y, double z) {
    expect(real.x, closeTo(x, 1e-9), reason: 'x of $real');
    expect(real.y, closeTo(y, 1e-9), reason: 'y of $real');
    expect(real.z, closeTo(z, 1e-9), reason: 'z of $real');
  }

  group('Punto3D', () {
    test('should_compare_by_value_when_coordinates_match', () {
      expect(const Punto3D(1, 2, 3), const Punto3D(1, 2, 3));
      expect(const Punto3D(1, 2, 3) == const Punto3D(1, 2, 4), isFalse);
      expect(const Punto3D(1, 2, 3).hashCode, const Punto3D(1, 2, 3).hashCode);
    });
  });

  group('OrientacionCubo.aplicar — rotation', () {
    test('should_be_identity_when_yaw_and_pitch_are_zero', () {
      const orientacion = OrientacionCubo();
      esperarPunto3D(orientacion.aplicar(const Punto3D(1, 2, 3)), 1, 2, 3);
    });

    test('should_swap_x_and_z_when_yaw_is_90_degrees', () {
      final orientacion = OrientacionCubo(yaw: math.pi / 2);
      esperarPunto3D(orientacion.aplicar(const Punto3D(1, 0, 0)), 0, 0, -1);
      esperarPunto3D(orientacion.aplicar(const Punto3D(0, 0, 1)), 1, 0, 0);
      // The y axis (vertical) is untouched by a pure yaw.
      esperarPunto3D(orientacion.aplicar(const Punto3D(0, 5, 0)), 0, 5, 0);
    });

    test('should_rotate_y_into_z_when_pitch_is_90_degrees', () {
      final orientacion = OrientacionCubo(pitch: math.pi / 2);
      esperarPunto3D(orientacion.aplicar(const Punto3D(0, 1, 0)), 0, 0, 1);
      // The x axis (horizontal) is untouched by a pure pitch.
      esperarPunto3D(orientacion.aplicar(const Punto3D(5, 0, 0)), 5, 0, 0);
    });

    test('should_clamp_pitch_within_bounds_when_rotating_repeatedly', () {
      const orientacion = OrientacionCubo();
      final girada = orientacion.rotada(dYaw: 0, dPitch: 100);
      expect(girada.pitch, lessThanOrEqualTo(OrientacionCubo.pitchMaximo));

      final giradaNegativa = orientacion.rotada(dYaw: 0, dPitch: -100);
      expect(
        giradaNegativa.pitch,
        greaterThanOrEqualTo(-OrientacionCubo.pitchMaximo),
      );
    });

    test('should_accumulate_yaw_without_bound_when_rotating_repeatedly', () {
      // Yaw (horizontal orbit) never needs clamping — it wraps naturally
      // through sin/cos.
      const orientacion = OrientacionCubo(yaw: 1.0);
      final girada = orientacion.rotada(dYaw: 0.5, dPitch: 0);
      expect(girada.yaw, closeTo(1.5, 1e-9));
    });
  });

  group('OrientacionCubo.proyectar — screen projection', () {
    const orientacion = OrientacionCubo();

    test('should_be_a_no_op_projection_when_z_is_zero', () {
      final proyectado = orientacion.proyectar(const Punto3D(2, 3, 0));
      expect(proyectado.pantalla, const Punto2D(2, 3));
      expect(proyectado.escala, closeTo(1.0, 1e-9));
    });

    test('should_scale_up_when_point_is_closer_to_camera', () {
      final cercano = orientacion.proyectar(const Punto3D(0, 0, 1));
      final lejano = orientacion.proyectar(const Punto3D(0, 0, -1));
      expect(cercano.escala, greaterThan(1.0));
      expect(lejano.escala, lessThan(1.0));
      expect(cercano.escala, greaterThan(lejano.escala));
    });

    test('should_never_go_non_positive_when_scaling_far_points', () {
      final proyectado = orientacion.proyectar(const Punto3D(0, 0, -100));
      expect(proyectado.escala, greaterThan(0));
    });

    test('should_apply_scale_to_screen_coordinates', () {
      final proyectado =
          orientacion.proyectar(const Punto3D(2, 4, 1), factorProfundidad: 0.5);
      // escala = 1 + 1*0.5 = 1.5
      expect(proyectado.escala, closeTo(1.5, 1e-9));
      expect(proyectado.pantalla, const Punto2D(3, 6));
    });

    test('should_rotate_then_project_when_using_proyectarPunto', () {
      final girada = OrientacionCubo(yaw: math.pi / 2);
      // (0,0,1) rotates to (1,0,0) — a z=0 result, so escala stays 1.
      final proyectado = girada.proyectarPunto(const Punto3D(0, 0, 1));
      expect(proyectado.pantalla, const Punto2D(1, 0));
      expect(proyectado.escala, closeTo(1.0, 1e-9));
    });
  });
}
