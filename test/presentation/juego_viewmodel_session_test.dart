import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/estado_sesion.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// Ticket 04 (DM-F8 guardrail) — the ViewModel maps the session's domain state
/// onto a *separate* UI snapshot. `VictoriaViewState` (presentation) is **not**
/// `EstadoVictoria` (the GoF session state); neither type leaks into the other.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    umbralesEstrellas: [300, 600, 900],
    limiteTiempo: null,
  );

  GrafoTablero tableroDeUnaFlecha() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
      );

  test('should_expose_VictoriaViewState_distinct_from_EstadoVictoria', () {
    // Arrange — a VM whose session shares the use case's single board.
    final tablero = tableroDeUnaFlecha();
    final moverFlecha = MoverFlechaUseCase(tablero);
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: moverFlecha,
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
    expect(viewModel.estado.victoria, isNull);

    // Act — clear the only arrow, emptying the board.
    viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

    // Assert — the domain session is a victory…
    expect(moverFlecha.sesion.estado, isA<EstadoVictoria>());

    // …while the View sees a UI snapshot that is NOT the domain state.
    final VictoriaViewState? victoria = viewModel.estado.victoria;
    expect(victoria, isNotNull);
    expect(victoria, isA<VictoriaViewState>());
    expect(victoria, isNot(isA<EstadoVictoria>()));
    expect(victoria!.movimientos, 1);
  });
}
