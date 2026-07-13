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
/// - fixed cell — `{"row": int, "col": int, "layer": int?, "type": "wall|empty"}`.
/// - arrow path — `{"id": int, "head": "UP|DOWN|LEFT|RIGHT|FORWARD|BACKWARD",
///   "cells": [{"row": int, "col": int, "layer": int?}, …]}` ordered tail → head.
///
/// `layer` is optional on every cell and defaults to `0`, so every existing
/// (2D) level file keeps working unchanged.
class FabricaCeldasEstandar {
  /// Creates the factory. Stateless — safe to share as a `const`.
  const FabricaCeldasEstandar();

  /// Maps a JSON direction token to its [Direccion] — the single lookup table
  /// every direction string resolves through, cardinal or depth alike.
  static const Map<String, Direccion> _direcciones = <String, Direccion>{
    'UP': Direccion.arriba,
    'DOWN': Direccion.abajo,
    'LEFT': Direccion.izquierda,
    'RIGHT': Direccion.derecha,
    'FORWARD': Direccion.adelante,
    'BACKWARD': Direccion.atras,
  };

  /// Builds a single fixed [Celda] described by [json].
  ///
  /// Handles `wall`, `empty` and `collectible`. Arrows are paths now and are
  /// built by [crearTrayectoria]; an `arrow` here, or any unknown `type`, throws
  /// [ArgumentError] so malformed level data fails loudly.
  Celda crear(Map<String, dynamic> json) {
    final posicion = _posicionDesde(json);
    final tipo = json['type'] as String;

    switch (tipo) {
      case 'wall':
        return CeldaPared(posicion);
      case 'empty':
        return CeldaVacia(posicion);
      case 'collectible':
        return Coleccionable(posicion);
      case 'absent':
        return CeldaAusente(posicion);
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
      segmentos: celdas.map(_posicionDesde).toList(),
    );
  }

  /// The [Posicion] a fixed-cell or path-segment [json] map describes;
  /// `layer` is optional and defaults to `0`.
  Posicion _posicionDesde(Map<String, dynamic> json) => Posicion.en(
        fila: json['row'] as int,
        columna: json['col'] as int,
        capa: json['layer'] as int? ?? 0,
      );

  /// Maps a JSON direction token to its [Direccion].
  Direccion _direccionDesde(String? token) {
    final direccion = _direcciones[token];
    if (direccion == null) {
      throw ArgumentError.value(token, 'head', 'Unknown direction');
    }
    return direccion;
  }
}
