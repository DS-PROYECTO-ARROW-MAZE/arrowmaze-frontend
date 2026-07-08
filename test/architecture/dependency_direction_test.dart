import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ticket 12 — Architecture guards (AC2, AC4).
///
/// Pure source-level lints wired into CI: they read the `lib/` tree and fail on
/// any import that would point the dependency arrows the wrong way. No app code
/// is executed; only `import` directives are inspected.
void main() {
  /// Returns every `import '...'` / `import "..."` target inside [dir],
  /// excluding directives that sit inside line comments.
  List<({String file, String target})> importsDe(Directory dir) {
    final directiva = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');
    final resultado = <({String file, String target})>[];
    for (final entidad in dir.listSync(recursive: true)) {
      if (entidad is! File || !entidad.path.endsWith('.dart')) continue;
      for (final linea in entidad.readAsLinesSync()) {
        final trimmed = linea.trimLeft();
        if (trimmed.startsWith('//')) continue;
        final m = directiva.firstMatch(linea);
        if (m != null) {
          resultado.add((file: entidad.path, target: m.group(1)!));
        }
      }
    }
    return resultado;
  }

  group('Architecture — dependency direction', () {
    test('should_not_import_logging_or_metrics_library_when_scanning_decorator', () {
      // Arrange — the decorators must lean only on ports, never a concrete
      // logging/metrics/framework library (AC2).
      final dir = Directory('lib/application/decoradores');
      expect(dir.existsSync(), isTrue,
          reason: 'lib/application/decoradores must exist');

      final prohibidos = RegExp(
        r'(dart:developer|package:flutter|package:logging|package:logger|'
        r'metrics|prisma|@nestjs)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports a forbidden logging/metrics/framework target: '
              '"${imp.target}" — decorators may depend only on ports (AC2).',
        );
      }
    });

    test('should_keep_domain_free_of_frameworks_when_scanning_imports', () {
      // Arrange — domain stays Dart-pure: no Flutter/logging/metrics/Nest/Prisma
      // and no leakage from outer layers (AC4, ADR-0004).
      final dir = Directory('lib/domain');
      expect(dir.existsSync(), isTrue, reason: 'lib/domain must exist');

      final prohibidos = RegExp(
        r'(package:flutter|dart:ui|dart:html|package:logging|package:logger|'
        r'package:http|metrics|prisma|@nestjs|/infrastructure/|/application/|'
        r'/presentation/)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports "${imp.target}", which breaks domain purity '
              '(AC4).',
        );
      }
    });

    test('should_keep_application_free_of_flutter_and_outer_layers_when_scanning_imports', () {
      // Arrange — the application layer is pure Dart use cases and ports: no
      // Flutter, and no leakage from the presentation/infrastructure rings.
      final dir = Directory('lib/application');
      expect(dir.existsSync(), isTrue, reason: 'lib/application must exist');

      final prohibidos = RegExp(
        r'(package:flutter|dart:ui|dart:html|/infrastructure/|/presentation/)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports "${imp.target}", which breaks application '
              'purity — application may depend only on domain and itself.',
        );
      }
    });

    test('should_keep_viewmodels_free_of_flutter_ui_when_scanning_imports', () {
      // Arrange — ViewModels may use ChangeNotifier (foundation) but must never
      // touch Flutter UI surfaces; that is the View's job (strict MVVM).
      final dir = Directory('lib/presentation/viewmodels');
      expect(dir.existsSync(), isTrue,
          reason: 'lib/presentation/viewmodels must exist');

      final prohibidos = RegExp(
        r'(package:flutter/material|package:flutter/widgets|'
        r'package:flutter/cupertino)',
        caseSensitive: false,
      );

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          prohibidos.hasMatch(imp.target),
          isFalse,
          reason:
              '${imp.file} imports "${imp.target}", a Flutter UI library — '
              'ViewModels must stay UI-independent (strict MVVM).',
        );
      }
    });

    test('should_not_reference_audio_when_scanning_domain_or_application', () {
      // AC2: domain/use-case code contains no reference to audio — audio is
      // driven only through the Observer pattern.
      for (final capa in ['lib/domain', 'lib/application']) {
        final dir = Directory(capa);
        expect(dir.existsSync(), isTrue, reason: '$capa must exist');
        for (final imp in importsDe(dir)) {
          final prohibido = imp.target.contains('audio') ||
              imp.target.contains('audioplayers') ||
              imp.target.contains('IReproductorAudio') ||
              imp.target.contains('AudioService');
          expect(
            prohibido,
            isFalse,
            reason:
                '${imp.file} imports "${imp.target}" — domain/application '
                'must not reference audio concerns (AC2).',
          );
        }
      }
    });

    test('should_keep_presentation_free_of_infrastructure_when_scanning_imports', () {
      // Arrange — the presentation layer reaches infrastructure only through
      // the composition root (di/), never by importing it directly.
      final dir = Directory('lib/presentation');
      expect(dir.existsSync(), isTrue,
          reason: 'lib/presentation must exist');

      // Act / Assert
      for (final imp in importsDe(dir)) {
        expect(
          imp.target.contains('/infrastructure/'),
          isFalse,
          reason:
              '${imp.file} imports "${imp.target}" from infrastructure — '
              'presentation must depend on application/domain abstractions only.',
        );
      }
    });
  });
}
