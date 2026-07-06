import 'package:flutter/widgets.dart';

import 'cadenas.dart';

/// [InheritedWidget] that provides the active [Cadenas] to the widget tree.
///
/// Placed once near the root (inside `MaterialApp.builder`) and rebuilt by a
/// `ListenableBuilder` when [ConfiguracionManager] notifies a locale change.
/// Any widget that calls [CadenasScope.of] registers a dependency and is
/// automatically rebuilt when the locale switches — no manual calls needed.
///
/// Views should read strings exclusively through this scope:
/// ```dart
/// final s = CadenasScope.of(context);
/// Text(s.reintentar);
/// ```
class CadenasScope extends InheritedWidget {
  /// Creates a scope that provides [cadenas] to [child] and its descendants.
  const CadenasScope({
    required this.cadenas,
    required super.child,
    super.key,
  });

  /// The currently active string resources.
  final Cadenas cadenas;

  /// Returns the [Cadenas] from the nearest [CadenasScope] ancestor.
  ///
  /// Registers a dependency so the caller rebuilds on locale changes.
  /// Throws if no [CadenasScope] is in the tree (programming error).
  static Cadenas of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CadenasScope>();
    assert(scope != null, 'No CadenasScope found in the widget tree. '
        'Ensure MaterialApp.builder wraps content with CadenasScope.');
    return scope!.cadenas;
  }

  @override
  bool updateShouldNotify(CadenasScope old) => cadenas != old.cadenas;
}
