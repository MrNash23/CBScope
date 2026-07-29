import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/util/cb_dxcc.dart';
import '../data/adif/adif_parser.dart';
import '../data/adif/adif_tail_watcher.dart';
import '../data/db/database.dart';
import '../data/db/qso_repository.dart';
import '../data/propagation/solar_client.dart';
import '../data/psk_reporter/callsign_resolver.dart';
import '../data/psk_reporter/psk_reporter_client.dart';
import '../data/wsjtx/messages.dart';
import '../data/wsjtx/udp_listener.dart';

/// ---------------- Core singletons ----------------

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final qsoRepoProvider = Provider<QsoRepository>((ref) {
  final repo = QsoRepository(ref.watch(dbProvider));
  // One-shot cleanup for legacy CB-band dupes (see repairCbBandDuplicates).
  // Fire-and-forget — the sync-only Provider must return the repo now.
  unawaited(repo.repairCbBandDuplicates());
  return repo;
});

final prefsProvider = FutureProvider<SharedPreferences>((_) async {
  final prefs = await SharedPreferences.getInstance();
  // Warm the CB-prefix-country self-learning cache from disk before any
  // provider that consumes prefs starts firing lookups.
  await initCbPrefixLearner(prefs);
  return prefs;
});

/// ---------------- Settings ----------------

class AppSettings {
  final int udpPort;
  final String bindAddress;
  final String? multicastGroup;
  final String? adifLogPath;
  final String? myCall;
  final String? myGrid;
  final ThemeModePref theme;
  final DistanceUnit distanceUnit;
  final bool pskReporterLookup;
  final AppMode appMode;
  final PskSpotDirection pskSpotDirection;
  final PskSpotWindow pskSpotWindow;

  /// Minutes for PskSpotWindow.custom (1-60).
  final int pskSpotCustomMinutes;

  /// When true we tail WSJT-CB's ADIF log in the background and import each
  /// new QSO into our own database, enriched with a solar/propagation
  /// snapshot taken at ingest time.
  final bool autoImportWsjtLog;
  final Color qsoColor;
  final Color decodeColor;
  final Color pskColor;
  final Color meColor;
  final MapStyle mapStyle;
  final bool mapGreylineEnabled;

  /// Theme accent chosen from [AppTheme.accentPalette]. `null` keeps the
  /// theme's built-in default (Tron cyan in dark, dark cyan in light).
  final Color? themeAccent;

  // -------- Voice announcements ---------------------------------------------

  /// Master switch. When false, no speech and no per-event toggles shown.
  final bool voiceEnabled;

  /// Which announcement events are enabled.
  final Set<VoiceEvent> voiceEvents;

  /// Distance threshold (km) for [VoiceEvent.notableDx].
  final int voiceNotableDxKm;

  /// SNR threshold (dB) for [VoiceEvent.strongSignal].
  final int voiceStrongSignalDb;

  /// SFI threshold for [VoiceEvent.solarFluxThreshold] (announced when
  /// crossed in either direction).
  final int voiceSolarFluxSfi;

  /// Playback volume for spoken announcements, 0.0–1.0. Applied live so
  /// dragging the settings slider changes any currently-playing utterance.
  final double voiceVolume;

  /// Max announcements per minute — protects against flurry storms.
  final int voiceRateLimitPerMinute;

  /// Quiet-hours window (minutes past UTC midnight). `null` on either
  /// end disables the mute.
  final int? voiceQuietStartMin;
  final int? voiceQuietEndMin;

  const AppSettings({
    required this.udpPort,
    required this.bindAddress,
    required this.multicastGroup,
    required this.adifLogPath,
    required this.myCall,
    required this.myGrid,
    required this.theme,
    required this.distanceUnit,
    required this.pskReporterLookup,
    required this.appMode,
    required this.pskSpotDirection,
    required this.pskSpotWindow,
    required this.pskSpotCustomMinutes,
    required this.autoImportWsjtLog,
    required this.qsoColor,
    required this.decodeColor,
    required this.pskColor,
    required this.meColor,
    required this.mapStyle,
    required this.mapGreylineEnabled,
    this.themeAccent,
    this.voiceEnabled = false,
    this.voiceEvents = const {},
    this.voiceNotableDxKm = 5000,
    this.voiceStrongSignalDb = 0,
    this.voiceSolarFluxSfi = 150,
    this.voiceRateLimitPerMinute = 4,
    this.voiceVolume = 1.0,
    this.voiceQuietStartMin,
    this.voiceQuietEndMin,
  });

  /// Sensible on-by-default events after the master switch is first flipped
  /// on. Only high-value, low-noise events so the first-run experience isn't
  /// an audio monologue.
  static const Set<VoiceEvent> defaultOnEvents = {
    VoiceEvent.newCountryCq,
    VoiceEvent.incomingCall,
    VoiceEvent.qsoLogged,
  };

