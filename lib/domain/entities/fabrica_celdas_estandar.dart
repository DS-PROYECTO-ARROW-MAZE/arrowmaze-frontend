import '../value_objects/direccion.dart';
import '../value_objects/posicion.dart';
import 'celda.dart';
import 'trayectoria.dart';

/// Factory Method that turns a level's JSON into the right domain objects.
///
/// Two products, one per shape of level data: [crear] builds a single fixed
/// [Celda] (a wall or an explicit empty), and [crearTrayectoria] builds a whole
/// arrow [Trayectoria] from a multi-cell path spec. Callers depend only on the
/// abstractions and never branch on `type` themselves (OCP); adding a new kind
/// means extending this one factory, not every call site.
///
/// Expected shapes (see `assets/levels/*.json`):
/// - fixed cell — `{"row": int, "col": int, "type": "wall|empty"}`.
/// - arrow path — `{"id": int, "head": "UP|DOWN|LEFT|RIGHT",
///   "cells": [{"row": int, "col": int}, …]}` ordered tail → head.
class FabricaCeldasEstandar {
  /// Creates the factory. Stateless — safe to share as a `const`.
  const FabricaCeldasEstandar();

  /// Builds a single fixed [Celda] described by [json].
  ///
  /// Handles `wall` and `empty`. Arrows are paths now and are built by
  /// [crearTrayectoria]; an `arrow` here, or any unknown `type`, throws
  /// [ArgumentError] so malformed level data fails loudly.
  Celda crear(Map<String, dynamic> json) {
    final posicion = Posicion.en(
      fila: json['row'] as int,
      columna: json['col'] as int,
    );
    final tipo = json['type'] as String;

    switch (tipo) {
      case 'wall':
        return CeldaPared(posicion);
      case 'empty':
        return CeldaVacia(posicion);
      default:
        throw ArgumentError.value(tipo, 'type', 'Unknown fixed cell type');
    }
  }

  /// Builds an arrow [Trayectoria] from a path [json] spec.
  ///
  /// The `cells` list is ordered tail → head; the head's arrowhead points in
  /// `head`. Throws [ArgumentError] for a missing/invalid `head`, an empty path,
  /// or non-contiguous cells (the latter enforced by [Trayectoria] itself).
  Trayectoria crearTrayectoria(Map<String, dynamic> json) {
    final celdas = (json['cells'] as List<dynamic>).cast<Map<String, dynamic>>();
    return Trayectoria(
      id: json['id'] as int,
      direccionCabeza: _direccionDesde(json['head'] as String?),
      segmentos: celdas
          .map((c) => Posicion.en(fila: c['row'] as int, columna: c['col'] as int))
          .toList(),
    );
  }

  /// Maps a JSON direction token to its [Direccion].
  Direccion _direccionDesde(String? token) {
    switch (token) {
      case 'UP':
        return Direccion.arriba;
      case 'DOWN':
        return Direccion.abajo;
      case 'LEFT':
        return Direccion.izquierda;
      case 'RIGHT':
        return Direccion.derecha;
      default:
        throw ArgumentError.value(token, 'head', 'Unknown direction');
    }
  }
}
