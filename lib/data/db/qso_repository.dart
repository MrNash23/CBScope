import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/util/dedup_key.dart';
import '../adif/adif_parser.dart';
import '../wsjtx/messages.dart';
import 'database.dart';

enum ReviewState { any, reviewed, unreviewed }

class QsoRepository {
  final AppDatabase db;
  QsoRepository(this.db);

  Future<int> insertFromAdif(AdifRecord r) async {
    final t = r.timeOnUtc();
    if (t == null || r.call() == null || r.band() == null || r.mode() == null) return 0;
    final key = qsoDedupKey(
      call: r.call()!,
      timeOnUtc: t,
      band: r.band()!,
      mode: r.mode()!,
    );
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
      gridsquare: Value(r.gridsquare()),
      myCall: Value(r.stationCallsign() ?? r.operator_()),
      myGrid: Value(r.myGridsquare()),
      name: Value(r.name()),
      country: Value(r.country()),
      comment: Value(r.comment()),
      source: const Value('adif'),
      dedupKey: key,
      // Preserve the entire ADIF record verbatim so QSLMSG, NOTES, POWER, QTH,
      // APP_* and user-defined fields survive round-trips.
      rawFields: Value(jsonEncode(r.fields)),
    );
    final n = await db.into(db.qsos).insert(companion, mode: InsertMode.insertOrIgnore);
    if (n > 0 && r.gridsquare() != null && r.gridsquare()!.length >= 4) {
      await upsertCallsignGrid(r.call()!, r.gridsquare()!, 'log');
    }
    return n;
  }

  Future<int> insertFromWsjtx(WsjtxQsoLogged m) async {
    final key = qsoDedupKey(
      call: m.dxCall,
      timeOnUtc: m.timeOn.toUtc(),
      band: freqToBand(m.txFrequency),
      mode: m.mode,
    );
    final raw = <String, String>{
      'call': m.dxCall,
      'gridsquare': m.dxGrid,
      'mode': m.mode,
      'rst_sent': m.reportSent,
      'rst_rcvd': m.reportReceived,
      'tx_pwr': m.txPower,
      'comment': m.comments,
      'name': m.name,
      'operator': m.opCall,
      'station_callsign': m.myCall,
      'my_gridsquare': m.myGrid,
      'srx_string': m.exchangeReceived,
      'stx_string': m.exchangeSent,
      if (m.adifPropagationMode != null) 'prop_mode': m.adifPropagationMode!,
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
      gridsquare: Value(m.dxGrid),
      myCall: Value(m.myCall),
      myGrid: Value(m.myGrid),
      name: Value(m.name),
      comment: Value(m.comments),
      source: const Value('udp'),
      dedupKey: key,
      rawFields: Value(jsonEncode(raw)),
    );
    final n = await db.into(db.qsos).insert(companion, mode: InsertMode.insertOrIgnore);
    if (n > 0 && m.dxGrid.length >= 4) {
      await upsertCallsignGrid(m.dxCall, m.dxGrid, 'log');
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
    bool markReviewed = false,
    bool clearAntenna = false,
    bool clearRadio = false,
  }) {
    return (db.update(db.qsos)..where((t) => t.id.equals(qsoId))).write(QsosCompanion(
      antennaId:      clearAntenna ? const Value(null) : (antennaId != null ? Value(antennaId) : const Value.absent()),
      radioId:        clearRadio   ? const Value(null) : (radioId   != null ? Value(radioId)   : const Value.absent()),
      personalNotes:  personalNotes != null ? Value(personalNotes) : const Value.absent(),
      rating:         rating != null ? Value(rating) : const Value.absent(),
      reviewedAt:     markReviewed ? Value(DateTime.now().toUtc()) : const Value.absent(),
    ));
  }

  Future<void> markReviewed(int qsoId) => updateEnrichment(qsoId, markReviewed: true);

  Future<void> unmarkReviewed(int qsoId) =>
      (db.update(db.qsos)..where((t) => t.id.equals(qsoId))).write(const QsosCompanion(reviewedAt: Value(null)));

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

  /// Frequency-usage histogram grouped by [binKhz] wide bins. Returns
  /// `{ centerKhz : count }` sorted by frequency ascending.
  Future<Map<int, int>> freqHistogramKhz({int binKhz = 5}) async {
    final rows = await db.customSelect(
      'SELECT freq_mhz AS f FROM qsos WHERE freq_mhz IS NOT NULL',
    ).get();
    final buckets = <int, int>{};
    for (final r in rows) {
      final f = r.read<double?>('f');
      if (f == null) continue;
      final khz = (f * 1000).round();
      final bin = (khz ~/ binKhz) * binKhz + binKhz ~/ 2;
      buckets[bin] = (buckets[bin] ?? 0) + 1;
    }
    final sorted = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in sorted) e.key: e.value};
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
