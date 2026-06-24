import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/ports/proveedor_sesion.dart';
import 'package:arrowmaze/application/use_cases/cerrar_sesion_use_case.dart';
import 'package:arrowmaze/application/use_cases/limpiar_progreso_local_use_case.dart';
import 'package:arrowmaze/domain/progreso/i_cola_sincronizacion.dart';
import 'package:arrowmaze/domain/progreso/run_completado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 20 — CerrarSesionUseCase delegates to ProveedorSesion.cerrarSesion().
void main() {
  group('CerrarSesionUseCase (Issue 20)', () {
    test('should_clear_session_when_logout', () async {
      // Arrange — a fake session that starts with a stored token.
      final sesion = _ProveedorSesionFake();
      sesion.guardado = 'tok-abc';
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — token is cleared.
      final token = await sesion.obtenerToken();
      expect(token, isNull);
    });

    test('should_wipe_local_progress_when_logout', () async {
      // Arrange — a session plus device-local progression that must not leak
      // into the next account.
      final sesion = _ProveedorSesionFake()..guardado = 'tok-abc';
      final progreso = _ProgresoLocalFake()..completados = {1, 2, 3};
      final cola = _ColaFake()..pendientes = 2;
      final useCase = CerrarSesionUseCase(
        proveedorSesion: sesion,
        limpiarProgresoLocal: LimpiarProgresoLocalUseCase(
          progreso: progreso,
          cola: cola,
        ),
      );

      // Act
      await useCase.ejecutar();

      // Assert — token cleared AND local progress + sync queue wiped.
      expect(await sesion.obtenerToken(), isNull);
      expect(progreso.limpiado, isTrue);
      expect(progreso.completados, isEmpty);
      expect(cola.vaciado, isTrue);
    });

    test('should_remain_cleared_when_already_logged_out', () async {
      // Arrange — no token exists.
      final sesion = _ProveedorSesionFake();
      final useCase = CerrarSesionUseCase(proveedorSesion: sesion);

      // Act
      await useCase.ejecutar();

      // Assert — no error thrown; still null.
      final token = await sesion.obtenerToken();
      expect(token, isNull);
    });
  });
}

/// A fake [ProveedorSesion] for use-case tests.
class _ProveedorSesionFake implements ProveedorSesion {
  String? guardado;

  @override
  Future<String?> obtenerToken() async => guardado;

  @override
  Future<void> guardarToken(String token) async {
    guardado = token;
  }

  @override
  Future<void> cerrarSesion() async {
    guardado = null;
  }
}

/// A fake [ConsultaProgresoLocal] that records whether it was wiped.
class _ProgresoLocalFake implements ConsultaProgresoLocal {
  Set<int> completados = {};
  bool limpiado = false;

  @override
  Future<Set<int>> nivelesCompletados() async => completados;

  @override
  Future<int> mejorEstrellas(int idNivel) async => 0;

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {}

  @override
  Future<void> limpiar() async {
    limpiado = true;
    completados = {};
  }
}

/// A fake [IColaSincronizacion] that records whether it was emptied.
class _ColaFake implements IColaSincronizacion {
  int pendientes = 0;
  bool vaciado = false;

  @override
  Future<void> encolar(RunCompletado run) async => pendientes++;

  @override
  Future<List<RunCompletado>> obtenerPendientes() async => const [];

  @override
  Future<int> cantidadPendientes() async => pendientes;

  @override
  Future<void> vaciar() async {
    vaciado = true;
    pendientes = 0;
  }
}