  AppSettings copyWith({
    int? udpPort,
    String? bindAddress,
    String? multicastGroup,
    String? adifLogPath,
    String? myCall,
    String? myGrid,
    ThemeModePref? theme,
    DistanceUnit? distanceUnit,
    bool? pskReporterLookup,
    AppMode? appMode,
    PskSpotDirection? pskSpotDirection,
    PskSpotWindow? pskSpotWindow,
    int? pskSpotCustomMinutes,
    bool? autoImportWsjtLog,
    Color? qsoColor,
    Color? decodeColor,
    Color? pskColor,
    Color? meColor,
    MapStyle? mapStyle,
    bool? mapGreylineEnabled,
    Color? themeAccent,
    bool? voiceEnabled,
    Set<VoiceEvent>? voiceEvents,
    int? voiceNotableDxKm,
    int? voiceStrongSignalDb,
    int? voiceSolarFluxSfi,
    int? voiceRateLimitPerMinute,
    double? voiceVolume,
    int? voiceQuietStartMin,
    int? voiceQuietEndMin,
    bool clearMulticast = false,
    bool clearAdifPath = false,
    bool clearThemeAccent = false,
    bool clearVoiceQuiet = false,
  }) =>
      AppSettings(
        udpPort: udpPort ?? this.udpPort,
        bindAddress: bindAddress ?? this.bindAddress,
        multicastGroup:
            clearMulticast ? null : (multicastGroup ?? this.multicastGroup),
        adifLogPath: clearAdifPath ? null : (adifLogPath ?? this.adifLogPath),
        myCall: myCall ?? this.myCall,
        myGrid: myGrid ?? this.myGrid,
        theme: theme ?? this.theme,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        pskReporterLookup: pskReporterLookup ?? this.pskReporterLookup,
        appMode: appMode ?? this.appMode,
        pskSpotDirection: pskSpotDirection ?? this.pskSpotDirection,
        pskSpotWindow: pskSpotWindow ?? this.pskSpotWindow,
        pskSpotCustomMinutes: pskSpotCustomMinutes ?? this.pskSpotCustomMinutes,
        autoImportWsjtLog: autoImportWsjtLog ?? this.autoImportWsjtLog,
        qsoColor: qsoColor ?? this.qsoColor,
        decodeColor: decodeColor ?? this.decodeColor,
        pskColor: pskColor ?? this.pskColor,
        meColor: meColor ?? this.meColor,
        mapStyle: mapStyle ?? this.mapStyle,
        mapGreylineEnabled: mapGreylineEnabled ?? this.mapGreylineEnabled,
        themeAccent:
            clearThemeAccent ? null : (themeAccent ?? this.themeAccent),
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        voiceEvents: voiceEvents ?? this.voiceEvents,
        voiceNotableDxKm: voiceNotableDxKm ?? this.voiceNotableDxKm,
        voiceStrongSignalDb: voiceStrongSignalDb ?? this.voiceStrongSignalDb,
        voiceSolarFluxSfi: voiceSolarFluxSfi ?? this.voiceSolarFluxSfi,
        voiceRateLimitPerMinute:
            voiceRateLimitPerMinute ?? this.voiceRateLimitPerMinute,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        voiceQuietStartMin: clearVoiceQuiet
            ? null
            : (voiceQuietStartMin ?? this.voiceQuietStartMin),
        voiceQuietEndMin: clearVoiceQuiet
            ? null
            : (voiceQuietEndMin ?? this.voiceQuietEndMin),
      );
}

/// Discrete voice-announcement events. Each can be individually toggled in
/// Settings (Set<VoiceEvent> on AppSettings). New enum values must be
/// appended, never reordered — index is persisted.
enum VoiceEvent {
  // Discovery / DX opportunities
  newCallCq,
  newGridCq,
  newCountryCq,
  notableDx,
  strongSignal,
  // Your QSO
  incomingCall,
  qsoLogged,
  qsoAbandoned,
  // Milestones
  firstCountry,
  firstGrid,
  personalBestDx,
  qsoCountMilestone,
  // Propagation / band
  bandOpening,
  solarFluxThreshold,
  greylineWindow,
  // System
  connectionLost,
  connectionRestored,
}

extension VoiceEventX on VoiceEvent {
  String get label => switch (this) {
        VoiceEvent.newCallCq => 'New callsign calls CQ',
        VoiceEvent.newGridCq => 'New grid calls CQ',
        VoiceEvent.newCountryCq => 'New DXCC country calls CQ',
        VoiceEvent.notableDx => 'Long-distance decode',
        VoiceEvent.strongSignal => 'Exceptionally strong signal',
        VoiceEvent.incomingCall => 'Someone calls me',
        VoiceEvent.qsoLogged => 'QSO logged',
        VoiceEvent.qsoAbandoned => 'QSO attempt abandoned',
        VoiceEvent.firstCountry => 'First contact with a new country',
        VoiceEvent.firstGrid => 'First contact from a new grid',
        VoiceEvent.personalBestDx => 'New personal-best DX distance',
        VoiceEvent.qsoCountMilestone => 'Round-number QSO milestone',
        VoiceEvent.bandOpening => 'Band opening detected',
        VoiceEvent.solarFluxThreshold => 'Solar flux threshold crossed',
        VoiceEvent.greylineWindow => 'Greyline window opens at my QTH',
        VoiceEvent.connectionLost => 'WSJT-CB disconnected',
        VoiceEvent.connectionRestored => 'WSJT-CB reconnected',
      };

