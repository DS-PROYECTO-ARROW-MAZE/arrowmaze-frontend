import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/catalogo_niveles.dart';
import '../../core/config/api_config.dart';
import '../../domain/niveles/dificultad.dart';
import '../../domain/niveles/resumen_nivel.dart';

/// HTTP-backed [CatalogoNiveles] (Ticket 17).
///
/// Fetches the level list from `GET /levels`. On any network failure (timeout,
/// non‑200 status, or thrown exception) it falls back to a provided
/// [CatalogoNiveles] (typically [CatalogoNivelesArchivo]) so the UI never
/// crashes and the player sees the bundled levels offline.
class CatalogoNivelesRemoto implements CatalogoNiveles {
  /// Creates the remote catalog.
  ///
  /// If [client] is omitted, a default [http.Client] is created. The
  /// [fallback] is used when the HTTP call fails.
  CatalogoNivelesRemoto({
    http.Client? client,
    required CatalogoNiveles fallback,
  })  : _client = client ?? http.Client(),
        _fallback = fallback;

  final http.Client _client;
  final CatalogoNiveles _fallback;

  @override
  Future<List<ResumenNivel>> listar() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.catalogPath}'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as List<dynamic>;
        final niveles = body
            .map((j) => _desdeJson(j as Map<String, dynamic>))
            .toList();
        niveles.sort((a, b) => a.id.compareTo(b.id));
        return niveles;
      }
    } catch (_) {
      // Network error — fall back.
    }
    return _fallback.listar();
  }

  /// Maps one `GET /levels` item (the backend `NivelResumenDto`) to a
  /// [ResumenNivel].
  ///
  /// The backend contract is `{ id: uuid, numero: int, nombre, dificultad,
  /// … }`: `numero` is the sequential ordinal used everywhere locally, and `id`
  /// is the UUID carried as [ResumenNivel.idRemoto] for sync/leaderboard. (The
  /// previous code read `id` as an int and used `name`/`difficulty`, which threw
  /// on the real UUID payload and silently fell back to the bundled catalog —
  /// the root cause of progress never saving.)
  ResumenNivel _desdeJson(Map<String, dynamic> json) {
    final numero = json['numero'] as int;
    return ResumenNivel(
      id: numero,
      idRemoto: json['id'] as String?,
      nombre: json['nombre'] as String? ?? 'Level $numero',
      dificultad: Dificultad.desde(json['dificultad'] as String?),
    );
  }
}
