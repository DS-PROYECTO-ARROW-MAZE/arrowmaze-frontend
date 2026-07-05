import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// DM-F8 — the ViewModel maps the collected-bonus count onto the HUD snapshot
/// (`JuegoViewState`), without leaking the domain `Coleccionable` into the View.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,

    limiteTiempo: null,
  );
  /// A 3×3 board: an arrow at (2,1) pointing up with a collectible on its ray.
  GrafoTablero tableroConColeccionable() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
        celdas: const [Coleccionable(Posicion.en(fila: 1, columna: 1))],
      );

  test('should_reflect_collected_bonus_in_hud_when_valid_move_crosses_collectible',
      () {
    // Arrange
    final tablero = tableroConColeccionable();
    final moverFlecha = MoverFlechaUseCase(tablero);
    final viewModel = JuegoViewModel(tablero: tablero, moverFlecha: moverFlecha, definicionNivel: definicion, reloj: _RelojNulo());
    expect(viewModel.estado.coleccionables, 0);

    // Act — clear the arrow; its ray flies over the collectible.
    viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

    // Assert — the HUD snapshot counts the collected bonus.
    expect(viewModel.estado.coleccionables, 1);

    viewModel.dispose();
  });
}
