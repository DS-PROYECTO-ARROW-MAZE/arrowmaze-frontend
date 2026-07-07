// ignore_for_file: avoid_print
//
// Authoring tool — generates the 15 bundled puzzle levels into
// `assets/levels/level_XX.json`.
//
// Why a tool and not a hand-authored file: the frontend already owns a proven,
// deterministic, *solvable-by-construction* interlocking maze generator
// ([GeneracionAleatoriaNivel]). Re-using it guarantees every bundled level is a
// real, interlocking puzzle whose arrows genuinely block each other — not a
// static grid. Each level is seeded by its `numero`, so layouts are unique per
// level and reproducible across runs (re-running this tool is idempotent).
//
// Ticket 31 retrofits ticket 23's shape rotation and the raised 7×7 grid floor
// onto the authored catalog. The pure generation core lives in
// `generador_catalogo.dart` (Flutter-free, unit-tested); this file only
// orchestrates the file IO around it:
//   • shape per level follows RepertorioFormas (level 1 → Cuadrado, 2 → Corazón,
//     3 → Triángulo, 4 → Cruz, 5 → Estrella, 6 → Cuadrado … continuous into the
//     endless tail);
//   • difficulty bands are raised to the 7×7 floor — 1–5 → 7×7, 6–10 → 8×8,
//     11–15 → 9×9;
//   • shaped boards are sparse — absent positions are omitted from `cells`.
//
// Run from the frontend package root:
//   dart run tool/generar_niveles.dart
//
// Each level is round-trip verified (solvable, arrow-length ≥ 2, correct shape)
// inside `generarNivelJson` before it is written, so a written file is provably
// loadable and clearable.

import 'dart:convert';
import 'dart:io';

import 'generador_catalogo.dart';

void main() {
  final salida = Directory('assets/levels');
  if (!salida.existsSync()) salida.createSync(recursive: true);

  for (var numero = 1; numero <= totalNivelesCatalogo; numero++) {
    final json = generarNivelJson(numero);
    final perfil = perfilNivel(numero);
    final forma = formaDeNivel(numero).nombre;
    final celdas = (json['cells'] as List).length;

    final ruta =
        'assets/levels/level_${numero.toString().padLeft(2, '0')}.json';
    File(ruta).writeAsStringSync('${_pretty(json)}\n');
    print(
      'level ${numero.toString().padLeft(2, '0')}  '
      '${perfil.dificultad.padRight(6)}  ${perfil.lado}x${perfil.lado}  '
      '${forma.padRight(10)}  celdas=$celdas  -> $ruta',
    );
  }

  print('\nDone — $totalNivelesCatalogo levels written to assets/levels/.');
}

String _pretty(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);
