import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/util/cb_dxcc.dart';
import '../../core/util/dedup_key.dart';
import '../adif/adif_parser.dart';
import '../wsjtx/messages.dart';
import 'database.dart';

enum ReviewState { any, reviewed, unreviewed }

class EquipmentStat {
  final String name;
  final String kind; // 'Radio' | 'Antenna'
  final int qsoCount;
  final int uniqueGrids;
  final int uniqueCountries;
  final double? avgDistanceKm;
  final double? bestDxKm;
  final String? bestDxCall;
  final double? avgRstRcvd;
  const EquipmentStat({
    required this.name, required this.kind,
    required this.qsoCount, required this.uniqueGrids, required this.uniqueCountries,
    this.avgDistanceKm, this.bestDxKm, this.bestDxCall, this.avgRstRcvd,
  });
}

class _EquipAgg {
  final String label;
  final String kind;
  int qsoCount = 0;
  final Set<String> uniqueGrids = {};
  final Set<String> uniqueCountries = {};
  double sumDist = 0;
  int distCount = 0;
  double bestDx = 0;
  String? bestDxCall;
  int sumRst = 0;
  int rstCount = 0;
  _EquipAgg({required this.label, required this.kind});
}

class StatsExtras {
  final int? bestSnr;
  final Qso? bestSnrQso;
  final int? worstSnr;
  final Qso? worstSnrQso;
  final double? longestKm;
  final Qso? longestQso;
  const StatsExtras({
    this.bestSnr, this.bestSnrQso,
    this.worstSnr, this.worstSnrQso,
    this.longestKm, this.longestQso,
  });
}

// Inline geo helpers to keep the repository self-contained.
(double, double)? _gridToLatLng(String grid) {
  final g = grid.toUpperCase();
  if (g.length < 4) return null;
  final f1 = g.codeUnitAt(0) - 0x41, f2 = g.codeUnitAt(1) - 0x41;
  final s1 = g.codeUnitAt(2) - 0x30, s2 = g.codeUnitAt(3) - 0x30;
  if (f1 < 0 || f1 > 17 || f2 < 0 || f2 > 17 || s1 < 0 || s1 > 9 || s2 < 0 || s2 > 9) return null;
  double lon = (-180 + f1 * 20 + s1 * 2).toDouble();
  double lat = (-90 + f2 * 10 + s2).toDouble();
  double lonSz = 2.0, latSz = 1.0;
  if (g.length >= 6) {
    final ss1 = g.toLowerCase().codeUnitAt(4) - 0x61;
    final ss2 = g.toLowerCase().codeUnitAt(5) - 0x61;
    if (ss1 >= 0 && ss1 < 24 && ss2 >= 0 && ss2 < 24) {
      lon += ss1 * (2 / 24); lat += ss2 * (1 / 24);
      lonSz = 2 / 24; latSz = 1 / 24;
    }
  }
  return (lat + latSz / 2, lon + lonSz / 2);
}

