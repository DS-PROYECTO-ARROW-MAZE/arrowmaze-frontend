import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 — depth-aware `GrafoTablero.desde`. `profundo` links neighbours
/// across all six directions in a single loop (no branching on dimension), so
/// a `profundo: 1` board (every existing 2D fixture) links zero depth
/// neighbours — a pure regression — while a `profundo: 2+` board gets real
/// cross-layer links both ways.
void main() {
  test('should_default_profundo_to_one', () {
    // Arrange / Act
    final tablero = GrafoTablero.desde(filas: 2, columnas: 2);

    // Assert
    expect(tablero.profundo, 1);
  });

  test('should_seed_empty_cells_across_every_layer_when_profundo_greater_than_one',
      () {
    // Arrange / Act
    final tablero = GrafoTablero.desde(filas: 1, columnas: 1, profundo: 2);

    // Assert — both layers exist as transparent empty space.
    expect(tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 0)),
        isA<CeldaVacia>());
    expect(tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 1)),
        isA<CeldaVacia>());
  });

  test('should_link_cross_layer_neighbours_both_ways_when_profundo_two', () {
    // Arrange
    final tablero = GrafoTablero.desde(filas: 1, columnas: 1, profundo: 2);

    // Act
    final capa0 = tablero.nodoEn(const Posicion.en(fila: 0, columna: 0, capa: 0));
    final capa1 = tablero.nodoEn(const Posicion.en(fila: 0, columna: 0, capa: 1));

    // Assert — linked both ways via adelante/atras.
    expect(identical(capa0.vecinos[Direccion.adelante], capa1), isTrue);
    expect(identical(capa1.vecinos[Direccion.atras], capa0), isTrue);
  });

  test('should_link_zero_depth_neighbours_when_profundo_one', () {
    // Arrange — every existing 2D fixture implicitly exercises this: a
    // profundo:1 board must behave exactly as before (regression).
    final tablero = GrafoTablero.desde(filas: 3, columnas: 3);

    // Act
    final nodo = tablero.nodoEn(const Posicion.en(fila: 1, columna: 1));

    // Assert — no depth neighbour exists to link.
    expect(nodo.vecinos.containsKey(Direccion.adelante), isFalse);
    expect(nodo.vecinos.containsKey(Direccion.atras), isFalse);
  });

  test('should_raycast_across_layers_when_ray_travels_through_depth', () {
    // Arrange — a 1x1x3 stack, nothing blocking.
    final tablero = GrafoTablero.desde(filas: 1, columnas: 1, profundo: 3);

    // Act — from layer 0, forward should exit clear at the far side.
    final resultado = tablero.raycast(
      const Posicion.en(fila: 0, columna: 0, capa: 0),
      Direccion.adelante,
    );

    // Assert
    expect(resultado.despejadoHastaBorde, isTrue);
  });
}
