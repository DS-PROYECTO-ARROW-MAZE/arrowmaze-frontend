import '../../domain/entities/celda.dart';
import '../../domain/entities/trayectoria.dart';
import '../../domain/grafo_tablero.dart';
import '../../domain/solver.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'configuracion_generacion.dart';

abstract class GeneradorNivelBase {
  const GeneradorNivelBase();
  Tablero? generar(ConfiguracionGeneracion config) {
    final tablero = crearTableroVacio(config);
    poblar(tablero, config);
    if (!validarSolvencia(tablero)) {
      return null;
    }
    return entregar(tablero);
  }

  Tablero crearTableroVacio(ConfiguracionGeneracion config) {
    return GrafoTablero.desde(
      filas: config.filas,
      columnas: config.columnas,
    );
  }

  void poblar(Tablero tablero, ConfiguracionGeneracion config);

  bool validarSolvencia(Tablero tablero) {
    final trayectorias = <int, Trayectoria>{};
    final celdas = <Celda>[];
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        final pos = Posicion.en(fila: f, columna: c);
        final celda = tablero.celdaEn(pos);
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
    final copia = GrafoTablero.desde(
      filas: tablero.filas,
      columnas: tablero.columnas,
      trayectorias: trayectorias.values.toList(),
      celdas: celdas,
    );
    return Solver.esSolvable(copia);
  }

  Tablero entregar(Tablero tablero) {
    return tablero;
  }
}
