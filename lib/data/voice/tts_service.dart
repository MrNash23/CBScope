import 'package:flutter/foundation.dart';

/// Pluggable text-to-speech backend. Phase 2 ships the debug backend
/// (console-only, no audio); Phase 3 will add a Piper subprocess backend
/// that plays real audio.
abstract class TtsBackend {
  /// Speak [text]. Returns when audio playback completes (or the debug
  /// backend has printed the line). Implementations must be safe to call
  /// serially from the [VoiceAnnouncer] queue.
  Future<void> speak(String text);

  /// Interrupt any in-flight utterance. Optional — no-op is fine.
  Future<void> stop() async {}

  void dispose() {}
}

/// Prints every announcement to stderr with a `[TTS]` tag. Used during
/// pipeline development so we can watch triggers fire in a run terminal
/// without needing the audio path wired up.
class DebugTtsBackend implements TtsBackend {
  @override
  Future<void> speak(String text) async {
    debugPrint('[TTS] $text');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
