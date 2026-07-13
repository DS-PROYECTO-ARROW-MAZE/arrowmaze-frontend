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
    return generarDesdeDefinicionAsync(await cargador.cargar(idNivel));
  }

  /// Generates a board straight from an already-resolved [definicion],
  /// bypassing [cargador]/[CargadorNivel.cargar].
  ///
  /// This is the QA/debug entry point the bundled 3D test boards are loaded
  /// through (Ticket 36): a caller resolves the definition itself — e.g. via
  /// `CargadorNivelArchivo.cargarPorNombre` for a level outside the numbered
  /// catalog range — and hands it here directly.
  Future<Tablero?> generarDesdeDefinicionAsync(
    DefinicionNivelDto definicion,
  ) async {
    _definicion = definicion;
    final ausentes = definicion.ausentes
        .map((j) => Posicion.en(
              fila: j['row'] as int,
              columna: j['col'] as int,
              capa: j['layer'] as int? ?? 0,
            ))
        .toSet();
    final configAjustada = ConfiguracionGeneracion(
      filas: definicion.filas,
      columnas: definicion.columnas,
      profundo: definicion.layers,
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
