import '../application/generadores/generacion_aleatoria_nivel.dart';
import '../application/generadores/generacion_por_archivo_nivel.dart';
import '../application/generadores/generador_nivel_base.dart';
import '../application/ports/cargador_nivel.dart';
import '../application/use_cases/mover_flecha_use_case.dart';
import '../domain/entities/fabrica_celdas_estandar.dart';
import '../domain/grafo_tablero.dart';
import '../domain/tablero.dart';
import '../infrastructure/audio/audio_service_imp.dart';
import '../infrastructure/datasources/cargador_nivel_archivo.dart';
import '../infrastructure/datasources/fuente_tablero_memoria.dart';
import '../presentation/viewmodels/juego_view_model.dart';
import '../presentation/viewmodels/seleccion_nivel_view_model.dart';

/// Composition root: wires domain, application, infrastructure, and presentation
/// into the object graph that the app consumes.
///
/// No business logic lives here — only construction and wiring.
abstract final class Inyeccion {
  /// Builds the [JuegoViewModel] for the active level, wiring the full
  /// Observer chain: [AudioServiceImp] subscribes to the use case's publisher
  /// before the ViewModel is constructed (which also auto-subscribes itself).
  static JuegoViewModel construirJuegoViewModel() {
    const fuente = FuenteTableroMemoria();
    const fabrica = FabricaCeldasEstandar();

    final Tablero tablero = GrafoTablero.desde(
      filas: fuente.filas,
      columnas: fuente.columnas,
      trayectorias:
          fuente.cargarTrayectorias().map(fabrica.crearTrayectoria).toList(),
      celdas: fuente.cargarParedes().map(fabrica.crear).toList(),
    );

    final moverFlecha = MoverFlechaUseCase(tablero);

    // Register infrastructure observers before the ViewModel so the full
    // observer chain is in place when the first tap arrives.
    moverFlecha.publicador.suscribir(AudioServiceImp.instance);

    return JuegoViewModel(tablero: tablero, moverFlecha: moverFlecha);
  }

  static GeneradorNivelBase get generadorAleatorio =>
      const GeneracionAleatoriaNivel();

  static CargadorNivel get cargadorNivelArchivo =>
      const CargadorNivelArchivo();

  static GeneracionPorArchivoNivel get generadorPorArchivo =>
      GeneracionPorArchivoNivel(cargador: cargadorNivelArchivo);

  static SeleccionNivelViewModel construirSeleccionNivelViewModel() {
    return SeleccionNivelViewModel(
      generadorArchivo: generadorPorArchivo,
    );
  }
}
