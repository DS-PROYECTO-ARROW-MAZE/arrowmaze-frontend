import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/domain/value_objects/vector3.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behavioural tests for the dimension-agnostic value objects underpinning the
/// `Tablero` contract.
void main() {
  group('Vector3', () {
    test('should_add_componentwise_and_negate_when_operating_on_vectors', () {
      // Arrange
      const a = Vector3(1, 2, 3);
      const b = Vector3(-1, 4, 0);

      // Act + Assert
      expect(a + b, const Vector3(0, 6, 3));
      expect(a.negado, const Vector3(-1, -2, -3));
    });

    test('should_compare_by_value_when_components_match', () {
      // Arrange / Act / Assert
      expect(const Vector3(1, 2, 0), const Vector3(1, 2, 0));
      expect(const Vector3(1, 2, 0).hashCode, const Vector3(1, 2, 0).hashCode);
      expect(const Vector3(1, 2, 0) == const Vector3(9, 2, 0), isFalse);
      expect(const Vector3(1, 2, 0).toString(), contains('1'));
    });
  });

  group('Posicion', () {
    test('should_step_to_the_neighbour_when_desplazar_along_a_direction', () {
      // Arrange
      const origen = Posicion.en(fila: 2, columna: 2);

      // Act + Assert
      expect(origen.desplazar(Direccion.arriba),
          const Posicion.en(fila: 1, columna: 2));
      expect(origen.desplazar(Direccion.derecha),
          const Posicion.en(fila: 2, columna: 3));
    });

    test('should_compare_by_value_when_coordinates_match', () {
      // Arrange / Act / Assert
      expect(const Posicion.en(fila: 1, columna: 1),
          const Posicion.en(fila: 1, columna: 1));
      expect(
        const Posicion.en(fila: 1, columna: 1) ==
            const Posicion.en(fila: 2, columna: 1),
        isFalse,
      );
      expect(const Posicion.en(fila: 1, columna: 1).hashCode,
          const Posicion.en(fila: 1, columna: 1).hashCode);
      expect(const Posicion.en(fila: 1, columna: 1).toString(),
          contains('fila: 1'));
    });

    test('should_default_capa_to_zero', () {
      // Arrange / Act / Assert
      expect(const Posicion.en(fila: 0, columna: 0).capa, 0);
      expect(const Posicion.en(fila: 0, columna: 0),
          const Posicion.en(fila: 0, columna: 0, capa: 0));
    });

    test('should_distinguish_positions_by_capa_when_comparing', () {
      // Arrange
      const enCapa0 = Posicion.en(fila: 1, columna: 1);
      const enCapa1 = Posicion.en(fila: 1, columna: 1, capa: 1);

      // Act + Assert — same fila/columna, different capa ⇒ not equal.
      expect(enCapa0 == enCapa1, isFalse);
      expect(enCapa0.hashCode == enCapa1.hashCode, isFalse);
    });

    test('should_step_capa_by_one_when_desplazar_adelante_or_atras', () {
      // Arrange
      const origen = Posicion.en(fila: 0, columna: 0, capa: 1);

      // Act + Assert
      expect(origen.desplazar(Direccion.adelante),
          const Posicion.en(fila: 0, columna: 0, capa: 2));
      expect(origen.desplazar(Direccion.atras),
          const Posicion.en(fila: 0, columna: 0, capa: 0));
    });
  });

  group('Direccion', () {
    test('should_expose_the_opposite_when_asked_for_each_cardinal', () {
      // Arrange / Act / Assert
      expect(Direccion.arriba.opuesta, Direccion.abajo);
      expect(Direccion.izquierda.opuesta, Direccion.derecha);
    });

    test('should_compare_by_value_and_list_four_cardinals_when_inspected', () {
      // Arrange / Act / Assert
      expect(Direccion.arriba, const Direccion(Vector3(0, -1, 0)));
      expect(Direccion.arriba.hashCode,
          const Direccion(Vector3(0, -1, 0)).hashCode);
      expect(Direccion.arriba == Direccion.abajo, isFalse);
      expect(Direccion.cardinales, hasLength(4));
      expect(Direccion.derecha.toString(), contains('1'));
    });

    test('should_expose_forward_and_backward_as_opposite_z_steps', () {
      // Arrange / Act / Assert
      expect(Direccion.adelante, const Direccion(Vector3(0, 0, 1)));
      expect(Direccion.atras, const Direccion(Vector3(0, 0, -1)));
      expect(Direccion.adelante.opuesta, Direccion.atras);
      expect(Direccion.atras.opuesta, Direccion.adelante);
    });

    test('should_expose_six_directions_when_profundo_greater_than_one', () {
      // Arrange / Act / Assert — cardinales stays four (2D contract unchanged);
      // todas extends it with adelante/atras for a depth-aware board.
      expect(Direccion.todas, hasLength(6));
      expect(Direccion.todas, containsAll(Direccion.cardinales));
      expect(Direccion.todas, containsAll([Direccion.adelante, Direccion.atras]));
    });

    test('should_recover_forward_and_backward_from_desdePaso', () {
      // Arrange / Act / Assert — desdePaso must resolve z-steps too, so a
      // Trayectoria bending through depth can compute its connections.
      expect(Direccion.desdePaso(const Vector3(0, 0, 1)), Direccion.adelante);
      expect(Direccion.desdePaso(const Vector3(0, 0, -1)), Direccion.atras);
    });
  });
}