  String get groupLabel => switch (this) {
        VoiceEvent.newCallCq ||
        VoiceEvent.newGridCq ||
        VoiceEvent.newCountryCq ||
        VoiceEvent.notableDx ||
        VoiceEvent.strongSignal =>
          'Discovery',
        VoiceEvent.incomingCall ||
        VoiceEvent.qsoLogged ||
        VoiceEvent.qsoAbandoned =>
          'My QSO',
        VoiceEvent.firstCountry ||
        VoiceEvent.firstGrid ||
        VoiceEvent.personalBestDx ||
        VoiceEvent.qsoCountMilestone =>
          'Milestones',
        VoiceEvent.bandOpening ||
        VoiceEvent.solarFluxThreshold ||
        VoiceEvent.greylineWindow =>
          'Propagation',
        VoiceEvent.connectionLost || VoiceEvent.connectionRestored => 'System',
      };
}

enum ThemeModePref { system, light, dark }

enum DistanceUnit { km, mi }

enum AppMode { cb, ham }

/// Direction bitmask for PSK Reporter spot layer.
enum PskSpotDirection { off, sent, received, both }

/// Basemap style shown behind markers on the Map screen.
enum MapStyle { regular, cbscopeRetro }

/// How far back to fetch PSK Reporter spots. `custom` uses
/// [AppSettings.pskSpotCustomMinutes] (1-60 min slider).
enum PskSpotWindow { custom, h1, h6, h24, d7 }

/// Default marker colors — Tron-flavoured neon on the dark map.
class MarkerColors {
  static const qso = Color(0xFF00E5FF); // electric cyan (accent)
  static const decode = Color(0xFFFFB000); // amber
  static const psk = Color(0xFFFF00AA); // magenta
  static const me = Color(0xFF00FF88); // bright green (my station stands out)
}

/// Preset palette shown in the color picker. Bright and distinct for a
/// dark map background.
const kMarkerPalette = <Color>[
  Color(0xFF00E5FF), // electric cyan
  Color(0xFF4DE0FF), // ice cyan
  Color(0xFF00FF88), // neon green
  Color(0xFFFFB000), // amber
  Color(0xFFFF6A00), // Tron orange (opposing signal)
  Color(0xFFFF00AA), // magenta
  Color(0xFFFF3B4E), // red
  Color(0xFFB565FF), // purple
  Color(0xFFFFFFFF), // white
];

extension PskSpotWindowX on PskSpotWindow {
  Duration get duration => switch (this) {
        PskSpotWindow.custom =>
          const Duration(minutes: 15), // fallback when settings absent
        PskSpotWindow.h1 => const Duration(hours: 1),
        PskSpotWindow.h6 => const Duration(hours: 6),
        PskSpotWindow.h24 => const Duration(hours: 24),
        PskSpotWindow.d7 => const Duration(days: 7),
      };
  String get label => switch (this) {
        PskSpotWindow.custom => 'Custom',
        PskSpotWindow.h1 => 'Last 1 h',
        PskSpotWindow.h6 => 'Last 6 h',
        PskSpotWindow.h24 => 'Last 24 h',
        PskSpotWindow.d7 => 'Last 7 d',
      };
}

extension DistanceUnitX on DistanceUnit {
  String get label => this == DistanceUnit.km ? 'km' : 'mi';
  double from(double km) => this == DistanceUnit.km ? km : km / 1.60934;
}

