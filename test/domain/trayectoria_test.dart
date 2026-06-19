import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Trayectoria` is the continuous, possibly bending arrow path. These tests
/// pin down its geometry (head/tail, straight vs corner connections) and its
/// fail-loud validation of malformed (non-contiguous) paths.
void main() {
  // An L-shaped path: down the first column, then right, head pointing right.
  Trayectoria construirEle() => Trayectoria(
        id: 1,
        direccionCabeza: Direccion.derecha,
        segmentos: const [
          Posicion.en(fila: 0, columna: 0),
          Posicion.en(fila: 1, columna: 0),
          Posicion.en(fila: 1, columna: 1),
        ],
      );

  test('should_expose_head_and_tail_when_built_from_segments', () {
    // Arrange / Act
    final trayectoria = construirEle();

    // Assert — tail is the first segment, head the last.
    expect(trayectoria.cola, const Posicion.en(fila: 0, columna: 0));
    expect(trayectoria.cabeza, const Posicion.en(fila: 1, columna: 1));
    expect(trayectoria.esCabeza(const Posicion.en(fila: 1, columna: 1)), isTrue);
    expect(trayectoria.esCabeza(const Posicion.en(fila: 0, columna: 0)), isFalse);
  });

  test('should_report_two_perpendicular_connections_when_segment_is_a_corner',
      () {
    // Arrange — (1,0) is the bend: it connects up to (0,0) and right to (1,1).
    final trayectoria = construirEle();

    // Act
    final conexiones =
        trayectoria.conexionesEn(const Posicion.en(fila: 1, columna: 0));

    // Assert — a corner: two perpendicular directions.
    expect(conexiones, {Direccion.arriba, Direccion.derecha});
  });

  test('should_report_one_connection_when_segment_is_an_endpoint', () {
    // Arrange
    final trayectoria = construirEle();

    // Act + Assert — the head connects only back toward its predecessor.
    expect(
      trayectoria.conexionesEn(const Posicion.en(fila: 1, columna: 1)),
      {Direccion.izquierda},
    );
  });

  test('should_throw_when_segments_are_not_contiguous', () {
    // Arrange / Act / Assert — a gap between (0,0) and (0,2) is illegal.
    expect(
      () => Trayectoria(
        id: 2,
        direccionCabeza: Direccion.derecha,
        segmentos: const [
          Posicion.en(fila: 0, columna: 0),
          Posicion.en(fila: 0, columna: 2),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('should_throw_when_path_is_empty', () {
    // Arrange / Act / Assert
    expect(
      () => Trayectoria(
        id: 3,
        direccionCabeza: Direccion.arriba,
        segmentos: const [],
      ),
      throwsArgumentError,
    );
  });
}
