import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/util/cb_dxcc.dart';
import '../../core/util/maidenhead.dart';
import '../../providers/providers.dart';
import '../db/database.dart';
import '../wsjtx/messages.dart';
import 'sherpa_onnx_tts_backend.dart';
import 'tts_service.dart';
import 'voice_announcer.dart';

// ----------------------------------------------------------------- providers

/// Currently-active TTS backend. Falls back to [DebugTtsBackend] on any
/// platform where audio isn't wired up (right now: everything except
/// macOS/Linux/Windows desktop, i.e. flutter test). The real backend
/// shells out to the bundled sherpa-onnx runtime; missing runtime is
/// handled internally as a no-op with a single debug log.
final ttsBackendProvider = Provider<TtsBackend>((ref) {
  final TtsBackend backend =
      (Platform.isMacOS || Platform.isLinux || Platform.isWindows)
          ? SherpaOnnxTtsBackend()
          : DebugTtsBackend();
  ref.onDispose(backend.dispose);
  return backend;
});

/// Singleton [VoiceAnnouncer]. Reads the current [AppSettings] on every
/// [VoiceAnnouncer.say] call so runtime toggle changes take effect
/// immediately without recreating the announcer.
final voiceAnnouncerProvider = Provider<VoiceAnnouncer>((ref) {
  final a = VoiceAnnouncer(
    backendFactory: () => ref.read(ttsBackendProvider),
    readSettings: () => ref.read(settingsProvider),
  );
  ref.onDispose(a.dispose);
  return a;
});

/// Fire-and-forget: mounts every event listener that can trigger a voice
/// announcement. Watched by the app shell so it starts running when the
/// app boots and stays alive for the process lifetime.
final voicePipelineProvider = Provider<void>((ref) {
  final announcer = ref.watch(voiceAnnouncerProvider);
  final unit = () => ref.read(settingsProvider).distanceUnit;

  // Push settings.voiceVolume into the backend on every change. This
  // makes the Settings volume slider audible live — dragging it while
  // an utterance is playing adjusts the current playback immediately.
  final backend = ref.watch(ttsBackendProvider);
  backend.setVolume(ref.read(settingsProvider).voiceVolume);
  ref.listen<AppSettings>(settingsProvider, (prev, next) {
    if (prev?.voiceVolume != next.voiceVolume) {
      backend.setVolume(next.voiceVolume);
    }
  });

  // ---------------- Decode-driven listeners -------------------------------
  ref.listen<AsyncValue<WsjtxMessage>>(wsjtxMessagesProvider, (_, next) {
    next.whenData((m) {
      if (m is WsjtxDecode) _onDecode(ref, announcer, m);
      if (m is WsjtxQsoLogged) _onQsoLogged(ref, announcer, m, unit());
    });
  });

  // ---------------- Milestone / logbook-diff listeners --------------------
  final logbookState = _LogbookMilestoneTracker(ref: ref);
  ref.listen<AsyncValue<List<Qso>>>(logbookProvider, (prev, next) {
    next.whenData(logbookState.observe);
  });

  // ---------------- Solar-flux threshold ----------------------------------
  final solarState = _SolarThresholdTracker();
  ref.listen(solarDataProvider, (_, next) {
    next.whenData((s) => solarState.observe(ref, announcer, s?.sfi));
  });

  // ---------------- Connection watchdog + greyline window -----------------
  final wdog = _ConnectionWatchdog(ref: ref, announcer: announcer);
  final greyline = _GreylineTicker(ref: ref, announcer: announcer);
  final tick = Timer.periodic(const Duration(seconds: 15), (_) {
    wdog.tick();
    greyline.tick();
  });
  ref.onDispose(tick.cancel);
});

// -------------------------------------------------------- decode dispatch