class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences prefs;
  SettingsController(this.prefs)
      : super(AppSettings(
          udpPort: prefs.getInt('udpPort') ?? 2237,
          bindAddress: prefs.getString('bindAddress') ?? '127.0.0.1',
          multicastGroup: prefs.getString('multicastGroup'),
          adifLogPath: prefs.getString('adifLogPath') ?? defaultWsjtxLogPath(),
          myCall: prefs.getString('myCall'),
          myGrid: prefs.getString('myGrid'),
          theme: ThemeModePref
              .values[prefs.getInt('theme') ?? ThemeModePref.dark.index],
          distanceUnit: DistanceUnit.values[prefs.getInt('distanceUnit') ?? 0],
          pskReporterLookup: prefs.getBool('pskReporterLookup') ?? true,
          appMode: AppMode.values[prefs.getInt('appMode') ?? 0],
          pskSpotDirection:
              PskSpotDirection.values[prefs.getInt('pskSpotDirection') ?? 0],
          pskSpotWindow: PskSpotWindow
              .values[prefs.getInt('pskSpotWindow') ?? PskSpotWindow.h6.index],
          pskSpotCustomMinutes:
              (prefs.getInt('pskSpotCustomMinutes') ?? 15).clamp(1, 60),
          autoImportWsjtLog: prefs.getBool('autoImportWsjtLog') ?? true,
          qsoColor: Color(prefs.getInt('color.qso') ?? MarkerColors.qso.value),
          decodeColor:
              Color(prefs.getInt('color.decode') ?? MarkerColors.decode.value),
          pskColor: Color(prefs.getInt('color.psk') ?? MarkerColors.psk.value),
          meColor: Color(prefs.getInt('color.me') ?? MarkerColors.me.value),
          mapStyle: MapStyle
              .values[prefs.getInt('mapStyle') ?? MapStyle.cbscopeRetro.index],
          mapGreylineEnabled: prefs.getBool('map.greylineEnabled') ?? false,
          themeAccent: prefs.containsKey('themeAccent')
              ? Color(prefs.getInt('themeAccent')!)
              : null,
          voiceEnabled: prefs.getBool('voice.enabled') ?? false,
          voiceEvents: _readVoiceEvents(prefs),
          voiceNotableDxKm: prefs.getInt('voice.notableDxKm') ?? 5000,
          voiceStrongSignalDb: prefs.getInt('voice.strongSignalDb') ?? 0,
          voiceSolarFluxSfi: prefs.getInt('voice.solarFluxSfi') ?? 150,
          voiceRateLimitPerMinute:
              (prefs.getInt('voice.rateLimitPerMinute') ?? 4).clamp(1, 20),
          voiceVolume:
              (prefs.getDouble('voice.volume') ?? 1.0).clamp(0.0, 1.0),
          voiceQuietStartMin: prefs.getInt('voice.quietStartMin'),
          voiceQuietEndMin: prefs.getInt('voice.quietEndMin'),
        ));

  /// Decode the stored comma-separated list of enabled voice-event indices.
  /// Falls back to [AppSettings.defaultOnEvents] when the key isn't present
  /// (fresh install), and to an empty set when the key exists but is empty
  /// (user explicitly disabled everything).
  static Set<VoiceEvent> _readVoiceEvents(SharedPreferences prefs) {
    if (!prefs.containsKey('voice.events')) {
      return AppSettings.defaultOnEvents;
    }
    final raw = prefs.getString('voice.events') ?? '';
    if (raw.isEmpty) return const {};
    return raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i >= 0 && i < VoiceEvent.values.length)
        .map((i) => VoiceEvent.values[i])
        .toSet();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await prefs.setInt('udpPort', next.udpPort);
    await prefs.setString('bindAddress', next.bindAddress);
    if (next.multicastGroup == null) {
      await prefs.remove('multicastGroup');
    } else {
      await prefs.setString('multicastGroup', next.multicastGroup!);
    }
    if (next.adifLogPath == null) {
      await prefs.remove('adifLogPath');
    } else {
      await prefs.setString('adifLogPath', next.adifLogPath!);
    }
    if (next.myCall != null) await prefs.setString('myCall', next.myCall!);
    if (next.myGrid != null) await prefs.setString('myGrid', next.myGrid!);
    await prefs.setInt('theme', next.theme.index);
    await prefs.setInt('distanceUnit', next.distanceUnit.index);
    await prefs.setBool('pskReporterLookup', next.pskReporterLookup);
    await prefs.setInt('appMode', next.appMode.index);
    await prefs.setInt('pskSpotDirection', next.pskSpotDirection.index);
    await prefs.setInt('pskSpotWindow', next.pskSpotWindow.index);
    await prefs.setInt('pskSpotCustomMinutes', next.pskSpotCustomMinutes);
    await prefs.setBool('autoImportWsjtLog', next.autoImportWsjtLog);
    await prefs.setInt('color.qso', next.qsoColor.value);
    await prefs.setInt('color.decode', next.decodeColor.value);
    await prefs.setInt('color.psk', next.pskColor.value);
    await prefs.setInt('color.me', next.meColor.value);
    await prefs.setInt('mapStyle', next.mapStyle.index);
    await prefs.setBool(
      'map.greylineEnabled',
      next.mapGreylineEnabled,
    );
    if (next.themeAccent == null) {
      await prefs.remove('themeAccent');
    } else {
      await prefs.setInt('themeAccent', next.themeAccent!.value);
    }
    await prefs.setBool('voice.enabled', next.voiceEnabled);
    await prefs.setString(
      'voice.events',
      next.voiceEvents.map((e) => e.index).join(','),
    );
    await prefs.setInt('voice.notableDxKm', next.voiceNotableDxKm);
    await prefs.setInt('voice.strongSignalDb', next.voiceStrongSignalDb);
    await prefs.setInt('voice.solarFluxSfi', next.voiceSolarFluxSfi);
    await prefs.setInt('voice.rateLimitPerMinute', next.voiceRateLimitPerMinute);
    await prefs.setDouble('voice.volume', next.voiceVolume);
    if (next.voiceQuietStartMin == null) {
      await prefs.remove('voice.quietStartMin');
    } else {
      await prefs.setInt('voice.quietStartMin', next.voiceQuietStartMin!);
    }
    if (next.voiceQuietEndMin == null) {
      await prefs.remove('voice.quietEndMin');
    } else {
      await prefs.setInt('voice.quietEndMin', next.voiceQuietEndMin!);
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(prefsProvider).requireValue;
  return SettingsController(prefs);
});

