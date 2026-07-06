import 'package:audioplayers/audioplayers.dart';

import 'i_reproductor_audio.dart';

/// Asset-based audio player backed by the `audioplayers` package.
///
/// Errors (missing asset, player failure) are caught and silently dropped so the
/// game never crashes when a sound file is unavailable (AC4).
final class ReproductorAudioAssets implements IReproductorAudio {
  final AudioPlayer _player = AudioPlayer();

  @override
  void reproducir(String assetPath, {double volumen = 1.0}) {
    _player.stop();
    _player.setVolume(volumen);
    _player
        .play(AssetSource(assetPath))
        .onError(
          (_, _) => null, // graceful degradation
        );
  }

  @override
  void detener() => _player.stop();

  @override
  void liberar() => _player.dispose();
}
