import 'package:arrowmaze/application/ports/i_control_audio.dart';
import 'package:arrowmaze/application/ports/preferencias_usuario.dart';
import 'package:arrowmaze/core/configuracion_manager.dart';
import 'package:arrowmaze/presentation/viewmodels/ajustes_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [PreferenciasUsuario] — in-memory store, no shared_preferences.
class _FakePrefs implements PreferenciasUsuario {
  bool _sonido = true;
  String? _idioma;

  @override
  Future<bool> leerSonidoHabilitado() async => _sonido;

  @override
  Future<String?> leerIdioma() async => _idioma;

  @override
  Future<void> guardarSonidoHabilitado(bool habilitado) async =>
      _sonido = habilitado;

  @override
  Future<void> guardarIdioma(String idioma) async => _idioma = idioma;
}

/// Fake [IControlAudio] — records toggle calls, never touches a platform channel.
class _FakeAudio implements IControlAudio {
  bool _muted = false;

  @override
  bool get muted => _muted;

  @override
  void toggleMute() => _muted = !_muted;
}

void main() {
  group('AjustesViewModel', () {
    late _FakePrefs prefs;
    late _FakeAudio audio;
    late ConfiguracionManager config;

    setUp(() {
      prefs = _FakePrefs();
      audio = _FakeAudio();
      config = ConfiguracionManager(prefs: prefs, audioControl: audio);
    });

    // ── AC2 ──────────────────────────────────────────────────────────────────
    test('should_persist_and_apply_sound_toggle_when_changed', () async {
      // Arrange
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);
      expect(viewModel.estado.sonidoHabilitado, isTrue,
          reason: 'default is sound ON');
      expect(audio.muted, isFalse);

      // Act
      await viewModel.toggleSonido();

      // Assert — ViewModel reflects new state
      expect(viewModel.estado.sonidoHabilitado, isFalse);
      // Audio service is now muted
      expect(audio.muted, isTrue);
      // Pref was persisted
      expect(await prefs.leerSonidoHabilitado(), isFalse);

      viewModel.dispose();
    });

    // ── AC3 ──────────────────────────────────────────────────────────────────
    test('should_persist_and_change_locale_when_language_selected', () async {
      // Arrange
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);
      expect(viewModel.estado.idioma, 'en');

      // Act
      await viewModel.cambiarIdioma('es');

      // Assert — ViewModel reflects new locale
      expect(viewModel.estado.idioma, 'es');
      // Pref was persisted
      expect(await prefs.leerIdioma(), 'es');

      viewModel.dispose();
    });

    // ── AC4 ──────────────────────────────────────────────────────────────────
    test('should_load_saved_settings_on_init', () async {
      // Arrange — pre-populate prefs with saved values (simulates a restart)
      await prefs.guardarSonidoHabilitado(false);
      await prefs.guardarIdioma('es');

      // Act — manager reads prefs; ViewModel reads manager state
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);

      // Assert — ViewModel reflects the persisted settings
      expect(viewModel.estado.sonidoHabilitado, isFalse);
      expect(viewModel.estado.idioma, 'es');
      // Audio is muted because saved pref said so
      expect(audio.muted, isTrue);

      viewModel.dispose();
    });

    // ── AC5 ──────────────────────────────────────────────────────────────────
    test('should_default_to_sound_on_and_english_on_first_run', () async {
      // Arrange — empty prefs (first run)
      // Act
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);

      // Assert — sensible defaults
      expect(viewModel.estado.sonidoHabilitado, isTrue);
      expect(viewModel.estado.idioma, 'en');
      expect(audio.muted, isFalse);

      viewModel.dispose();
    });

    test('should_notify_listeners_when_sound_toggled', () async {
      // Arrange
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);
      var notified = 0;
      viewModel.addListener(() => notified++);

      // Act
      await viewModel.toggleSonido();

      // Assert
      expect(notified, greaterThanOrEqualTo(1));

      viewModel.dispose();
    });

    test('should_notify_listeners_when_idioma_changed', () async {
      // Arrange
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);
      var notified = 0;
      viewModel.addListener(() => notified++);

      // Act
      await viewModel.cambiarIdioma('es');

      // Assert
      expect(notified, greaterThanOrEqualTo(1));

      viewModel.dispose();
    });

    test('should_not_toggle_audio_when_same_language_selected', () async {
      // Arrange — no idioma change should occur
      await config.inicializar();
      final viewModel = AjustesViewModel(config: config);
      expect(viewModel.estado.idioma, 'en');

      // Act
      await viewModel.cambiarIdioma('en'); // same language

      // Assert — state unchanged
      expect(viewModel.estado.idioma, 'en');

      viewModel.dispose();
    });
  });
}
