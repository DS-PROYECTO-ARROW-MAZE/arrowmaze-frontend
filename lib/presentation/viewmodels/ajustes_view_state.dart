import 'package:flutter/foundation.dart';

/// Immutable snapshot of the Settings screen's observable state.
///
/// The [AjustesViewModel] publishes new instances of this class via
/// [ChangeNotifier] whenever a setting changes. The View reads these
/// snapshots and never mutates them.
@immutable
class AjustesViewState {
  /// Creates a state snapshot with the given settings values.
  const AjustesViewState({
    this.sonidoHabilitado = true,
    this.idioma = 'en',
  });

  /// Whether game sounds are currently enabled.
  final bool sonidoHabilitado;

  /// The active language code (`'en'` or `'es'`).
  final String idioma;

  /// Returns a copy with the provided fields replaced.
  AjustesViewState copyWith({
    bool? sonidoHabilitado,
    String? idioma,
  }) {
    return AjustesViewState(
      sonidoHabilitado: sonidoHabilitado ?? this.sonidoHabilitado,
      idioma: idioma ?? this.idioma,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AjustesViewState &&
          sonidoHabilitado == other.sonidoHabilitado &&
          idioma == other.idioma;

  @override
  int get hashCode => Object.hash(sonidoHabilitado, idioma);
}
