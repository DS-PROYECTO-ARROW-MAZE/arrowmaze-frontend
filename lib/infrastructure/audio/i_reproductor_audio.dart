/// Pluggable audio backend — lets tests swap the real player for a fake.
abstract interface class IReproductorAudio {
  /// Plays the audio asset at [assetPath] (e.g. `"sounds/move.wav"`).
  /// Errors degrade gracefully (no crash).
  void reproducir(String assetPath);

  /// Stops the current playback immediately.
  void detener();

  /// Releases all resources (dispose the underlying player).
  void liberar();
}
