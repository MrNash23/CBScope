import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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

final qsoRepoProvider = Provider<QsoRepository>((ref) => QsoRepository(ref.watch(dbProvider)));

final prefsProvider = FutureProvider<SharedPreferences>((_) => SharedPreferences.getInstance());

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
  });

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
    bool clearMulticast = false,
    bool clearAdifPath = false,
  }) =>
      AppSettings(
        udpPort: udpPort ?? this.udpPort,
        bindAddress: bindAddress ?? this.bindAddress,
        multicastGroup: clearMulticast ? null : (multicastGroup ?? this.multicastGroup),
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
        qsoColor:    qsoColor    ?? this.qsoColor,
        decodeColor: decodeColor ?? this.decodeColor,
        pskColor:    pskColor    ?? this.pskColor,
        meColor:     meColor     ?? this.meColor,
        mapStyle:    mapStyle    ?? this.mapStyle,
      );
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

/// Default marker colors — bright, distinct, retro-terminal palette.
class MarkerColors {
  static const qso    = Color(0xFF49FF7A); // mint green (accent)
  static const decode = Color(0xFFFFB000); // amber
  static const psk    = Color(0xFFFF00AA); // magenta
  static const me     = Color(0xFF00FFCC); // teal (secondary)
}

/// Preset palette shown in the color picker. Bright and distinct for a
/// dark map background.
const kMarkerPalette = <Color>[
  Color(0xFF49FF7A), // mint
  Color(0xFF00FFCC), // teal
  Color(0xFFFFB000), // amber
  Color(0xFFFF00AA), // magenta
  Color(0xFFFF3B4E), // red
  Color(0xFF4AA3FF), // sky
  Color(0xFFB565FF), // purple
  Color(0xFFFFE44D), // yellow
  Color(0xFFFFFFFF), // white
];

extension PskSpotWindowX on PskSpotWindow {
  Duration get duration => switch (this) {
        PskSpotWindow.custom => const Duration(minutes: 15), // fallback when settings absent
        PskSpotWindow.h1  => const Duration(hours: 1),
        PskSpotWindow.h6  => const Duration(hours: 6),
        PskSpotWindow.h24 => const Duration(hours: 24),
        PskSpotWindow.d7  => const Duration(days: 7),
      };
  String get label => switch (this) {
        PskSpotWindow.custom => 'Custom',
        PskSpotWindow.h1  => 'Last 1 h',
        PskSpotWindow.h6  => 'Last 6 h',
        PskSpotWindow.h24 => 'Last 24 h',
        PskSpotWindow.d7  => 'Last 7 d',
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
          theme: ThemeModePref.values[prefs.getInt('theme') ?? ThemeModePref.dark.index],
          distanceUnit: DistanceUnit.values[prefs.getInt('distanceUnit') ?? 0],
          pskReporterLookup: prefs.getBool('pskReporterLookup') ?? true,
          appMode: AppMode.values[prefs.getInt('appMode') ?? 0],
          pskSpotDirection: PskSpotDirection.values[prefs.getInt('pskSpotDirection') ?? 0],
          pskSpotWindow: PskSpotWindow.values[prefs.getInt('pskSpotWindow') ?? PskSpotWindow.h6.index],
          pskSpotCustomMinutes: (prefs.getInt('pskSpotCustomMinutes') ?? 15).clamp(1, 60),
          autoImportWsjtLog: prefs.getBool('autoImportWsjtLog') ?? true,
          qsoColor:    Color(prefs.getInt('color.qso')    ?? MarkerColors.qso.value),
          decodeColor: Color(prefs.getInt('color.decode') ?? MarkerColors.decode.value),
          pskColor:    Color(prefs.getInt('color.psk')    ?? MarkerColors.psk.value),
          meColor:     Color(prefs.getInt('color.me')     ?? MarkerColors.me.value),
          mapStyle:    MapStyle.values[prefs.getInt('mapStyle') ?? MapStyle.cbscopeRetro.index],
        ));

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
    await prefs.setInt('color.qso',    next.qsoColor.value);
    await prefs.setInt('color.decode', next.decodeColor.value);
    await prefs.setInt('color.psk',    next.pskColor.value);
    await prefs.setInt('color.me',     next.meColor.value);
    await prefs.setInt('mapStyle',     next.mapStyle.index);
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(prefsProvider).requireValue;
  return SettingsController(prefs);
});

