import '../../domain/entities/celda.dart';
import '../../domain/entities/trayectoria.dart';
import '../../domain/grafo_tablero.dart';
import '../../domain/solver.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'configuracion_generacion.dart';

/// The minimum number of cells a valid arrow path must span.
///
/// A length-1 arrow is degenerate: it can never interlock with other paths and
/// is always trivially clearable (or trivially blocked). Both generated and
/// loaded boards must satisfy this invariant.
const minLongitudFlecha = 2;

abstract class GeneradorNivelBase {
  const GeneradorNivelBase();
  Tablero? generar(ConfiguracionGeneracion config) {
    final tablero = crearTableroVacio(config);
    poblar(tablero, config);
    if (!validarEstructural(tablero)) return null;
    if (!validarSolvencia(tablero)) {
      return null;
    }
    return entregar(tablero);
  }

  Tablero crearTableroVacio(ConfiguracionGeneracion config) {
    return GrafoTablero.desde(
      filas: config.filas,
      columnas: config.columnas,
      profundo: config.profundo,
      ausentes: config.ausentes,
    );
  }

  void poblar(Tablero tablero, ConfiguracionGeneracion config);

  /// Structural invariants checked before the solver runs.
  ///
  /// Currently enforces [minLongitudFlecha]: no arrow path may have fewer than
  /// 2 cells. Returns `true` when all checks pass.
  bool validarEstructural(Tablero tablero) {
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        for (var p = 0; p < tablero.profundo; p++) {
          final pos = Posicion.en(fila: f, columna: c, capa: p);
          final celda = tablero.celdaEn(pos);
          if (celda is CeldaFlecha) {
            final t = tablero.trayectoriaEn(pos);
            if (t != null && t.segmentos.length < minLongitudFlecha) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool validarSolvencia(Tablero tablero) {
    final trayectorias = <int, Trayectoria>{};
    final celdas = <Celda>[];
    final ausentes = <Posicion>{};
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        for (var p = 0; p < tablero.profundo; p++) {
          final pos = Posicion.en(fila: f, columna: c, capa: p);
          final celda = tablero.celdaEn(pos);
          if (celda is CeldaAusente) {
            ausentes.add(pos);
            continue;
          }
          if (celda is CeldaFlecha) {
            final t = tablero.trayectoriaEn(pos);
            if (t != null && !trayectorias.containsKey(t.id)) {
              trayectorias[t.id] = t;
            }
          } else if (celda is CeldaPared) {
            celdas.add(celda);
          }
        }
      }
    }
    // Validate the actual shaped board: absent positions stay void so a ray
    // exits through them exactly as on the real board (not as transparent
    // empty space, which would let rays travel past the shape's boundary).
    final copia = GrafoTablero.desde(
      filas: tablero.filas,
      columnas: tablero.columnas,
      profundo: tablero.profundo,
      trayectorias: trayectorias.values.toList(),
      celdas: celdas,
      ausentes: ausentes,
    );
    return Solver.esSolvable(copia);
  }

  Tablero entregar(Tablero tablero) {
    return tablero;
  }
}