void _onDecode(Ref ref, VoiceAnnouncer a, WsjtxDecode d) {
  final s = ref.read(settingsProvider);
  if (!s.voiceEnabled) return;

  final call = d.stationCall();
  if (call == null) return;
  final upper = call.toUpperCase();
  final msg = d.message.trim().toUpperCase();
  final isCq = msg.startsWith('CQ ');
  final myCall = s.myCall?.trim().toUpperCase();

  final grid = d.gridHint() ??
      ref.read(callsignResolverProvider).gridFor(upper);
  final myGrid = s.myGrid;

  // -------- Incoming call (addressed to me, not a CQ) --------------------
  if (s.voiceEvents.contains(VoiceEvent.incomingCall) &&
      myCall != null &&
      myCall.isNotEmpty &&
      !isCq &&
      msg.split(RegExp(r'\s+')).first.replaceAll(RegExp(r'^<|>$'), '') ==
          myCall) {
    a.say('Incoming call from ${_spell(upper)}.');
    return; // one strong signal per decode is enough
  }

  // -------- Strong signal ------------------------------------------------
  if (s.voiceEvents.contains(VoiceEvent.strongSignal) &&
      d.snr >= s.voiceStrongSignalDb) {
    a.say('Strong signal, ${_snr(d.snr)} from ${_spell(upper)}.');
  }

  // -------- CQ-only from here on ----------------------------------------
  if (!isCq) return;

  final worked =
      ref.read(workedCallsignsProvider).valueOrNull ?? const <String>{};
  final workedGrids =
      ref.read(workedGridsProvider).valueOrNull ?? const <String>{};
  final workedCountries =
      ref.read(workedCountriesProvider).valueOrNull ?? const <String>{};

  // -------- New callsign CQ ---------------------------------------------
  if (s.voiceEvents.contains(VoiceEvent.newCallCq) &&
      !worked.contains(upper)) {
    a.say('New station ${_spell(upper)} calling C-Q.');
  }

  // -------- New grid CQ -------------------------------------------------
  if (s.voiceEvents.contains(VoiceEvent.newGridCq) &&
      grid != null &&
      grid.length >= 4 &&
      !workedGrids.contains(grid.substring(0, 4).toUpperCase())) {
    final grid4 = grid.substring(0, 4);
    final country = countryFromCbCallsign(upper);
    a.say(country != null
        ? 'New grid: ${_letters(grid4)}, $country.'
        : 'New grid: ${_letters(grid4)}.');
  }

  // -------- New DXCC country CQ -----------------------------------------
  if (s.voiceEvents.contains(VoiceEvent.newCountryCq)) {
    final country = countryFromCbCallsign(upper);
    if (country != null && !workedCountries.contains(country)) {
      a.say('New country: $country, ${_spell(upper)}.');
    }
  }

  // -------- Notable DX (distance-based) ---------------------------------
  if (s.voiceEvents.contains(VoiceEvent.notableDx) &&
      grid != null &&
      myGrid != null) {
    final dist = _distanceKm(myGrid, grid);
    if (dist != null && dist >= s.voiceNotableDxKm) {
      a.say('Long-range decode. ${_spell(upper)}. '
          '${dist.round()} kilometers.');
    }
  }
}

// -------------------------------------------------------- qso-logged UDP

void _onQsoLogged(
    Ref ref, VoiceAnnouncer a, WsjtxQsoLogged m, DistanceUnit unit) {
  final s = ref.read(settingsProvider);
  if (!s.voiceEnabled) return;
  if (s.voiceEvents.contains(VoiceEvent.qsoLogged)) {
    a.say('QSO logged with ${_spell(m.dxCall.toUpperCase())}.');
  }
}

// -------------------------------------------------------- milestones

class _LogbookMilestoneTracker {
  final Ref ref;
  int _lastCount = -1;
  Set<int> _seenIds = <int>{};
  double? _pbKm;

  _LogbookMilestoneTracker({required this.ref});

  void observe(List<Qso> rows) {
    final s = ref.read(settingsProvider);
    final a = ref.read(voiceAnnouncerProvider);

    // First observation just seeds the caches — never announce on cold boot.
    if (_lastCount < 0) {
      _lastCount = rows.length;
      _seenIds = rows.map((q) => q.id).toSet();
      _pbKm = _pbFromRows(rows, s.myGrid);
      return;
    }

    // Round-number milestones (crossed since last observation).
    if (s.voiceEnabled &&
        s.voiceEvents.contains(VoiceEvent.qsoCountMilestone) &&
        rows.length > _lastCount) {
      for (final m in _milestonesBetween(_lastCount, rows.length)) {
        a.say('Milestone. $m QSOs logged.');
      }
    }

    final newRows = rows.where((q) => !_seenIds.contains(q.id)).toList();
    for (final q in newRows) {
      _observeNewQso(q, s, a);
    }

    _lastCount = rows.length;
    _seenIds = rows.map((q) => q.id).toSet();
  }