String? defaultWsjtxLogPath() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return null;
  // Try WSJT-CB first (11m community fork), fall back to stock WSJT-X.
  final candidates = <String>[];
  if (Platform.isMacOS) {
    candidates.addAll([
      p.join(home, 'Library', 'Application Support', 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(home, 'Library', 'Application Support', 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(home, 'Library', 'Application Support', 'WSJT-X',  'wsjtx_log.adi'),
    ]);
  } else if (Platform.isWindows) {
    final la = Platform.environment['LOCALAPPDATA'] ?? p.join(home, 'AppData', 'Local');
    candidates.addAll([
      p.join(la, 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(la, 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(la, 'WSJT-X',  'wsjtx_log.adi'),
    ]);
  } else {
    candidates.addAll([
      p.join(home, '.local', 'share', 'WSJT-CB', 'wsjtcb_log.adi'),
      p.join(home, '.local', 'share', 'WSJT-CB', 'wsjtx_log.adi'),
      p.join(home, '.local', 'share', 'WSJT-X',  'wsjtx_log.adi'),
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

final wsjtxStatusProvider = StateNotifierProvider<_StatusCtrl, WsjtxStatus?>((ref) {
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

final liveDecodesProvider = StateNotifierProvider<_DecodesCtrl, List<LiveDecode>>((ref) {
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
  void clear() { _q.clear(); state = const []; }
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
        repo.insertFromWsjtx(m);
      } else if (m is WsjtxDecode) {
        final call = m.cqCall();
        final grid = m.cqGrid();
        if (call != null) {
          resolver.gridFor(call, seenGridHint: grid);
        }
      } else if (m is WsjtxStatus) {
        final s = ref.read(settingsProvider);
        final needsCall = (s.myCall == null || s.myCall!.trim().isEmpty) && (m.deCall?.isNotEmpty ?? false);
        final needsGrid = (s.myGrid == null || s.myGrid!.trim().isEmpty) && (m.deGrid?.isNotEmpty ?? false);
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

final callsignResolverProvider = ChangeNotifierProvider<CallsignResolver>((ref) {
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
  debugPrint('[psk] provider run: dir=${s.pskSpotDirection} call=${s.myCall} window=${s.pskSpotWindow.label}');
  if (s.pskSpotDirection == PskSpotDirection.off) { yield const []; return; }
  final call = s.myCall?.trim();
  if (call == null || call.isEmpty) {
    print('[psk] no callsign — set myCall in Settings'); // ignore: avoid_print
    yield const [];
    return;
  }
  final client = ref.watch(pskReporterClientProvider);

  Future<List<PskSpot>> fetchAll() async {
    final directions = <PskDirection>[];
    if (s.pskSpotDirection == PskSpotDirection.sent     || s.pskSpotDirection == PskSpotDirection.both) directions.add(PskDirection.sent);
    if (s.pskSpotDirection == PskSpotDirection.received || s.pskSpotDirection == PskSpotDirection.both) directions.add(PskDirection.received);
    final all = <PskSpot>[];
    for (final dir in directions) {
      try {
        final since = s.pskSpotWindow == PskSpotWindow.custom
            ? Duration(minutes: s.pskSpotCustomMinutes.clamp(1, 60))
            : s.pskSpotWindow.duration;
        final r = await client.fetchSpots(myCall: call, direction: dir, since: since);
        print('[psk] got ${r.length} spots for dir=$dir'); // ignore: avoid_print
        all.addAll(r);
      } catch (e, st) {
        print('[psk] fetch failed: $e\n$st'); // ignore: avoid_print
      }
    }
    return all;
  }

  yield await fetchAll();
  final t = Stream<void>.periodic(const Duration(minutes: 5));
  await for (final _ in t) {
    yield await fetchAll();
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
    for (final r in e.records) {
      final enriched = _enrich(r, solar: solarSnapshot, ingestedAt: DateTime.now().toUtc());
      await repo.insertFromAdif(enriched);
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
AdifRecord _enrich(AdifRecord src, {SolarData? solar, required DateTime ingestedAt}) {
  final f = Map<String, String>.from(src.fields);
  f['app_qsobook_ingested_at'] = ingestedAt.toIso8601String();
  if (solar != null) {
    if (solar.sfi     != null) f['app_qsobook_sfi']     = solar.sfi!.toStringAsFixed(0);
    if (solar.kIndex  != null) f['app_qsobook_k_index'] = solar.kIndex!.toStringAsFixed(1);
    if (solar.aIndex  != null) f['app_qsobook_a_index'] = solar.aIndex!.toStringAsFixed(0);
    if (solar.sunspots != null) f['app_qsobook_sunspots'] = solar.sunspots!.toString();
    final cond = solar.twelveTenCondition(_isDaytimeUtc(ingestedAt) ? 'day' : 'night');
    if (cond != null) f['app_qsobook_band_condition'] = cond;
  }
  return AdifRecord(Map.unmodifiable(f));
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

final logbookFilterProvider = StateProvider<LogbookFilter>((_) =>
    (search: null, band: null, mode: null, antennaId: null, radioId: null, minRating: null, reviewState: null));

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

final antennasProvider = StreamProvider<List<Antenna>>((ref) => ref.watch(qsoRepoProvider).watchAntennas());
final rigsProvider     = StreamProvider<List<Rig>>((ref) => ref.watch(qsoRepoProvider).watchRigs());

// ---------------- Review queue ----------------

final needsReviewProvider = StreamProvider<List<Qso>>((ref) => ref.watch(qsoRepoProvider).watchNeedsReview());
final needsReviewCountProvider = StreamProvider<int>((ref) => ref.watch(qsoRepoProvider).watchNeedsReviewCount());

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
  const Kpis(this.total, this.uniqueCalls, this.uniqueGrids, this.uniqueCountries);
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

/// Freq histogram (kHz bins) — CB-optimized alternative to the band donut,
/// since on 11m most activity happens within a handful of kHz of 27.245.
final freqHistogramProvider = FutureProvider<Map<int, int>>((ref) async {
  ref.watch(logbookProvider);
  return ref.watch(qsoRepoProvider).freqHistogramKhz(binKhz: 5);
});

/// ---------------- ADIF drag-drop import ----------------

final adifImportProvider = Provider<Future<int> Function(String)>((ref) {
  final repo = ref.watch(qsoRepoProvider);
  return (String path) async {
    final file = File(path);
    if (!file.existsSync()) return 0;
    final text = await file.readAsString();
    final records = AdifParser.parse(text);
    int n = 0;
    for (final r in records) {
      final rows = await repo.insertFromAdif(r);
      if (rows > 0) n++;
    }
    return n;
  };
});

