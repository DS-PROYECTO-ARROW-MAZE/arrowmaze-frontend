import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports/catalogo_niveles.dart';
import '../../core/config/api_config.dart';
import '../../domain/niveles/dificultad.dart';
import '../../domain/niveles/resumen_nivel.dart';

/// HTTP-backed [CatalogoNiveles] (Ticket 17).
///
/// Fetches the level list from `GET /levels`. On any network failure (timeout,
/// non‑200 status, or thrown exception) it falls back entirely to a provided
/// [CatalogoNiveles] (typically [CatalogoNivelesArchivo]) so the UI never
/// crashes and the player sees the bundled levels offline.
///
/// When the backend **is** reachable, its response still isn't the whole
/// story: a level authored locally and not yet known to the backend (ticket
/// 36's 3D boards, for instance) would otherwise vanish the moment a backend
/// is running, even though the bundled asset is right there. So a successful
/// response is *merged* with [fallback] — the backend wins for every id it
/// knows (real UUID, live progress sync), and any bundled id it doesn't know
/// is appended as a local-only, offline-only entry (Ticket 36).
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
        final remotos = body
            .map((j) => _desdeJson(j as Map<String, dynamic>))
            .toList();
        return _fusionarConLocales(remotos);
      }
    } catch (_) {
      // Network error — fall back entirely to the bundle.
    }
    return _fallback.listar();
  }

  /// Merges [remotos] with [_fallback]'s bundled catalog: every remote entry
  /// is kept as-is (it owns the real [ResumenNivel.idRemoto]), and any
  /// bundled id the backend didn't return is appended, offline-only. Ordered
  /// by id ascending either way.
  Future<List<ResumenNivel>> _fusionarConLocales(
    List<ResumenNivel> remotos,
  ) async {
    final idsRemotos = remotos.map((n) => n.id).toSet();
    final locales = await _fallback.listar();
    final soloLocales = locales.where((n) => !idsRemotos.contains(n.id));

    final combinados = [...remotos, ...soloLocales];
    combinados.sort((a, b) => a.id.compareTo(b.id));
    return combinados;
  }

  @override
  Future<int> obtenerCantidadTotal() async {
    final niveles = await listar();
    return niveles.length;
  }

  @override
  Future<ResumenNivel> obtenerPorIndice(int indice) async {
    final niveles = await listar();
    if (indice <= niveles.length) {
      return niveles.firstWhere((r) => r.id == indice);
    }
    return _fallback.obtenerPorIndice(indice);
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
