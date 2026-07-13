import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_por_archivo_nivel.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/datasources/cargador_nivel_archivo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 — the three 3D boards are now real, numbered catalog levels
/// (16/17/18), loaded through the exact same production path as any other
/// bundled level ([CargadorNivelArchivo.cargar] by numbered id) — no more
/// QA-only filename entry point.

/// Counts distinct arrow paths on [tablero] by scanning every
/// `(fila, columna, capa)` position — the 3D-aware sibling of
/// `Inyeccion._contarFlechas`.
int _contarFlechas(Tablero tablero) {
  final ids = <int>{};
  for (var f = 0; f < tablero.filas; f++) {
    for (var c = 0; c < tablero.columnas; c++) {
      for (var p = 0; p < tablero.profundo; p++) {
        final celda = tablero.celdaEn(Posicion.en(fila: f, columna: c, capa: p));
        if (celda is CeldaFlecha) ids.add(celda.idFlecha);
      }
    }
  }
  return ids.length;
}

/// Counts arrows whose head ray is blocked in the **initial** board — a
/// genuine release-order dependency, not just a claim of solvability. A
/// board with zero of these is trivially solvable in any order.
int _contarBloqueadosInicialmente(Tablero tablero) {
  final vistos = <int>{};
  var bloqueados = 0;
  for (var f = 0; f < tablero.filas; f++) {
    for (var c = 0; c < tablero.columnas; c++) {
      for (var p = 0; p < tablero.profundo; p++) {
        final pos = Posicion.en(fila: f, columna: c, capa: p);
        final t = tablero.trayectoriaEn(pos);
        if (t == null || !vistos.add(t.id)) continue;
        final rayo = tablero.raycast(t.cabeza, t.direccionCabeza);
        if (!rayo.despejadoHastaBorde) bloqueados++;
      }
    }
  }
  return bloqueados;
}

/// Whether every present (non-absent) cell is part of some arrow — full
/// density, no transparent gaps left within the shape.
bool _totalmenteLleno(Tablero tablero) {
  for (var f = 0; f < tablero.filas; f++) {
    for (var c = 0; c < tablero.columnas; c++) {
      for (var p = 0; p < tablero.profundo; p++) {
        final celda =
            tablero.celdaEn(Posicion.en(fila: f, columna: c, capa: p));
        if (celda is CeldaVacia) return false;
      }
    }
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Tablero?> cargar(int idNivel) async {
    final generador =
        GeneracionPorArchivoNivel(cargador: const CargadorNivelArchivo());
    return generador.generarAsync(
      const ConfiguracionGeneracion(filas: 0, columnas: 0),
      idNivel: idNivel,
    );
  }

  test(
      'should_load_level_16_as_a_fully_dense_interlocking_seven_arrow_cube',
      () async {
    final tablero = await cargar(16);
    expect(tablero, isNotNull, reason: 'level 16 must load and be solvable');
    expect(tablero!.profundo, 3);
    expect(_contarFlechas(tablero), 7);
    // Fills every cell of the shape — no empty gaps left over.
    expect(_totalmenteLleno(tablero), isTrue);
    // Genuinely interlocking: some arrows are blocked until others clear
    // first, so there is a real release sequence, not a free-for-all.
    expect(_contarBloqueadosInicialmente(tablero), greaterThanOrEqualTo(2));
  });

  test(
      'should_load_level_17_as_a_fully_dense_interlocking_ten_arrow_pyramid',
      () async {
    final tablero = await cargar(17);
    expect(tablero, isNotNull, reason: 'level 17 must load and be solvable');
    expect(tablero!.profundo, 3);
    expect(_contarFlechas(tablero), 10);
    expect(_totalmenteLleno(tablero), isTrue);
    expect(_contarBloqueadosInicialmente(tablero), greaterThanOrEqualTo(2));
  });

  test(
      'should_load_level_18_as_a_fully_dense_interlocking_twelve_arrow_prism',
      () async {
    final tablero = await cargar(18);
    expect(tablero, isNotNull, reason: 'level 18 must load and be solvable');
    expect(tablero!.profundo, 2);
    expect(_contarFlechas(tablero), 12);
    expect(_totalmenteLleno(tablero), isTrue);
    expect(_contarBloqueadosInicialmente(tablero), greaterThanOrEqualTo(2));
  });
}