  void _observeNewQso(Qso q, AppSettings s, VoiceAnnouncer a) {
    if (!s.voiceEnabled) return;
    final grid = q.gridsquare;
    final country = q.country;

    // First contact with a country.
    if (s.voiceEvents.contains(VoiceEvent.firstCountry) &&
        country != null &&
        country.isNotEmpty) {
      final priorCountries =
          ref.read(workedCountriesProvider).valueOrNull ?? const <String>{};
      // The provider already includes this row (drift-reactive), so
      // "first" means it appears exactly once in the current set.
      final priorSet = {...priorCountries};
      // Best-effort: this is a heuristic — good enough for the debug
      // pipeline and easy to refine when we have a proper insert event bus.
      if (priorSet.length == 1 && priorSet.contains(country)) {
        a.say('First contact with $country. Confirmed.');
      }
    }

    // First contact from a new grid.
    if (s.voiceEvents.contains(VoiceEvent.firstGrid) &&
        grid != null &&
        grid.length >= 4) {
      final priorGrids =
          ref.read(workedGridsProvider).valueOrNull ?? const <String>{};
      final priorSet = {...priorGrids};
      final short = grid.substring(0, 4).toUpperCase();
      if (priorSet.length == 1 && priorSet.contains(short)) {
        final c = country ?? countryFromCbCallsign(q.call.toUpperCase());
        a.say(c != null
            ? 'New grid worked: ${_letters(short)}, $c.'
            : 'New grid worked: ${_letters(short)}.');
      }
    }

    // Personal-best DX.
    if (s.voiceEvents.contains(VoiceEvent.personalBestDx) &&
        s.myGrid != null &&
        grid != null &&
        grid.length >= 4) {
      final d = _distanceKm(s.myGrid!, grid);
      if (d != null && (_pbKm == null || d > _pbKm!)) {
        _pbKm = d;
        a.say('Personal best. ${d.round()} kilometers.');
      }
    }
  }

  double? _pbFromRows(List<Qso> rows, String? myGrid) {
    if (myGrid == null) return null;
    double? best;
    for (final q in rows) {
      final g = q.gridsquare;
      if (g == null || g.length < 4) continue;
      final d = _distanceKm(myGrid, g);
      if (d == null) continue;
      if (best == null || d > best) best = d;
    }
    return best;
  }

  Iterable<int> _milestonesBetween(int from, int to) sync* {
    const steps = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];
    for (final s in steps) {
      if (from < s && to >= s) yield s;
    }
  }
}

// -------------------------------------------------------- solar-flux gate

class _SolarThresholdTracker {
  double? _prevSfi;

  void observe(Ref ref, VoiceAnnouncer a, double? sfi) {
    if (sfi == null) return;
    final s = ref.read(settingsProvider);
    if (_prevSfi == null) {
      _prevSfi = sfi;
      return;
    }
    if (s.voiceEnabled &&
        s.voiceEvents.contains(VoiceEvent.solarFluxThreshold)) {
      final t = s.voiceSolarFluxSfi.toDouble();
      final crossed = (_prevSfi! < t && sfi >= t) ||
          (_prevSfi! >= t && sfi < t);
      if (crossed) {
        a.say('Solar flux ${sfi.round()}.');
      }
    }
    _prevSfi = sfi;
  }
}

// -------------------------------------------------------- WSJT-CB watchdog

class _ConnectionWatchdog {
  final Ref ref;
  final VoiceAnnouncer announcer;
  bool _connected = false;

  _ConnectionWatchdog({required this.ref, required this.announcer});

  void tick() {
    final s = ref.read(settingsProvider);
    if (!s.voiceEnabled) {
      // Still update internal state so the next enable doesn't announce
      // a stale transition, but don't speak.
    }
    final last = ref.read(udpListenerProvider).lastPacketAt;
    final now = DateTime.now();
    final live = last != null && now.difference(last).inSeconds < 30;
    if (live == _connected) return;
    _connected = live;
    if (!s.voiceEnabled) return;
    if (live &&
        s.voiceEvents.contains(VoiceEvent.connectionRestored)) {
      announcer.say('WSJT-C-B reconnected.');
    } else if (!live &&
        s.voiceEvents.contains(VoiceEvent.connectionLost)) {
      announcer.say('WSJT-C-B disconnected.');
    }
  }
}

