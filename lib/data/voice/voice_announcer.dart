import 'dart:async';
import 'dart:collection';

import '../../providers/providers.dart';
import 'tts_service.dart';

/// Serializes voice announcements from many concurrent event sources onto
/// a single TTS backend. Enforces:
///   - master switch (drop when off)
///   - per-event switch (checked by callers before invoking [say])
///   - rate limit (max N announcements per rolling minute)
///   - quiet hours (UTC window, silence in-window)
///   - serialisation (one utterance at a time, no overlap)
///
/// Announcements that fail the rate-limit / quiet-hours gate are dropped,
/// not queued — a band opening should not turn into a five-minute monologue
/// after the fact.
class VoiceAnnouncer {
  final TtsBackend Function() _backendFactory;
  final AppSettings Function() _readSettings;

  TtsBackend? _backend;
  final Queue<String> _queue = Queue<String>();
  final Queue<DateTime> _emittedAt = Queue<DateTime>();
  bool _speaking = false;

  VoiceAnnouncer({
    required TtsBackend Function() backendFactory,
    required AppSettings Function() readSettings,
  })  : _backendFactory = backendFactory,
        _readSettings = readSettings;

  TtsBackend _ensureBackend() => _backend ??= _backendFactory();

  /// Enqueue an announcement. Silently dropped if the master switch is off,
  /// the quiet-hours window is active, or the rate limit is saturated.
  void say(String text) {
    final s = _readSettings();
    if (!s.voiceEnabled) return;
    if (_inQuietHours(s)) return;
    if (!_underRateLimit(s)) return;
    _emittedAt.add(DateTime.now());
    _queue.add(text);
    unawaited(_pump());
  }

  /// User-initiated announcement used by the "Test voice" button in
  /// Settings. Bypasses the rate limit and quiet-hours gate (still
  /// respects the master switch) so the user can always verify the
  /// pipeline is wired up, no matter what happened in the last minute.
  void sayTest(String text) {
    final s = _readSettings();
    if (!s.voiceEnabled) return;
    _queue.add(text);
    unawaited(_pump());
  }

  bool _inQuietHours(AppSettings s) {
    final start = s.voiceQuietStartMin;
    final end = s.voiceQuietEndMin;
    if (start == null || end == null) return false;
    final now = DateTime.now().toUtc();
    final mins = now.hour * 60 + now.minute;
    return start <= end
        ? (mins >= start && mins < end)
        : (mins >= start || mins < end); // wraps midnight
  }

  bool _underRateLimit(AppSettings s) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    while (_emittedAt.isNotEmpty && _emittedAt.first.isBefore(cutoff)) {
      _emittedAt.removeFirst();
    }
    return _emittedAt.length < s.voiceRateLimitPerMinute;
  }

  Future<void> _pump() async {
    if (_speaking || _queue.isEmpty) return;
    _speaking = true;
    try {
      while (_queue.isNotEmpty) {
        final next = _queue.removeFirst();
        try {
          await _ensureBackend().speak(next);
        } catch (_) {
          // Swallow speech errors — no need to kill the queue.
        }
      }
    } finally {
      _speaking = false;
    }
  }

  Future<void> dispose() async {
    _queue.clear();
    await _backend?.stop();
    _backend?.dispose();
  }
}
