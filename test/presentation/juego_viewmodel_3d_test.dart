import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
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

/// Ticket 36 — the ViewModel's `TableroUI` snapshot holds every cell of every
/// depth layer at once (the rotatable 3D cube renders the whole board, not
/// one layer at a time), and tap-any-segment resolution is driven purely by
/// the tapped segment's `idFlecha` — unchanged `MoverFlechaUseCase` behaviour,
/// regardless of which layer the head sits on.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    limiteTiempo: null,
  );

  /// Mirrors `level_3d_test_02` — 1x2 footprint, 2 layers, a path bending
  /// in-plane on layer 0 then through depth to a head on layer 1.
  GrafoTablero construirTablero() {
    return GrafoTablero.desde(
      filas: 1,
      columnas: 2,
      profundo: 2,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.adelante,
          segmentos: const [
            Posicion.en(fila: 0, columna: 0, capa: 0),
            Posicion.en(fila: 0, columna: 1, capa: 0),
            Posicion.en(fila: 0, columna: 1, capa: 1),
          ],
        ),
      ],
    );
  }

  JuegoViewModel construirViewModel(GrafoTablero tablero) => JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
      );

  test('should_expose_profundo_on_the_board_snapshot', () {
    // Arrange / Act
    final viewModel = construirViewModel(construirTablero());

    // Assert
    expect(viewModel.estado.tablero.profundo, 2);
  });

  test('should_render_every_layer_cell_in_a_single_snapshot', () {
    // Arrange / Act
    final viewModel = construirViewModel(construirTablero());
    final tablero = viewModel.estado.tablero;

    // Assert — the whole cube is present in one snapshot: layer 0's tail and
    // bend, and layer 1's head, all queryable at once (no "active layer").
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 0)).tipo,
      TipoCeldaUI.flecha,
    );
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 1, capa: 0)).tipo,
      TipoCeldaUI.flecha,
    );
    final cabeza =
        tablero.celdaEn(const Posicion.en(fila: 0, columna: 1, capa: 1));
    expect(cabeza.tipo, TipoCeldaUI.flecha);
    expect(cabeza.esCabeza, isTrue);
    // (0,0,capa:1) is empty — no arrow segment there.
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 1)).tipo,
      TipoCeldaUI.vacia,
    );
  });

  test(
      'should_resolve_owning_path_when_tapped_segment_head_is_on_a_different_layer',
      () {
    // Arrange — tap the tail on layer 0; the head sits on layer 1.
    final viewModel = construirViewModel(construirTablero());
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    // Act
    viewModel.tocar(const Posicion.en(fila: 0, columna: 0, capa: 0));

    // Assert — the whole path resolved: every layer it occupied is now empty.
    final tablero = viewModel.estado.tablero;
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 0)).tipo,
      TipoCeldaUI.vacia,
    );
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 1, capa: 0)).tipo,
      TipoCeldaUI.vacia,
    );
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 1, capa: 1)).tipo,
      TipoCeldaUI.vacia,
    );
    expect(viewModel.estado.movimientos, 1);
    expect(notificaciones, 1);
  });

  test(
      'should_compute_a_depth_edge_target_when_exit_animation_travels_through_capa',
      () {
    // Regression — a head exiting along adelante/atras only ever changes
    // `capa`, never fila/columna; the off-board edge target must still be
    // computed by walking depth bounds, not row/column bounds (otherwise the
    // walk never leaves the 2D bounding box and never terminates).
    final viewModel = construirViewModel(construirTablero());

    viewModel.tocar(const Posicion.en(fila: 0, columna: 0, capa: 0));

    final salida = viewModel.estado.animacionSalida;
    expect(salida, isNotNull);
    expect(salida!.direccionSalida, Direccion.adelante);
    // Head at (0,1,capa:1) exiting adelante ⇒ edge target one layer past the
    // 2-layer stack, same fila/columna.
    expect(salida.objetivoBorde,
        const Posicion.en(fila: 0, columna: 1, capa: 2));
  });
}
