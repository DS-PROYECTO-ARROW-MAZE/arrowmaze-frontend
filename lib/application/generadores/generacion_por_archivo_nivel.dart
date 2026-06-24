import 'package:arrowmaze/domain/value_objects/posicion.dart';

import '../../domain/entities/fabrica_celdas_estandar.dart';
import '../../domain/grafo_tablero.dart';
import '../../domain/tablero.dart';
import '../ports/cargador_nivel.dart';
import '../ports/definicion_nivel_dto.dart';
import 'configuracion_generacion.dart';
import 'generador_nivel_base.dart';

class GeneracionPorArchivoNivel extends GeneradorNivelBase {
  GeneracionPorArchivoNivel({required this.cargador});

  final CargadorNivel cargador;
  final FabricaCeldasEstandar _fabrica = const FabricaCeldasEstandar();
  DefinicionNivelDto? _definicion;

  Future<Tablero?> generarAsync(
    ConfiguracionGeneracion config, {
    required int idNivel,
  }) async {
    _definicion = await cargador.cargar(idNivel);
    final ausentes = _definicion!.ausentes
        .map((j) => Posicion.en(fila: j['row'] as int, columna: j['col'] as int))
        .toSet();
    final configAjustada = ConfiguracionGeneracion(
      filas: _definicion!.filas,
      columnas: _definicion!.columnas,
      ausentes: ausentes,
    );
    return generar(configAjustada);
  }

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    final definicion = _definicion!;
    final grafo = tablero as GrafoTablero;
    for (final json in definicion.trayectorias) {
      grafo.agregarTrayectoria(_fabrica.crearTrayectoria(json));
    }
    for (final json in definicion.celdas) {
      grafo.agregarCelda(_fabrica.crear(json));
    }
    // Absent cells are already handled by the board construction (via config.ausentes),
    // so no need to apply them here.
  }
}