String? defaultWsjtxLogPath() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return null;
  // Try WSJT-CB first (11m community fork), fall back to stock WSJT-X.
  final candidates = <String>[];
  if (Platform.isMacOS) {
    candidates.addAll([
      p.join(
          home, 'Library', 'Application Support', 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(
          home, 'Library', 'Application Support', 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(home, 'Library', 'Application Support', 'WSJT-X', 'wsjtx_log.adi'),
    ]);
  } else if (Platform.isWindows) {
    final la = Platform.environment['LOCALAPPDATA'] ??
        p.join(home, 'AppData', 'Local');
    candidates.addAll([
      p.join(la, 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(la, 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(la, 'WSJT-X', 'wsjtx_log.adi'),
    ]);
  } else {
    candidates.addAll([
      p.join(home, '.local', 'share', 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(home, '.local', 'share', 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(home, '.local', 'share', 'WSJT-X', 'wsjtx_log.adi'),
    ]);
  }
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return candidates.first;
}

/// ---------------- UDP listener ----------------

final udpListenerProvider = Provider<UdpListenerService>((ref) {
  final s = ref.watch(settingsProvider);
  final svc = UdpListenerService(
    port: s.udpPort,
    bindAddress: s.bindAddress,
    multicastGroup: s.multicastGroup,
  );
  svc.start().catchError((e) {
    debugPrint('UDP bind failed: $e');
  });
  ref.onDispose(svc.dispose);
  return svc;
});

final wsjtxMessagesProvider = StreamProvider<WsjtxMessage>((ref) {
  return ref.watch(udpListenerProvider).messages;
});

final wsjtxStatusProvider =
    StateNotifierProvider<_StatusCtrl, WsjtxStatus?>((ref) {
  final ctrl = _StatusCtrl();
  ref.listen(wsjtxMessagesProvider, (_, next) {
    next.whenData((m) {
      if (m is WsjtxStatus) ctrl.set(m);
    });
  });
  return ctrl;
});

class _StatusCtrl extends StateNotifier<WsjtxStatus?> {
  _StatusCtrl() : super(null);
  void set(WsjtxStatus s) => state = s;
}

class LiveDecode {
  final WsjtxDecode decode;
  final DateTime receivedAt;
  const LiveDecode(this.decode, this.receivedAt);
}

final liveDecodesProvider =
    StateNotifierProvider<_DecodesCtrl, List<LiveDecode>>((ref) {
  final ctrl = _DecodesCtrl();
  ref.listen(wsjtxMessagesProvider, (_, next) {
    next.whenData((m) {
      if (m is WsjtxDecode) ctrl.add(m);
      if (m is WsjtxClear) ctrl.clear();
    });
  });
  return ctrl;
});

class _DecodesCtrl extends StateNotifier<List<LiveDecode>> {
  static const _maxLen = 400;
  final _q = Queue<LiveDecode>();
  _DecodesCtrl() : super(const []);
  void add(WsjtxDecode d) {
    _q.addFirst(LiveDecode(d, DateTime.now()));
    while (_q.length > _maxLen) {
      _q.removeLast();
    }
    state = List.unmodifiable(_q);
  }

  void clear() {
    _q.clear();
    state = const [];
  }
}

/// Bridge UDP → DB: QsoLogged messages are persisted. Decodes that carry
/// their own grid also feed the callsign→grid cache so future decodes from
/// the same station can be placed on the map even without a grid. Status
/// messages auto-populate the user's own call / grid the first time WSJT-CB
/// reports them, so the user doesn't have to re-type what WSJT-CB already
/// knows.
final qsoLoggedIngestProvider = Provider<void>((ref) {
  final repo = ref.watch(qsoRepoProvider);
  final resolver = ref.watch(callsignResolverProvider);
  ref.listen(wsjtxMessagesProvider, (_, next) {
    next.whenData((m) {
      if (m is WsjtxQsoLogged) {
        // Stamp the QSO with the current propagation snapshot so it's
        // remembered forever, not just what hamqsl reports today. Also
        // supply portable fallbacks from settings + a grid resolver so
        // CB QSOs never leave the DB with an empty locator.
        final solar = ref.read(solarDataProvider).valueOrNull;
        final s = ref.read(settingsProvider);
        final r = ref.read(callsignResolverProvider);
        repo.insertFromWsjtx(
          m,
          extraFields: _solarSnapshotFields(solar, DateTime.now().toUtc()),
          fallbackMyCall: s.myCall,
          fallbackMyGrid: s.myGrid,
          gridResolver: (call) => r.gridFor(call),
        );
      } else if (m is WsjtxDecode) {
        final call = m.stationCall();
        final grid = m.gridHint();
        if (call != null) {
          resolver.gridFor(call, seenGridHint: grid);
        }
      } else if (m is WsjtxStatus) {
        final s = ref.read(settingsProvider);
        final needsCall = (s.myCall == null || s.myCall!.trim().isEmpty) &&
            (m.deCall?.isNotEmpty ?? false);
        final needsGrid = (s.myGrid == null || s.myGrid!.trim().isEmpty) &&
            (m.deGrid?.isNotEmpty ?? false);
        if (needsCall || needsGrid) {
          ref.read(settingsProvider.notifier).update(s.copyWith(
                myCall: needsCall ? m.deCall!.toUpperCase() : s.myCall,
                myGrid: needsGrid ? m.deGrid!.toUpperCase() : s.myGrid,
              ));
        }
      }
    });
  });
});

/// ---------------- PSK Reporter + callsign resolver ----------------

final pskReporterClientProvider = Provider<PskReporterClient>((ref) {
  final c = PskReporterClient();
  ref.onDispose(c.close);
  return c;
});

final callsignResolverProvider =
    ChangeNotifierProvider<CallsignResolver>((ref) {
  final repo = ref.watch(qsoRepoProvider);
  final psk = ref.watch(pskReporterClientProvider);
  final resolver = CallsignResolver(
    repo: repo,
    psk: psk,
    pskEnabled: () => ref.read(settingsProvider).pskReporterLookup,
  );
  // Warm from DB at startup so map markers appear immediately.
  repo.db.select(repo.db.callsignGrids).get().then(resolver.warmFromDb);
  return resolver;
});

/// ---------------- Solar / propagation ----------------

final solarClientProvider = Provider<SolarClient>((ref) {
  final c = SolarClient();
  ref.onDispose(c.close);
  return c;
});

/// Polls hamqsl.com every 15 min. First fetch on startup.
final solarDataProvider = StreamProvider<SolarData?>((ref) async* {
  final c = ref.watch(solarClientProvider);
  yield await c.fetch();
  final t = Stream<void>.periodic(const Duration(minutes: 15));
  await for (final _ in t) {
    final d = await c.fetch();
    if (d != null) yield d;
  }
});

/// ---------------- PSK Reporter spots layer ----------------
///
/// Fetches spots involving the user's callsign from PSK Reporter. Refreshes
/// every 3 minutes while enabled. Returns an empty list when disabled or
/// when the user hasn't set a callsign yet.
final pskSpotsProvider = StreamProvider<List<PskSpot>>((ref) async* {
  final s = ref.watch(settingsProvider);
  if (s.pskSpotDirection == PskSpotDirection.off) {
    yield const [];
    return;
  }
  final call = s.myCall?.trim();
  if (call == null || call.isEmpty) {
    yield const [];
    return;
  }
  final client = ref.watch(pskReporterClientProvider);
  final repo = ref.watch(qsoRepoProvider);

  Duration windowFor(AppSettings s) => s.pskSpotWindow == PskSpotWindow.custom
      ? Duration(minutes: s.pskSpotCustomMinutes.clamp(1, 60))
      : s.pskSpotWindow.duration;

  List<PskDirection> directionsFor(AppSettings s) {
    final r = <PskDirection>[];
    if (s.pskSpotDirection == PskSpotDirection.sent ||
        s.pskSpotDirection == PskSpotDirection.both) r.add(PskDirection.sent);
    if (s.pskSpotDirection == PskSpotDirection.received ||
        s.pskSpotDirection == PskSpotDirection.both)
      r.add(PskDirection.received);
    return r;
  }

  // Read 7-day rolling cache back into PskSpot objects.
  Future<List<PskSpot>> readCache() async {
    final since = windowFor(s);
    final dirs = directionsFor(s);
    final all = <PskSpot>[];
    for (final d in dirs) {
      final rows = await repo.readCachedPskSpots(
          myCall: call, since: since, direction: d.name);
      for (final r in rows) {
        all.add(PskSpot(
          otherCall: r.otherCall,
          otherGrid: r.otherGrid,
          direction: d,
          at: r.at,
          freqHz: r.freqHz,
          snr: r.snr,
          mode: r.mode,
        ));
      }
    }
    return all;
  }

  // Fetch each direction independently and emit after every result. With
  // "Both" selected, a slow/failed receiver query must not hide the already
  // successful sender query.
  Stream<List<PskSpot>> fetchCycle() async* {
    final since = windowFor(s);
    final dirs = directionsFor(s);
    final combined = <String, PskSpot>{};
    void add(PskSpot p) {
      combined[
          '${p.otherCall}|${p.direction.name}|${p.at.millisecondsSinceEpoch}|${p.freqHz}'] = p;
    }

    for (final cached in await readCache()) {
      add(cached);
    }

    for (final dir in dirs) {
      try {
        final r =
            await client.fetchSpots(myCall: call, direction: dir, since: since);
        for (final spot in r) {
          add(spot);
        }
        await repo.cachePskSpots(
            call,
            dir.name,
            r.map((s) => (
                  otherCall: s.otherCall,
                  otherGrid: s.otherGrid,
                  at: s.at,
                  freqHz: s.freqHz,
                  snr: s.snr,
                  mode: s.mode
                )));
      } catch (e) {
        debugPrint(
            'PSK Reporter fetch failed ($dir): $e — falling back to cache');
      }
      final visible = combined.values.toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      yield visible;
    }
  }

  yield await readCache();
  await for (final spots in fetchCycle()) {
    yield spots;
  }
  final t = Stream<void>.periodic(const Duration(minutes: 5));
  await for (final _ in t) {
    await for (final spots in fetchCycle()) {
      yield spots;
    }
  }
});

/// ---------------- ADIF tail watcher ----------------

final adifTailProvider = Provider<AdifTailWatcher?>((ref) {
  final s = ref.watch(settingsProvider);
  // User can turn off the background ingest entirely.
  if (!s.autoImportWsjtLog) return null;
  final path = s.adifLogPath;
  if (path == null || !File(path).existsSync()) return null;
  final prefs = ref.watch(prefsProvider).requireValue;
  final offset = prefs.getInt('adifOffset:$path') ?? 0;
  final w = AdifTailWatcher(path, startOffset: offset);
  w.start();

  final repo = ref.read(qsoRepoProvider);
  final sub = w.events.listen((e) async {
    // Grab the freshest propagation snapshot for enrichment. This provider's
    // value is non-blocking: if the last fetch failed we simply skip the
    // enrichment for these records.
    final solarSnapshot = ref.read(solarDataProvider).valueOrNull;
    final settings = ref.read(settingsProvider);
    final resolver = ref.read(callsignResolverProvider);
    for (final r in e.records) {
      final enriched =
          _enrich(r, solar: solarSnapshot, ingestedAt: DateTime.now().toUtc());
      await repo.insertFromAdif(
        enriched,
        fallbackMyCall: settings.myCall,
        fallbackMyGrid: settings.myGrid,
        gridResolver: (call) => resolver.gridFor(call),
      );
    }
    await prefs.setInt('adifOffset:$path', e.newOffset);
  });

  ref.onDispose(() async {
    await sub.cancel();
    await w.dispose();
  });
  return w;
});

/// Returns a new [AdifRecord] with app-specific enrichment fields added
/// (namespaced under APP_QSOBOOK_*). The original ADIF fields are preserved
/// so subsequent re-exports round-trip cleanly.
AdifRecord _enrich(AdifRecord src,
    {SolarData? solar, required DateTime ingestedAt}) {
  final f = Map<String, String>.from(src.fields);
  f.addAll(_solarSnapshotFields(solar, ingestedAt));
  return AdifRecord(Map.unmodifiable(f));
}

/// Renders the current solar / propagation snapshot as a map of ADIF-style
/// `app_qsobook_*` fields suitable for merging into either an [AdifRecord]
/// or a UDP QSO's `raw_fields` JSON.
Map<String, String> _solarSnapshotFields(
    SolarData? solar, DateTime ingestedAt) {
  final f = <String, String>{
    'app_qsobook_ingested_at': ingestedAt.toIso8601String(),
  };
  if (solar == null) return f;
  if (solar.sfi != null) f['app_qsobook_sfi'] = solar.sfi!.toStringAsFixed(0);
  if (solar.kIndex != null)
    f['app_qsobook_k_index'] = solar.kIndex!.toStringAsFixed(1);
  if (solar.aIndex != null)
    f['app_qsobook_a_index'] = solar.aIndex!.toStringAsFixed(0);
  if (solar.sunspots != null)
    f['app_qsobook_sunspots'] = solar.sunspots!.toString();
  final cond =
      solar.twelveTenCondition(_isDaytimeUtc(ingestedAt) ? 'day' : 'night');
  if (cond != null) f['app_qsobook_band_condition'] = cond;
  return f;
}

/// Rough day/night switch based on UTC hour. This is a proxy: hamqsl feeds
/// day/night as *global* condition, not location-specific.
bool _isDaytimeUtc(DateTime utc) {
  final h = utc.hour;
  return h >= 6 && h < 18;
}

/// ---------------- Logbook / stats ----------------

typedef LogbookFilter = ({
  String? search,
  String? band,
  String? mode,
  int? antennaId,
  int? radioId,
  int? minRating,
  ReviewState? reviewState,
});

final logbookFilterProvider = StateProvider<LogbookFilter>((_) => (
      search: null,
      band: null,
      mode: null,
      antennaId: null,
      radioId: null,
      minRating: null,
      reviewState: null
    ));

final logbookProvider = StreamProvider<List<Qso>>((ref) {
  final repo = ref.watch(qsoRepoProvider);
  final f = ref.watch(logbookFilterProvider);
  return repo.watchAll(
    search: f.search,
    band: f.band,
    mode: f.mode,
    antennaId: f.antennaId,
    radioId: f.radioId,
    minRating: f.minRating,
    reviewState: f.reviewState,
  );
});

// ---------------- Equipment library ----------------

final antennasProvider = StreamProvider<List<Antenna>>(
    (ref) => ref.watch(qsoRepoProvider).watchAntennas());
final rigsProvider =
    StreamProvider<List<Rig>>((ref) => ref.watch(qsoRepoProvider).watchRigs());

// ---------------- Review queue ----------------

final needsReviewProvider = StreamProvider<List<Qso>>(
    (ref) => ref.watch(qsoRepoProvider).watchNeedsReview());
final needsReviewCountProvider = StreamProvider<int>(
    (ref) => ref.watch(qsoRepoProvider).watchNeedsReviewCount());

/// Cached set of every callsign already in our logbook. Drives the NEW-CQ
/// badge on live map decodes — recomputes whenever the logbook stream
/// emits (i.e. after every ingest).
final workedCallsignsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).workedCallsigns();
});

/// Set of every 4-char grid we've logged. Used by the voice pipeline to
/// spot the first decode from a never-heard grid square.
final workedGridsProvider = FutureProvider<Set<String>>((ref) async {
  final rows = ref.watch(logbookProvider).valueOrNull ?? const <Qso>[];
  final out = <String>{};
  for (final q in rows) {
    final g = q.gridsquare;
    if (g != null && g.length >= 4) out.add(g.substring(0, 4).toUpperCase());
  }
  return out;
});

/// Set of every DXCC country we've logged.
final workedCountriesProvider = FutureProvider<Set<String>>((ref) async {
  final rows = ref.watch(logbookProvider).valueOrNull ?? const <Qso>[];
  final out = <String>{};
  for (final q in rows) {
    final c = q.country;
    if (c != null && c.isNotEmpty) out.add(c);
  }
  return out;
});

final equipmentStatsProvider = FutureProvider<List<EquipmentStat>>((ref) async {
  ref.watch(logbookProvider);
  final s = ref.watch(settingsProvider);
  final me = s.myGrid == null ? null : _gridToLatLngPublic(s.myGrid!);
  return ref
      .watch(qsoRepoProvider)
      .equipmentStats(myLat: me?.$1, myLon: me?.$2);
});

final statsExtrasProvider = FutureProvider<StatsExtras>((ref) async {
  ref.watch(logbookProvider);
  final s = ref.watch(settingsProvider);
  final me = s.myGrid == null ? null : _gridToLatLngPublic(s.myGrid!);
  return ref.watch(qsoRepoProvider).extras(
        myLat: me?.$1,
        myLon: me?.$2,
      );
});

(double, double)? _gridToLatLngPublic(String g) {
  final gg = g.toUpperCase();
  if (gg.length < 4) return null;
  final f1 = gg.codeUnitAt(0) - 0x41, f2 = gg.codeUnitAt(1) - 0x41;
  final s1 = gg.codeUnitAt(2) - 0x30, s2 = gg.codeUnitAt(3) - 0x30;
  if (f1 < 0 ||
      f1 > 17 ||
      f2 < 0 ||
      f2 > 17 ||
      s1 < 0 ||
      s1 > 9 ||
      s2 < 0 ||
      s2 > 9) return null;
  return (-90 + f2 * 10 + s2 + 0.5, -180 + f1 * 20 + s1 * 2 + 1);
}

final allQsosProvider = FutureProvider<List<Qso>>((ref) async {
  // Rebuild whenever logbook changes.
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).all();
});

class Kpis {
  final int total;
  final int uniqueCalls;
  final int uniqueGrids;
  final int uniqueCountries;
  const Kpis(
      this.total, this.uniqueCalls, this.uniqueGrids, this.uniqueCountries);
}

final kpisProvider = FutureProvider<Kpis>((ref) async {
  ref.watch(logbookProvider);
  final r = ref.watch(qsoRepoProvider);
  final results = await Future.wait([
    r.countQsos(),
    r.countUniqueCalls(),
    r.countUniqueGrids(),
    r.countUniqueCountries(),
  ]);
  return Kpis(results[0], results[1], results[2], results[3]);
});

final qsoPerDayProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).qsosPerDay(days: 60);
});

final bandCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).countsBy('band');
});

final modeCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).countsBy('mode');
});

/// ---------------- ADIF drag-drop import ----------------

final adifImportProvider = Provider<Future<int> Function(String)>((ref) {
  final repo = ref.watch(qsoRepoProvider);
  final resolver = ref.watch(callsignResolverProvider);
  final s = ref.watch(settingsProvider);
  return (String path) async {
    final file = File(path);
    if (!file.existsSync()) return 0;
    final text = await file.readAsString();
    final records = AdifParser.parse(text);
    int n = 0;
    for (final r in records) {
      final rows = await repo.insertFromAdif(
        r,
        fallbackMyCall: s.myCall,
        fallbackMyGrid: s.myGrid,
        gridResolver: (call) => resolver.gridFor(call),
      );
      if (rows > 0) n++;
    }
    return n;
  };
});
