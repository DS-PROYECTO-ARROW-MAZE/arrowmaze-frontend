import '../application/use_cases/mover_flecha_use_case.dart';
import '../domain/entities/fabrica_celdas_estandar.dart';
import '../domain/grafo_tablero.dart';
import '../domain/tablero.dart';
import '../infrastructure/datasources/fuente_tablero_memoria.dart';
import '../presentation/viewmodels/juego_view_model.dart';

/// Composition root for the move-mechanic slice.
///
/// This is the one place an infrastructure adapter ([FuenteTableroMemoria]) is
/// chosen and wired to the domain ([GrafoTablero]) and the use case, then handed
/// to the [JuegoViewModel]. Every consumer above this line depends on the
/// [Tablero] port only (DIP), so swapping the in-memory source for a real level
/// loader later changes nothing but this function.
abstract final class Inyeccion {
  /// Builds a ready-to-use [JuegoViewModel] for the demo board.
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

    return JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
    );
  }
}
