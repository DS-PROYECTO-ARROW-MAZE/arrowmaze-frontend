import 'package:flutter/foundation.dart';

import '../../core/configuracion_manager.dart';
import 'ajustes_view_state.dart';

/// The Settings screen's only collaborator (Ticket 27, DM-F8).
///
/// Bridges the [AjustesView] to [ConfiguracionManager]: it delegates all
/// persistence and audio-mute side-effects to the manager, and mirrors the
/// manager's state as immutable [AjustesViewState] snapshots.
///
/// ViewModels never import `infrastructure/` directly; both the persistence
/// port and the audio port are hidden behind [ConfiguracionManager] (DIP).
class AjustesViewModel extends ChangeNotifier {
  /// Creates the ViewModel bound to [config].
  ///
  /// Reads the current settings immediately from [config] so the first rendered
  /// frame already reflects the saved locale and mute state (AC4).
  AjustesViewModel({required ConfiguracionManager config}) : _config = config {
    _estado = AjustesViewState(
      sonidoHabilitado: config.sonidoHabilitado,
      idioma: config.idioma,
    );
    config.addListener(_alCambiarConfig);
  }

  final ConfiguracionManager _config;
  late AjustesViewState _estado;

  /// The current immutable state the View renders.
  AjustesViewState get estado => _estado;

  /// Toggles sound on/off, persists the new value, and mutes/unmutes the
  /// global [AudioServiceImp] — all via [ConfiguracionManager] (AC2).
  Future<void> toggleSonido() => _config.toggleSonido();

  /// Switches the active language, persists the choice, and triggers a live
  /// string refresh through [CadenasScope] (AC3).
  Future<void> cambiarIdioma(String idioma) => _config.cambiarIdioma(idioma);

  void _alCambiarConfig() {
    _estado = AjustesViewState(
      sonidoHabilitado: _config.sonidoHabilitado,
      idioma: _config.idioma,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _config.removeListener(_alCambiarConfig);
    super.dispose();
  }
}
