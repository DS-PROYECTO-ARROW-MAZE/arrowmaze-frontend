import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Factory Method must return the correct [Celda] for each `type`, so
/// callers never branch on the type themselves (OCP).
void main() {
  const fabrica = FabricaCeldasEstandar();

  test('should_create_an_arrow_for_each_direction', () {
    // Arrange
    const casos = {
      'UP': Direccion.arriba,
      'DOWN': Direccion.abajo,
      'LEFT': Direccion.izquierda,
      'RIGHT': Direccion.derecha,
    };

    casos.forEach((token, esperada) {
      // Act
      final celda = fabrica.crear(
        {'row': 0, 'col': 0, 'type': 'arrow', 'direction': token},
      );

      // Assert
      expect(celda, isA<CeldaFlecha>());
      expect((celda as CeldaFlecha).direccion, esperada);
    });
  });

  test('should_create_a_wall_when_type_is_wall', () {
    // Arrange / Act
    final celda = fabrica.crear({'row': 1, 'col': 1, 'type': 'wall'});

    // Assert
    expect(celda, isA<CeldaPared>());
    expect(celda.bloqueaRayo, isTrue);
  });

  test('should_create_an_empty_when_type_is_empty', () {
    // Arrange / Act
    final celda = fabrica.crear({'row': 2, 'col': 2, 'type': 'empty'});

    // Assert
    expect(celda, isA<CeldaVacia>());
    expect(celda.bloqueaRayo, isFalse);
  });

  test('should_throw_when_type_is_unknown', () {
    // Arrange / Act / Assert
    expect(
      () => fabrica.crear({'row': 0, 'col': 0, 'type': 'portal'}),
      throwsArgumentError,
    );
  });

  test('should_throw_when_arrow_direction_is_invalid', () {
    // Arrange / Act / Assert
    expect(
      () => fabrica.crear(
        {'row': 0, 'col': 0, 'type': 'arrow', 'direction': 'NORTH'},
      ),
      throwsArgumentError,
    );
  });
}
