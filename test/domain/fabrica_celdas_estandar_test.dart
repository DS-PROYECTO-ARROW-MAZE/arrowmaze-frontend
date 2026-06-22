import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Factory Method must return the correct product for each shape of level
/// data — fixed cells via [FabricaCeldasEstandar.crear], whole arrow paths via
/// [FabricaCeldasEstandar.crearTrayectoria] — so callers never branch on the
/// type themselves (OCP).
void main() {
  const fabrica = FabricaCeldasEstandar();

  test('should_build_a_trayectoria_with_head_direction_for_each_token', () {
    // Arrange
    const casos = {
      'UP': Direccion.arriba,
      'DOWN': Direccion.abajo,
      'LEFT': Direccion.izquierda,
      'RIGHT': Direccion.derecha,
    };

    casos.forEach((token, esperada) {
      // Act
      final trayectoria = fabrica.crearTrayectoria({
        'id': 1,
        'head': token,
        'cells': [
          {'row': 0, 'col': 0},
          {'row': 0, 'col': 1},
        ],
      });

      // Assert
      expect(trayectoria.direccionCabeza, esperada);
      expect(trayectoria.cabeza, const Posicion.en(fila: 0, columna: 1));
      expect(trayectoria.cola, const Posicion.en(fila: 0, columna: 0));
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

  test('should_create_ausente_when_type_is_absent', () {
    final celda = fabrica.crear({'row': 3, 'col': 3, 'type': 'absent'});
    expect(celda, isA<CeldaAusente>());
  });

  test('should_throw_when_fixed_cell_type_is_unknown', () {
    // Arrange / Act / Assert
    expect(
      () => fabrica.crear({'row': 0, 'col': 0, 'type': 'portal'}),
      throwsArgumentError,
    );
  });

  test('should_throw_when_path_head_direction_is_invalid', () {
    // Arrange / Act / Assert
    expect(
      () => fabrica.crearTrayectoria({
        'id': 1,
        'head': 'NORTH',
        'cells': [
          {'row': 0, 'col': 0},
        ],
      }),
      throwsArgumentError,
    );
  });
}
