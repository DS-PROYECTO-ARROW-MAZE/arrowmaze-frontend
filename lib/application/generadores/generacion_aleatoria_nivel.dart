import '../../domain/entities/trayectoria.dart';
import '../../domain/grafo_tablero.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/direccion.dart';
import '../../domain/value_objects/posicion.dart';
import 'configuracion_generacion.dart';
import 'generador_nivel_base.dart';

class GeneracionAleatoriaNivel extends GeneradorNivelBase {
  const GeneracionAleatoriaNivel();

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    final grafo = tablero as GrafoTablero;
    var nextId = 1;

    for (var f = 0; f < config.filas; f++) {
      for (var c = 0; c < config.columnas; c++) {
        final enBorde = f == 0 ||
            f == config.filas - 1 ||
            c == 0 ||
            c == config.columnas - 1;
        if (!enBorde) continue;

        final pos = Posicion.en(fila: f, columna: c);
        final direccion = _direccionSalida(f, c, config);
        grafo.agregarTrayectoria(Trayectoria(
          id: nextId++,
          direccionCabeza: direccion,
          segmentos: [pos],
        ));
      }
    }
  }

  Direccion _direccionSalida(
    int fila,
    int columna,
    ConfiguracionGeneracion config,
  ) {
    if (fila == 0) return Direccion.arriba;
    if (fila == config.filas - 1) return Direccion.abajo;
    if (columna == 0) return Direccion.izquierda;
    return Direccion.derecha;
  }
}
