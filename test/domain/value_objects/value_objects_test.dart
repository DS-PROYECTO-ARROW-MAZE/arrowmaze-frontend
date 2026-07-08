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
  });
}
