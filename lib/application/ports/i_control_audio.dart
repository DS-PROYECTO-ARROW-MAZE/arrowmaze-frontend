/// Port that allows the presentation layer to control audio state (mute toggle)
/// without referencing infrastructure directly (DIP).
abstract interface class IControlAudio {
  /// Whether audio playback is globally muted.
  bool get muted;

  /// Toggles mute on/off.
  void toggleMute();
}
