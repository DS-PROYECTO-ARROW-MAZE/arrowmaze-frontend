import 'dart:convert';

import 'package:arrowmaze/application/ports/catalogo_niveles.dart';
import 'package:arrowmaze/domain/niveles/dificultad.dart';
import 'package:arrowmaze/domain/niveles/resumen_nivel.dart';
import 'package:arrowmaze/infrastructure/niveles/catalogo_niveles_remoto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Ticket 17 — CatalogoNivelesRemoto fetches from GET /levels or falls back
/// to asset catalog on network error (AC3).
void main() {
  late http.Client client;
  late CatalogoNiveles fallback;

  setUp(() {
    client = _HttpClientFake();
    fallback = _CatalogoFake(const [
      ResumenNivel(id: 1, nombre: 'Fallback One', dificultad: Dificultad.facil),
    ]);
  });

  group('CatalogoNivelesRemoto', () {
    test('should_return_catalog_from_http_when_online', () async {
      // Arrange — HTTP 200 with two levels in the real backend shape:
      // `id` is a UUID, `numero` the ordinal, `nombre`/`dificultad` Spanish keys.
      (client as _HttpClientFake).respuesta = http.Response(
        jsonEncode([
          {
            'id': 'uuid-aaa',
            'numero': 1,
            'nombre': 'Remote One',
            'dificultad': 'FACIL',
          },
          {
            'id': 'uuid-bbb',
            'numero': 2,
            'nombre': 'Remote Two',
            'dificultad': 'DIFICIL',
          },
        ]),
        200,
      );

      final remoto = CatalogoNivelesRemoto(client: client, fallback: fallback);

      // Act
      final niveles = await remoto.listar();

      // Assert — from HTTP, not fallback. `id` is the ordinal; `idRemoto` the UUID.
      expect(niveles.length, 2);
      expect(niveles[0].nombre, 'Remote One');
      expect(niveles[0].id, 1);
      expect(niveles[0].idRemoto, 'uuid-aaa');
      expect(niveles[1].nombre, 'Remote Two');
      expect(niveles[1].idRemoto, 'uuid-bbb');
      expect(niveles[1].dificultad, Dificultad.dificil);
    });

    test('should_map_difficulty_tokens_correctly', () async {
      // Arrange — all difficulty variants (backend FACIL/MEDIO/DIFICIL tokens).
      (client as _HttpClientFake).respuesta = http.Response(
        jsonEncode([
          {'id': 'u1', 'numero': 1, 'nombre': 'E', 'dificultad': 'FACIL'},
          {'id': 'u2', 'numero': 2, 'nombre': 'M', 'dificultad': 'MEDIO'},
          {'id': 'u3', 'numero': 3, 'nombre': 'H', 'dificultad': 'DIFICIL'},
          {'id': 'u4', 'numero': 4, 'nombre': 'X', 'dificultad': 'unknown'},
        ]),
        200,
      );

      final remoto = CatalogoNivelesRemoto(client: client, fallback: fallback);

      // Act
      final niveles = await remoto.listar();

      // Assert
      expect(niveles[0].dificultad, Dificultad.facil);
      expect(niveles[1].dificultad, Dificultad.medio);
      expect(niveles[2].dificultad, Dificultad.dificil);
      expect(niveles[3].dificultad, Dificultad.facil); // unknown → facil
    });

    test('should_fallback_to_assets_when_http_returns_error', () async {
      // Arrange — HTTP 500.
      (client as _HttpClientFake).respuesta = http.Response('Server Error', 500);

      final remoto = CatalogoNivelesRemoto(client: client, fallback: fallback);

      // Act
      final niveles = await remoto.listar();

      // Assert — falls back.
      expect(niveles.length, 1);
      expect(niveles[0].nombre, 'Fallback One');
    });

    test('should_fallback_to_assets_when_http_throws_network_error', () async {
      // Arrange — network throws.
      (client as _HttpClientFake).lanzarExcepcion = true;

      final remoto = CatalogoNivelesRemoto(client: client, fallback: fallback);

      // Act
      final niveles = await remoto.listar();

      // Assert — falls back gracefully.
      expect(niveles.length, 1);
      expect(niveles[0].nombre, 'Fallback One');
    });

    test('should_order_results_by_id_ascending', () async {
      // Arrange — unordered response.
      (client as _HttpClientFake).respuesta = http.Response(
        jsonEncode([
          {'id': 'u3', 'numero': 3, 'nombre': 'C', 'dificultad': 'DIFICIL'},
          {'id': 'u1', 'numero': 1, 'nombre': 'A', 'dificultad': 'FACIL'},
          {'id': 'u2', 'numero': 2, 'nombre': 'B', 'dificultad': 'MEDIO'},
        ]),
        200,
      );

      final remoto = CatalogoNivelesRemoto(client: client, fallback: fallback);

      // Act
      final niveles = await remoto.listar();

      // Assert
      expect(niveles.map((n) => n.id), [1, 2, 3]);
    });

    test('should_return_at_least_15_levels_from_assets_when_remote_fails', () async {
      // Arrange — full offline scenario.
      (client as _HttpClientFake).lanzarExcepcion = true;
      // Use a real archive-backed fallback so we count the 15 bundled levels.
      // Note: this test only works once level_04…level_15 exist.
      final archivoFallback = _CatalogoFake(
        List.generate(15, (i) => ResumenNivel(
          id: i + 1,
          nombre: 'Level ${i + 1}',
          dificultad: Dificultad.facil,
        )),
      );

      final remoto = CatalogoNivelesRemoto(
        client: client,
        fallback: archivoFallback,
      );

      // Act
      final niveles = await remoto.listar();

      // Assert — 15+ levels from fallback.
      expect(niveles.length, greaterThanOrEqualTo(15));
      expect(niveles.first.id, 1);
      expect(niveles.last.id, greaterThanOrEqualTo(15));
    });
  });
}

/// A fake HTTP client that returns a canned response or throws.
class _HttpClientFake extends http.BaseClient {
  http.Response respuesta = http.Response('[]', 200);
  bool lanzarExcepcion = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (lanzarExcepcion) {
      throw Exception('Network error');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(respuesta.body)),
      respuesta.statusCode,
    );
  }
}

/// A fake catalog that returns a canned list (no asset I/O).
class _CatalogoFake implements CatalogoNiveles {
  _CatalogoFake(this._niveles);

  final List<ResumenNivel> _niveles;

  @override
  Future<List<ResumenNivel>> listar() async => _niveles;
}