double _greatCircleKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0088;
  double toRad(double d) => d * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class QsoRepository {
  final AppDatabase db;
  QsoRepository(this.db);

  /// Insert a QSO parsed from an ADIF record.
  ///
  /// [fallbackMyCall] / [fallbackMyGrid] come from user settings and are
  /// applied when the record itself doesn't carry a station call / QTH — so
  /// portable operation gets logged with the *current* locator even if
  /// WSJT-CB forgot to include it. [gridResolver] optionally fills in the
  /// DX gridsquare when the ADIF has none (typical for CB decodes) — pass
  /// `CallsignResolver.gridFor`.
  Future<int> insertFromAdif(
    AdifRecord r, {
    String? fallbackMyCall,
    String? fallbackMyGrid,
    String? Function(String call)? gridResolver,
  }) async {
    final t = r.timeOnUtc();
    if (t == null || r.call() == null || r.band() == null || r.mode() == null) return 0;
    final key = qsoDedupKey(
      call: r.call()!,
      timeOnUtc: t,
      band: r.band()!,
      mode: r.mode()!,
    );

    // Auto-enrichment: grid from resolver (PSK cache), country from CB prefix,
    // my_call/my_grid from settings.
    var grid = r.gridsquare();
    if ((grid == null || grid.length < 4) && gridResolver != null) {
      grid = gridResolver(r.call()!);
    }
    final country = (r.country() ?? '').isNotEmpty
        ? r.country()
        : countryFromCbCallsign(r.call()!);
    final myCall = (r.stationCallsign() ?? r.operator_() ?? '').isNotEmpty
        ? (r.stationCallsign() ?? r.operator_())
        : fallbackMyCall;
    final myGrid = (r.myGridsquare() ?? '').isNotEmpty ? r.myGridsquare() : fallbackMyGrid;

    // Persist enrichments back into rawFields so CSV export sees them.
    final enrichedFields = Map<String, String>.from(r.fields);
    if (grid != null    && grid.isNotEmpty)    enrichedFields['gridsquare']       = grid;
    if (country != null && country.isNotEmpty) enrichedFields['country']          = country;
    if (myCall != null  && myCall.isNotEmpty)  enrichedFields['station_callsign'] = myCall;
    if (myGrid != null  && myGrid.isNotEmpty)  enrichedFields['my_gridsquare']    = myGrid;

    final companion = QsosCompanion.insert(
      call: r.call()!.toUpperCase(),
      timeOn: t,
      timeOff: Value(r.timeOff() == null ? null : _mergeTime(r.qsoDate()!, r.timeOff()!)),
      band: r.band()!.toLowerCase(),
      mode: r.mode()!.toUpperCase(),
      submode: Value(r.submode()),
      freqMhz: Value(double.tryParse(r.freqMhz() ?? '')),
      rstSent: Value(r.rstSent()),
      rstRcvd: Value(r.rstRcvd()),
      gridsquare: Value(grid),
      myCall: Value(myCall),
      myGrid: Value(myGrid),
      name: Value(r.name()),
      country: Value(country),
      comment: Value(r.comment()),
      source: const Value('adif'),
      dedupKey: key,
      rawFields: Value(jsonEncode(enrichedFields)),
    );
    final n = await db.into(db.qsos).insert(companion, mode: InsertMode.insertOrIgnore);
    if (n > 0 && grid != null && grid.length >= 4) {
      await upsertCallsignGrid(r.call()!, grid, 'log');
    }
    return n;
  }

  Future<int> insertFromWsjtx(
    WsjtxQsoLogged m, {
    Map<String, String>? extraFields,
    String? fallbackMyCall,
    String? fallbackMyGrid,
    String? Function(String call)? gridResolver,
  }) async {
    final key = qsoDedupKey(
      call: m.dxCall,
      timeOnUtc: m.timeOn.toUtc(),
      band: freqToBand(m.txFrequency),
      mode: m.mode,
    );

    var dxGrid = m.dxGrid;
    if (dxGrid.length < 4 && gridResolver != null) {
      dxGrid = gridResolver(m.dxCall) ?? dxGrid;
    }
    final myCall = m.myCall.isNotEmpty ? m.myCall : (fallbackMyCall ?? '');
    final myGrid = m.myGrid.isNotEmpty ? m.myGrid : (fallbackMyGrid ?? '');
    final country = countryFromCbCallsign(m.dxCall);

    final raw = <String, String>{
      'call': m.dxCall,
      'gridsquare': dxGrid,
      'mode': m.mode,
      'rst_sent': m.reportSent,
      'rst_rcvd': m.reportReceived,
      'tx_pwr': m.txPower,
      'comment': m.comments,
      'name': m.name,
      'operator': m.opCall,
      'station_callsign': myCall,
      'my_gridsquare': myGrid,
      'srx_string': m.exchangeReceived,
      'stx_string': m.exchangeSent,
      if (country != null) 'country': country,
      if (m.adifPropagationMode != null) 'prop_mode': m.adifPropagationMode!,
      if (extraFields != null) ...extraFields,
    };
    final companion = QsosCompanion.insert(
      call: m.dxCall.toUpperCase(),
      timeOn: m.timeOn.toUtc(),
      timeOff: Value(m.timeOff.toUtc()),
      band: freqToBand(m.txFrequency).toLowerCase(),
      mode: m.mode.toUpperCase(),
      freqMhz: Value(m.txFrequency / 1e6),
      rstSent: Value(m.reportSent),
      rstRcvd: Value(m.reportReceived),
      gridsquare: Value(dxGrid),
      myCall: Value(myCall),
      myGrid: Value(myGrid),
      name: Value(m.name),
      country: Value(country),
      comment: Value(m.comments),
      source: const Value('udp'),
      dedupKey: key,
      rawFields: Value(jsonEncode(raw)),
    );
    final n = await db.into(db.qsos).insert(companion, mode: InsertMode.insertOrIgnore);
    if (n > 0 && dxGrid.length >= 4) {
      await upsertCallsignGrid(m.dxCall, dxGrid, 'log');
    }
    return n;
  }

  /// Insert or update a cached callsign → grid mapping.
  Future<void> upsertCallsignGrid(String call, String grid, String source) async {
    await db.into(db.callsignGrids).insertOnConflictUpdate(CallsignGridsCompanion(
      call: Value(call.toUpperCase()),
      grid: Value(grid.toUpperCase()),
      source: Value(source),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<CallsignGrid?> lookupCallsignGrid(String call) async {
    return (db.select(db.callsignGrids)..where((t) => t.call.equals(call.toUpperCase())))
        .getSingleOrNull();
  }

  /// Fill in `gridsquare` on any existing QSO for [call] that was imported
  /// without a locator. Called after an async PSK Reporter lookup succeeds,
  /// so review cards get their grid populated once the network catches up.
  /// Never overwrites a grid that's already set (user or ADIF wins).
  Future<int> backfillMissingGrid({required String call, required String grid}) {
    final g = grid.toUpperCase();
    return (db.update(db.qsos)
          ..where((t) =>
              t.call.equals(call.toUpperCase()) &
              (t.gridsquare.isNull() | t.gridsquare.equals(''))))
        .write(QsosCompanion(gridsquare: Value(g)));
  }

  /// One-shot cleanup for rows created before `freqToBand` learned about
  /// 11 m: the UDP path stamped band as e.g. `27.245mhz`, while the ADIF
  /// tail wrote `11m` for the same QSO. That mismatch defeated the dedup
  /// key and left duplicate rows in review. We normalise the stray label,
  /// rebuild the dedup key, and drop any row whose corrected key collides
  /// with an existing `11m` twin (keeping the older/canonical row).
  Future<void> repairCbBandDuplicates() async {
    // LIKE is case-insensitive in SQLite for ASCII, so both `27.245MHz` and
    // `27.245mhz` variants match.
    final rows = await (db.select(db.qsos)
          ..where((t) => t.band.like('%mhz')))
        .get();
    for (final q in rows) {
      final f = q.freqMhz;
      if (f == null || f < 26.9 || f >= 27.5) continue;
      final newKey = qsoDedupKey(
        call: q.call, timeOnUtc: q.timeOn, band: '11m', mode: q.mode,
      );
      final twin = await (db.select(db.qsos)
            ..where((t) => t.dedupKey.equals(newKey) & t.id.equals(q.id).not()))
          .getSingleOrNull();
      if (twin != null) {
        await (db.delete(db.qsos)..where((t) => t.id.equals(q.id))).go();
      } else {
        await (db.update(db.qsos)..where((t) => t.id.equals(q.id))).write(
          QsosCompanion(band: const Value('11m'), dedupKey: Value(newKey)),
        );
      }
    }
  }

  // ---------------- Equipment library ----------------

  Stream<List<Antenna>> watchAntennas() =>
      (db.select(db.antennas)..where((t) => t.archived.equals(false))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<Rig>> watchRigs() =>
      (db.select(db.rigs)..where((t) => t.archived.equals(false))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> addAntenna({required String name, String? description, String? kind, double? gainDbi}) =>
      db.into(db.antennas).insert(AntennasCompanion.insert(
            name: name,
            description: Value(description),
            kind: Value(kind),
            gainDbi: Value(gainDbi),
          ));

  Future<int> addRig({required String name, String? description, int? maxPowerW}) =>
      db.into(db.rigs).insert(RigsCompanion.insert(
            name: name,
            description: Value(description),
            maxPowerW: Value(maxPowerW),
          ));

  Future<void> archiveAntenna(int id) =>
      (db.update(db.antennas)..where((t) => t.id.equals(id))).write(const AntennasCompanion(archived: Value(true)));
  Future<void> archiveRig(int id) =>
      (db.update(db.rigs)..where((t) => t.id.equals(id))).write(const RigsCompanion(archived: Value(true)));

  // ---------------- Review / enrichment ----------------

  /// Stream of QSOs that still need user review (never enriched with radio /
  /// antenna / notes). Newest first.
  Stream<List<Qso>> watchNeedsReview({int limit = 500}) {
    return (db.select(db.qsos)
          ..where((t) => t.reviewedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.timeOn)])
          ..limit(limit))
        .watch();
  }

  /// Reactive count of unreviewed QSOs (drives the sidebar badge).
  Stream<int> watchNeedsReviewCount() {
    final q = db.customSelect(
      'SELECT COUNT(*) AS c FROM qsos WHERE reviewed_at IS NULL',
      readsFrom: {db.qsos},
    );
    return q.watch().map((rows) => rows.isEmpty ? 0 : rows.first.read<int>('c'));
  }

  Future<void> updateEnrichment(
    int qsoId, {
    int? antennaId,
    int? radioId,
    String? personalNotes,
    int? rating,
    String? gridsquare,
    bool markReviewed = false,
    bool clearAntenna = false,
    bool clearRadio = false,
  }) {
    return (db.update(db.qsos)..where((t) => t.id.equals(qsoId))).write(QsosCompanion(
      antennaId:      clearAntenna ? const Value(null) : (antennaId != null ? Value(antennaId) : const Value.absent()),
      radioId:        clearRadio   ? const Value(null) : (radioId   != null ? Value(radioId)   : const Value.absent()),
      personalNotes:  personalNotes != null ? Value(personalNotes) : const Value.absent(),
      rating:         rating != null ? Value(rating) : const Value.absent(),
      gridsquare:     gridsquare != null ? Value(gridsquare) : const Value.absent(),
      reviewedAt:     markReviewed ? Value(DateTime.now().toUtc()) : const Value.absent(),
    ));
  }

  Future<void> markReviewed(int qsoId) => updateEnrichment(qsoId, markReviewed: true);

  Future<void> unmarkReviewed(int qsoId) =>
      (db.update(db.qsos)..where((t) => t.id.equals(qsoId))).write(const QsosCompanion(reviewedAt: Value(null)));

  /// Permanently delete a QSO. Callsign→grid cache is left alone since it's
  /// shared across many QSOs for the same call.
  Future<int> deleteQso(int qsoId) =>
      (db.delete(db.qsos)..where((t) => t.id.equals(qsoId))).go();

  Stream<List<Qso>> watchAll({
    int limit = 500,
    String? search,
    String? band,
    String? mode,
    int? antennaId,
    int? radioId,
    int? minRating,
    ReviewState? reviewState,
  }) {
    final q = db.select(db.qsos)..orderBy([(t) => OrderingTerm.desc(t.timeOn)]);
    if (search != null && search.isNotEmpty) {
      final s = '%${search.toUpperCase()}%';
      q.where((t) => t.call.upper().like(s));
    }
    if (band != null) q.where((t) => t.band.equals(band.toLowerCase()));
    if (mode != null) q.where((t) => t.mode.equals(mode.toUpperCase()));
    if (antennaId != null) q.where((t) => t.antennaId.equals(antennaId));
    if (radioId != null) q.where((t) => t.radioId.equals(radioId));
    if (minRating != null && minRating > 0) q.where((t) => t.rating.isBiggerOrEqualValue(minRating));
    switch (reviewState) {
      case ReviewState.reviewed:   q.where((t) => t.reviewedAt.isNotNull()); break;
      case ReviewState.unreviewed: q.where((t) => t.reviewedAt.isNull());    break;
      case ReviewState.any:
      case null:                                                             break;
    }
    q.limit(limit);
    return q.watch();
  }

  Future<List<Qso>> all() => db.select(db.qsos).get();

  /// Full CSV dump of the local logbook. Automatically includes every column
  /// currently on the `qsos` table (so future schema additions appear here
  /// without touching this code) plus a resolved `radio_name`, `antenna_name`
  /// join and the entire `raw_fields` JSON blob so this is a complete backup.
  ///
  /// Header row is always emitted; empty cells stay empty; embedded commas /
  /// quotes / newlines are quoted per RFC 4180.
  Future<String> exportLogbookCsv() async {
    final qsos     = await db.select(db.qsos).get();
    final antennas = {for (final a in await db.select(db.antennas).get()) a.id: a.name};
    final rigs     = {for (final r in await db.select(db.rigs).get()) r.id: r.name};

    // Discover every column dynamically off the generated table description so
    // this stays honest as we add more fields later.
    final cols = <String>[
      for (final c in db.qsos.$columns) c.name,
      'radio_name',
      'antenna_name',
    ];

    String cell(Object? v) {
      if (v == null) return '';
      String s;
      if (v is DateTime) {
        s = v.toUtc().toIso8601String();
      } else {
        s = v.toString();
      }
      final needsQuote = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
      if (!needsQuote) return s;
      return '"${s.replaceAll('"', '""')}"';
    }

    final buf = StringBuffer();
    buf.writeln(cols.map(cell).join(','));
    for (final q in qsos) {
      final row = q.toColumns(false); // column name → Expression
      final values = <Object?>[];
      for (final c in db.qsos.$columns) {
        final expr = row[c.name];
        // Companion values wrap the raw value in `Variable(value)`.
        values.add(expr is Variable ? expr.value : null);
      }
      values.add(q.radioId    == null ? null : rigs[q.radioId!]     ?? '(deleted)');
      values.add(q.antennaId  == null ? null : antennas[q.antennaId!] ?? '(deleted)');
      buf.writeln(values.map(cell).join(','));
    }
    return buf.toString();
  }

  Future<int> countQsos() async {
    final row = await db.customSelect('SELECT COUNT(*) AS c FROM qsos').getSingle();
    return row.read<int>('c');
  }

  Future<int> countUniqueCalls() async {
    final row = await db.customSelect('SELECT COUNT(DISTINCT call) AS c FROM qsos').getSingle();
    return row.read<int>('c');
  }

  Future<int> countUniqueGrids() async {
    final row = await db.customSelect(
      'SELECT COUNT(DISTINCT SUBSTR(gridsquare,1,4)) AS c FROM qsos WHERE gridsquare IS NOT NULL AND LENGTH(gridsquare) >= 4',
    ).getSingle();
    return row.read<int>('c');
  }

  Future<int> countUniqueCountries() async {
    final row = await db.customSelect(
      "SELECT COUNT(DISTINCT country) AS c FROM qsos WHERE country IS NOT NULL AND country != ''", // ignore: prefer_single_quotes
    ).getSingle();
    return row.read<int>('c');
  }

  Future<Map<String, int>> qsosPerDay({int days = 30}) async {
    // Drift stores DateTime as INTEGER unix seconds by default → need 'unixepoch'.
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;
    final rows = await db.customSelect(
      "SELECT strftime('%Y-%m-%d', time_on, 'unixepoch') AS d, COUNT(*) AS c FROM qsos WHERE time_on >= ? GROUP BY d ORDER BY d", // ignore: prefer_single_quotes
      variables: [Variable.withInt(cutoff)],
    ).get();
    final out = <String, int>{};
    for (final r in rows) {
      final d = r.read<String?>('d');
      if (d == null) continue;
      out[d] = r.read<int>('c');
    }
    return out;
  }

  Future<Map<String, int>> countsBy(String column) async {
    final rows = await db.customSelect(
      'SELECT $column AS k, COUNT(*) AS c FROM qsos GROUP BY k ORDER BY c DESC',
    ).get();
    return {for (final r in rows) (r.read<String?>('k') ?? 'Unknown'): r.read<int>('c')};
  }

  // ---------------- PSK Reporter spot cache (7-day rolling) ----------------

  Future<void> cachePskSpots(String myCall, String direction, Iterable<({
    String otherCall, String otherGrid, DateTime at, int freqHz, int snr, String mode,
  })> spots) async {
    // Prune anything older than 7 days first — keeps the table bounded.
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
    await (db.delete(db.pskSpotsCache)..where((t) => t.fetchedAt.isSmallerThanValue(cutoff))).go();
    await db.batch((b) {
      for (final s in spots) {
        final key = '${myCall.toUpperCase()}|${s.otherCall.toUpperCase()}|$direction|${s.at.millisecondsSinceEpoch}|${s.freqHz}';
        b.insert(db.pskSpotsCache, PskSpotsCacheCompanion.insert(
          myCall: myCall.toUpperCase(),
          otherCall: s.otherCall.toUpperCase(),
          otherGrid: s.otherGrid.toUpperCase(),
          direction: direction,
          at: s.at,
          freqHz: s.freqHz,
          snr: s.snr,
          mode: s.mode,
          dedupKey: key,
        ), mode: InsertMode.insertOrIgnore);
      }
    });
  }

  /// Read cached spots for [myCall] within the [since] window regardless of
  /// [direction] ('sent', 'received', or `null` for both).
  Future<List<PskSpotsCacheData>> readCachedPskSpots({
    required String myCall,
    required Duration since,
    String? direction,
  }) async {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(since);
    final q = db.select(db.pskSpotsCache)
      ..where((t) => t.myCall.equals(myCall.toUpperCase()) & t.at.isBiggerOrEqualValue(cutoff));
    if (direction != null) q.where((t) => t.direction.equals(direction));
    q.orderBy([(t) => OrderingTerm.desc(t.at)]);
    return q.get();
  }

  Future<List<Qso>> qsosByCall(String call) async {
    final s = call.toUpperCase();
    return (db.select(db.qsos)
          ..where((t) => t.call.equals(s))
          ..orderBy([(t) => OrderingTerm.desc(t.timeOn)]))
        .get();
  }

  /// Equipment-comparison stats. Groups the current logbook by radio + by
  /// antenna and rolls up: QSO count, unique 4-char grids, unique countries,
  /// avg distance from [myLat]/[myLon], and best DX distance.
  Future<List<EquipmentStat>> equipmentStats({
    required double? myLat, required double? myLon,
  }) async {
    final antennas = {for (final a in await db.select(db.antennas).get()) a.id: a.name};
    final rigs     = {for (final r in await db.select(db.rigs).get()) r.id: r.name};
    final qsos = await all();

    final Map<String, _EquipAgg> aggs = {};
    void tally(String key, String label, String kind, Qso q) {
      final agg = aggs.putIfAbsent(key, () => _EquipAgg(label: label, kind: kind));
      agg.qsoCount += 1;
      if (q.gridsquare != null && q.gridsquare!.length >= 4) {
        agg.uniqueGrids.add(q.gridsquare!.substring(0, 4).toUpperCase());
      }
      if (q.country != null && q.country!.isNotEmpty) agg.uniqueCountries.add(q.country!);
      if (myLat != null && myLon != null && q.gridsquare != null && q.gridsquare!.length >= 4) {
        final ll = _gridToLatLng(q.gridsquare!);
        if (ll != null) {
          final d = _greatCircleKm(myLat, myLon, ll.$1, ll.$2);
          agg.sumDist += d;
          agg.distCount += 1;
          if (d > agg.bestDx) { agg.bestDx = d; agg.bestDxCall = q.call; }
        }
      }
      final r = q.rstRcvd?.trim();
      if (r != null && r.isNotEmpty) {
        final n = int.tryParse(r.replaceAll(RegExp(r'[^-0-9]'), ''));
        if (n != null) { agg.sumRst += n; agg.rstCount += 1; }
      }
    }

    for (final q in qsos) {
      if (q.radioId != null) {
        tally('rig:${q.radioId}', rigs[q.radioId!] ?? '(deleted)', 'Radio', q);
      }
      if (q.antennaId != null) {
        tally('ant:${q.antennaId}', antennas[q.antennaId!] ?? '(deleted)', 'Antenna', q);
      }
    }

    return aggs.values.map((a) => EquipmentStat(
      name: a.label,
      kind: a.kind,
      qsoCount: a.qsoCount,
      uniqueGrids: a.uniqueGrids.length,
      uniqueCountries: a.uniqueCountries.length,
      avgDistanceKm: a.distCount > 0 ? a.sumDist / a.distCount : null,
      bestDxKm: a.bestDx == 0 ? null : a.bestDx,
      bestDxCall: a.bestDxCall,
      avgRstRcvd: a.rstCount > 0 ? a.sumRst / a.rstCount : null,
    )).toList()
      ..sort((x, y) => y.qsoCount.compareTo(x.qsoCount));
  }

  /// Unique callsigns in the logbook. Cheap lookup for NEW-CQ detection on
  /// the live map.
  Future<Set<String>> workedCallsigns() async {
    final rows = await db.customSelect('SELECT DISTINCT call FROM qsos').get();
    return {for (final r in rows) r.read<String>('call').toUpperCase()};
  }

  /// Interesting extras for the stats page — computed on demand so we don't
  /// keep them in a separate table.
  Future<StatsExtras> extras({
    required double? myLat, required double? myLon,
  }) async {
    // Highest and lowest RST received (numeric — first token, integer parse).
    int? bestSnr, worstSnr;
    Qso? bestSnrQso, worstSnrQso;
    // Longest distance QSO (computed against the user's grid if provided).
    double? longestKm;
    Qso? longestQso;

    final qsos = await all();
    for (final q in qsos) {
      final rst = q.rstRcvd?.trim();
      if (rst != null && rst.isNotEmpty) {
        final n = int.tryParse(rst.replaceAll(RegExp(r'[^-0-9]'), ''));
        if (n != null) {
          if (bestSnr  == null || n > bestSnr)  { bestSnr  = n; bestSnrQso  = q; }
          if (worstSnr == null || n < worstSnr) { worstSnr = n; worstSnrQso = q; }
        }
      }
      if (myLat != null && myLon != null && q.gridsquare != null && q.gridsquare!.length >= 4) {
        final ll = _gridToLatLng(q.gridsquare!);
        if (ll != null) {
          final d = _greatCircleKm(myLat, myLon, ll.$1, ll.$2);
          if (longestKm == null || d > longestKm) { longestKm = d; longestQso = q; }
        }
      }
    }
    return StatsExtras(
      bestSnr: bestSnr, bestSnrQso: bestSnrQso,
      worstSnr: worstSnr, worstSnrQso: worstSnrQso,
      longestKm: longestKm, longestQso: longestQso,
    );
  }

  static DateTime _mergeTime(String yyyymmdd, String hhmm) {
    final y = int.parse(yyyymmdd.substring(0, 4));
    final mo = int.parse(yyyymmdd.substring(4, 6));
    final d = int.parse(yyyymmdd.substring(6, 8));
    final hh = int.parse(hhmm.substring(0, 2));
    final mm = int.parse(hhmm.substring(2, 4));
    final ss = hhmm.length >= 6 ? int.parse(hhmm.substring(4, 6)) : 0;
    return DateTime.utc(y, mo, d, hh, mm, ss);
  }
}
