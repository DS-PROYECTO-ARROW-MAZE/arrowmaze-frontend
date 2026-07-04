/// Pluggable audio backend — lets tests swap the real player for a fake.
abstract interface class IReproductorAudio {
  /// Plays the audio asset at [assetPath] (e.g. `"sounds/move_soft.wav"`) at
  /// [volumen] (0.0–1.0, comfortable/non-clipping levels are the caller's
  /// responsibility). Errors degrade gracefully (no crash).
  void reproducir(String assetPath, {double volumen = 1.0});

  /// Stops the current playback immediately.
  void detener();

  /// Releases all resources (dispose the underlying player).
  void liberar();
}