// -------------------------------------------------------- greyline window

class _GreylineTicker {
  final Ref ref;
  final VoiceAnnouncer announcer;
  DateTime? _lastAnnouncedWindowStart;

  _GreylineTicker({required this.ref, required this.announcer});

  void tick() {
    final s = ref.read(settingsProvider);
    if (!s.voiceEnabled) return;
    if (!s.voiceEvents.contains(VoiceEvent.greylineWindow)) return;
    final myGrid = s.myGrid;
    if (myGrid == null) return;
    final ll = gridToLatLng(myGrid);
    if (ll == null) return;

    // Simple sunrise/sunset approximation. Windows are ±15 min around
    // each event; announce once per window entry per day.
    final now = DateTime.now().toUtc();
    final events = _sunEventsUtc(ll, now);
    for (final e in events) {
      final delta = now.difference(e).inMinutes;
      if (delta.abs() > 15) continue;
      if (_lastAnnouncedWindowStart != null &&
          e.isAtSameMomentAs(_lastAnnouncedWindowStart!)) {
        continue;
      }
      _lastAnnouncedWindowStart = e;
      announcer.say('Greyline window opening.');
      return;
    }
  }

  /// Very rough sunrise/sunset UTC for [today], based on the "NOAA solar
  /// calculator" simplification. Not for aviation-grade accuracy — good
  /// enough for a ±15 min voice hint.
  List<DateTime> _sunEventsUtc(LatLng qth, DateTime nowUtc) {
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final n = today
            .difference(DateTime.utc(today.year))
            .inDays +
        1; // day of year
    final lngHour = qth.longitude / 15.0;
    final results = <DateTime>[];
    for (final rising in [true, false]) {
      final tApprox = n + ((rising ? 6.0 : 18.0) - lngHour) / 24.0;
      final m = (0.9856 * tApprox) - 3.289;
      final l = _norm(
          m + (1.916 * math.sin(_rad(m))) + (0.020 * math.sin(_rad(2 * m))) + 282.634,
          360);
      final ra = _norm(math.atan(0.91764 * math.tan(_rad(l))) * 180 / math.pi,
          360);
      final lQuad = ((l / 90).floor()) * 90;
      final raQuad = ((ra / 90).floor()) * 90;
      final raAdj = (ra + (lQuad - raQuad)) / 15.0;
      final sinDec = 0.39782 * math.sin(_rad(l));
      final cosDec = math.cos(math.asin(sinDec));
      final cosH = (math.cos(_rad(90.833)) -
              sinDec * math.sin(_rad(qth.latitude))) /
          (cosDec * math.cos(_rad(qth.latitude)));
      if (cosH > 1 || cosH < -1) continue; // sun never rises/sets
      final h = rising
          ? (360 - math.acos(cosH) * 180 / math.pi) / 15.0
          : (math.acos(cosH) * 180 / math.pi) / 15.0;
      final utcHours = _norm(h + raAdj - (0.06571 * tApprox) - 6.622 - lngHour, 24);
      final utcMin = (utcHours * 60).round();
      results.add(today.add(Duration(minutes: utcMin)));
    }
    return results;
  }

  double _rad(double deg) => deg * math.pi / 180;
  double _norm(double v, double m) {
    var r = v;
    while (r < 0) r += m;
    while (r >= m) r -= m;
    return r;
  }
}

// -------------------------------------------------------- helpers

/// Great-circle km between two Maidenhead grids.
double? _distanceKm(String gridA, String gridB) {
  final a = gridToLatLng(gridA);
  final b = gridToLatLng(gridB);
  if (a == null || b == null) return null;
  return const Distance().as(LengthUnit.Kilometer, a, b);
}

/// Spell a callsign one character at a time so the TTS engine reads
/// e.g. "56PJ017" as "five six P J zero one seven" instead of trying to
/// pronounce "fifty-six PJ seventeen". Every character gets its own
/// space; adjacent digits therefore read as separate digit words too.
String _spell(String call) => call.trim().split('').join(' ');

/// Space out a grid locator so TTS reads it letter-by-letter.
String _letters(String s) => s.split('').join(' ');

String _snr(int snr) => snr >= 0 ? 'plus $snr dB' : 'minus ${-snr} dB';
