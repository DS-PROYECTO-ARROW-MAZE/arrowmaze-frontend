import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/application/ports/consulta_progreso_local.dart';
import 'package:arrowmaze/application/ports/i_consulta_progreso_remoto.dart';
import 'package:arrowmaze/application/ports/progreso_remoto_item.dart';
import 'package:arrowmaze/application/use_cases/restaurar_progreso_use_case.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/resumen_nivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 24 — RestaurarProgresoUseCase hydrates local progression from server
/// data (GET /progress) on login, merging with the best-per-level policy.
void main() {
  group('RestaurarProgresoUseCase', () {
    test('should_hydrate_local_progress_from_remote_when_login_succeeds', () async {
      // Arrange
      final local = _ProgresoLocalSpy();
      final remote = _ProgresoRemotoFake(items: const [
        ProgresoRemotoItem(nivelId: 'uuid-1', estrellas: 2, puntaje: 600),
        ProgresoRemotoItem(nivelId: 'uuid-3', estrellas: 3, puntaje: 900),
      ]);
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
        ResumenNivel(id: 2, nombre: 'B', dificultad: Dificultad.medio, idRemoto: 'uuid-2'),
        ResumenNivel(id: 3, nombre: 'C', dificultad: Dificultad.dificil, idRemoto: 'uuid-3'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: remote,
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act
      await useCase.ejecutar();

      // Assert — only levels with a remote record are registered locally.
      expect(local.registros, hasLength(2));
      expect(local.registros[1], 2);
      expect(local.registros[3], 3);
    });

    test('should_keep_best_per_level_when_merging_remote_and_local', () async {
      // Arrange — local has a better run on level 1 (3 stars vs remote 2).
      // Remote has a better run on level 3 (3 stars vs local 1).
      final local = _ProgresoLocalSpy(
        pre: {1: 3, 3: 1}, // level 1: 3★ locally; level 3: 1★ locally
      );
      final remote = _ProgresoRemotoFake(items: const [
        ProgresoRemotoItem(nivelId: 'uuid-1', estrellas: 2, puntaje: 500),
        ProgresoRemotoItem(nivelId: 'uuid-3', estrellas: 3, puntaje: 950),
      ]);
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
        ResumenNivel(id: 3, nombre: 'C', dificultad: Dificultad.dificil, idRemoto: 'uuid-3'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: remote,
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act
      await useCase.ejecutar();

      // Assert — the best is kept per level.
      // Level 1: local 3 > remote 2 → keep 3.
      expect(local.registros[1], 3);
      // Level 3: remote 3 > local 1 → keep 3.
      expect(local.registros[3], 3);
    });

    test('should_noop_local_state_when_remote_read_fails', () async {
      // Arrange — remote always fails.
      final local = _ProgresoLocalSpy();
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: _ProgresoRemotoQueFalla(),
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act — should not throw.
      await useCase.ejecutar();

      // Assert — nothing was written; degraded gracefully.
      expect(local.registros, isEmpty);
    });

    test('should_skip_items_when_uuid_is_unmapped', () async {
      // Arrange — a remote item references a UUID not in the catalog.
      final local = _ProgresoLocalSpy();
      final remote = _ProgresoRemotoFake(items: const [
        ProgresoRemotoItem(nivelId: 'uuid-unknown', estrellas: 3, puntaje: 900),
        ProgresoRemotoItem(nivelId: 'uuid-1', estrellas: 2, puntaje: 600),
      ]);
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: remote,
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act
      await useCase.ejecutar();

      // Assert — unmapped UUID is silently skipped; known level is restored.
      expect(local.registros, hasLength(1));
      expect(local.registros[1], 2);
    });

    test('should_be_idempotent_when_called_twice', () async {
      // Arrange
      final local = _ProgresoLocalSpy();
      final remote = _ProgresoRemotoFake(items: const [
        ProgresoRemotoItem(nivelId: 'uuid-1', estrellas: 2, puntaje: 600),
      ]);
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: remote,
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act — call twice.
      await useCase.ejecutar();
      await useCase.ejecutar();

      // Assert — only one registrations per level; no duplicates.
      expect(local.registros[1], 2);
      expect(local.llamadasRegistro, 2); // both calls hit, but merge kept best
    });

    test('should_not_restore_when_remote_returns_empty_list', () async {
      // Arrange
      final local = _ProgresoLocalSpy(pre: {1: 2});
      final remote = _ProgresoRemotoFake(items: const []);
      final catalogo = _CatalogoFake(const [
        ResumenNivel(id: 1, nombre: 'A', dificultad: Dificultad.facil, idRemoto: 'uuid-1'),
      ]);
      final useCase = RestaurarProgresoUseCase(
        consultaRemoto: remote,
        progresoLocal: local,
        catalogo: catalogo,
      );

      // Act
      await useCase.ejecutar();

      // Assert — local state untouched (no remote items to merge).
      expect(local.registros, hasLength(1));
      expect(local.registros[1], 2);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _CatalogoFake implements CatalogoNiveles {
  _CatalogoFake(this._niveles);

  final List<ResumenNivel> _niveles;

  @override
  Future<List<ResumenNivel>> listar() async => _niveles;

  @override
  Future<int> obtenerCantidadTotal() async => _niveles.length;

  @override
  Future<ResumenNivel> obtenerPorIndice(int indice) async =>
      _niveles.firstWhere((r) => r.id == indice);
}

class _ProgresoRemotoFake implements IConsultaProgresoRemoto {
  const _ProgresoRemotoFake({this.items = const []});

  final List<ProgresoRemotoItem> items;

  @override
  Future<List<ProgresoRemotoItem>> obtenerProgreso() async => items;
}

class _ProgresoRemotoQueFalla implements IConsultaProgresoRemoto {
  @override
  Future<List<ProgresoRemotoItem>> obtenerProgreso() async =>
      throw Exception('Network error');
}

class _ProgresoLocalSpy implements ConsultaProgresoLocal {
  _ProgresoLocalSpy({Map<int, int>? pre}) {
    if (pre != null) {
      _registros = Map<int, int>.from(pre);
    }
  }

  Map<int, int> _registros = {};
  int _llamadasRegistro = 0;

  Map<int, int> get registros => _registros;
  int get llamadasRegistro => _llamadasRegistro;

  @override
  Future<Set<int>> nivelesCompletados() async => _registros.keys.toSet();

  @override
  Future<int> mejorEstrellas(int idNivel) async => _registros[idNivel] ?? 0;

  @override
  Future<void> registrarCompletado({
    required int idNivel,
    required int estrellas,
  }) async {
    _llamadasRegistro++;
    final actual = _registros[idNivel] ?? -1;
    if (estrellas > actual) {
      _registros[idNivel] = estrellas;
    }
  }

  @override
  Future<void> limpiar() async {
    _registros = {};
  }
}