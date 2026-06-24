import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../../application/ports/catalogo_niveles.dart';
import '../../domain/niveles/dificultad.dart';
import '../../domain/niveles/resumen_nivel.dart';

/// Asset-backed [CatalogoNiveles] (Ticket 13, DM §10.2).
///
/// Enumerates the bundled `assets/levels/level_*.json` files through the Flutter
/// [AssetManifest] and reads each file's `id` / `name` / `difficulty` header
/// into a [ResumenNivel]. Parallels [CargadorNivelArchivo], which loads the full
/// board for a chosen level. Results are ordered by id ascending.
class CatalogoNivelesArchivo implements CatalogoNiveles {
  /// Creates the catalog over [basePath] (the bundled levels folder).
  const CatalogoNivelesArchivo({String basePath = 'assets/levels'})
      : _basePath = basePath;

  final String _basePath;

  @override
  Future<List<ResumenNivel>> listar() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final rutas = manifest
        .listAssets()
        .where((r) => r.startsWith('$_basePath/level_') && r.endsWith('.json'))
        .toList();

    final resumenes = <ResumenNivel>[];
    for (final ruta in rutas) {
      final jsonStr = await rootBundle.loadString(ruta);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final id = json['id'] as int;
      resumenes.add(
        ResumenNivel(
          id: id,
          nombre: json['name'] as String? ?? 'Level $id',
          dificultad: Dificultad.desde(json['difficulty'] as String?),
        ),
      );
    }

    resumenes.sort((a, b) => a.id.compareTo(b.id));
    return resumenes;
  }
}
