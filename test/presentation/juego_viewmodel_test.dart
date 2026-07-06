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

/// Verifies the MVVM binding: a tap on the VM runs the use case and publishes a
/// *new immutable* [JuegoViewState] (via `copyWith`) with the whole path now
/// empty, notifying listeners exactly once. Also checks the snapshot carries the
/// path geometry (corner connections, head) the painter needs.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,

    limiteTiempo: null,
  );

  GrafoTablero construirTablero() {
    // 3x3 with an L-shaped path: (2,1)->(1,1)->(1,0), head (1,0) exits left.
    return GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.izquierda,
          segmentos: const [
            Posicion.en(fila: 2, columna: 1),
            Posicion.en(fila: 1, columna: 1),
            Posicion.en(fila: 1, columna: 0),
          ],
        ),
      ],
    );
  }

  test('should_expose_path_geometry_in_the_initial_snapshot', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Assert — the bend at (1,1) is a corner; (1,0) is the head exiting left.
    final esquina =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 1));
    expect(esquina.tipo, TipoCeldaUI.flecha);
    expect(esquina.conexiones, {Direccion.abajo, Direccion.izquierda});

    final cabeza =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 0));
    expect(cabeza.esCabeza, isTrue);
    expect(cabeza.direccion, Direccion.izquierda);
  });

  test('should_expose_new_JuegoViewState_with_emptied_path_when_move_valid', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
    final JuegoViewState estadoInicial = viewModel.estado;
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    // Tap any segment of the path — the whole arrow should resolve.
    const tap = Posicion.en(fila: 2, columna: 1);
    expect(estadoInicial.tablero.celdaEn(tap).tipo, TipoCeldaUI.flecha);

    // Act
    viewModel.tocar(tap);

    // Assert — a brand new immutable state instance was published.
    expect(identical(viewModel.estado, estadoInicial), isFalse);
    final tablero2 = viewModel.estado.tablero;
    for (final p in const [
      Posicion.en(fila: 2, columna: 1),
      Posicion.en(fila: 1, columna: 1),
      Posicion.en(fila: 1, columna: 0),
    ]) {
      expect(tablero2.celdaEn(p).tipo, TipoCeldaUI.vacia);
    }
    expect(viewModel.estado.movimientos, 1);
    expect(notificaciones, 1);
  });

  test(
    'should_emit_exit_animation_descriptor_with_ordered_path_when_move_valid',
    () {
      // Arrange
      final tablero = construirTablero();
      final viewModel = JuegoViewModel(
        tablero: tablero,
        moverFlecha: MoverFlechaUseCase(tablero),
        definicionNivel: definicion,
        reloj: _RelojNulo(),
      );

      // Act — resolve the L-shaped path (head (1,0) exits left).
      viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

      // Assert — the transient descriptor carries the exiting cells in order
      // (tail → head), the exit direction and an off-board edge target so the
      // View can play the snake gait (AC1).
      final salida = viewModel.estado.animacionSalida;
      expect(salida, isNotNull);
      expect(salida!.idFlecha, 1);
      expect(salida.segmentos, const [
        Posicion.en(fila: 2, columna: 1),
        Posicion.en(fila: 1, columna: 1),
        Posicion.en(fila: 1, columna: 0),
      ]);
      expect(salida.direccionSalida, Direccion.izquierda);
      // Head at (1,0) exiting left ⇒ the edge target is off-board at column -1.
      expect(salida.objetivoBorde, const Posicion.en(fila: 1, columna: -1));

      // And it is transient: a later state (any other notification) clears it so
      // a finished animation never leaks into later frames (AC3, refactor note).
      viewModel.toggleMute();
      expect(viewModel.estado.animacionSalida, isNull);
    },
  );

  test('should_not_emit_exit_descriptor_when_move_invalid', () {
    // Arrange — a path whose head is boxed in by a wall so its ray is blocked.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 2)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.abajo,
          segmentos: const [Posicion.en(fila: 1, columna: 2)],
        ),
      ],
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Act — tap the arrow at (2,2): its upward ray is blocked by the arrow at
    // (1,2), so the move is penalized/invalid.
    viewModel.tocar(const Posicion.en(fila: 2, columna: 2));

    // Assert — an invalid move never emits an exit descriptor (AC3).
    expect(viewModel.estado.movimientoInvalido, isTrue);
    expect(viewModel.estado.animacionSalida, isNull);
  });

  test('should_mark_absent_positions_as_non_playable_in_view_state', () {
    // Arrange — a shaped 2×2 board with one absent corner (outside the shape).
    final tablero = GrafoTablero.desde(
      filas: 2,
      columnas: 2,
      ausentes: {const Posicion.en(fila: 0, columna: 1)},
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    // Assert — the masked board flags the absent corner as non-playable, while
    // an in-shape cell stays playable (AC1). No UI-side re-derivation: the flag
    // comes straight from the model's `CeldaAusente`.
    final ausente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 1));
    expect(ausente.tipo, TipoCeldaUI.ausente);
    expect(ausente.esJugable, isFalse);

    final presente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 0));
    expect(presente.esJugable, isTrue);
  });

  test('should_distinguish_absent_from_empty_cell_in_view_state', () {
    // Arrange — (0,1) is absent; every other cell is present empty space.
    final tablero = GrafoTablero.desde(
      filas: 2,
      columnas: 2,
      ausentes: {const Posicion.en(fila: 0, columna: 1)},
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );

    final ausente = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 1));
    final vacia = viewModel.estado.tablero
        .celdaEn(const Posicion.en(fila: 0, columna: 0));

    // Assert — absent ≠ empty: distinct kinds and distinct playability, so the
    // painter draws a dot for the empty cell but nothing for the absent one, and
    // only the empty cell is a hit-test target (AC2).
    expect(ausente.tipo, TipoCeldaUI.ausente);
    expect(vacia.tipo, TipoCeldaUI.vacia);
    expect(ausente.esJugable, isFalse);
    expect(vacia.esJugable, isTrue);
  });
}
