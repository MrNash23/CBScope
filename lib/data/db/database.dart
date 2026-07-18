import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Qsos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get call => text()();
  DateTimeColumn get timeOn => dateTime()();
  DateTimeColumn get timeOff => dateTime().nullable()();
  TextColumn get band => text()();
  TextColumn get mode => text()();
  TextColumn get submode => text().nullable()();
  RealColumn get freqMhz => real().nullable()();
  TextColumn get rstSent => text().nullable()();
  TextColumn get rstRcvd => text().nullable()();
  TextColumn get gridsquare => text().nullable()();
  TextColumn get myCall => text().nullable()();
  TextColumn get myGrid => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('adif'))();
  TextColumn get dedupKey => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  /// JSON blob of the full original ADIF/UDP record. Preserves every field
  /// (including QSLMSG, NOTES, APP_*, user-defined) so nothing is lost on import.
  TextColumn get rawFields => text().nullable()();

  // Enrichment fields (populated in the Review screen after auto-import).
  // FK not enforced at DB level to keep migrations simple — repository
  // resolves the join in Dart.
  IntColumn get antennaId => integer().nullable()();
  IntColumn get radioId   => integer().nullable()();
  TextColumn get personalNotes => text().nullable()();
  /// 0 = unrated, 1-5 stars.
  IntColumn get rating         => integer().withDefault(const Constant(0))();
  /// Null → still needs review; non-null → user has approved/enriched it.
  DateTimeColumn get reviewedAt => dateTime().nullable()();
}

/// User-managed antenna library — pick one when reviewing a QSO.
class Antennas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  /// e.g. "Vertical", "Dipole", "Beam", "Loop"
  TextColumn get kind => text().nullable()();
  /// Gain in dBi (optional).
  RealColumn get gainDbi => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// User-managed radio library. Called `Rigs` internally to avoid clashing
/// with Flutter's `Radio` widget when imported alongside `material.dart`.
class Rigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  /// Nominal power in watts (optional).
  IntColumn get maxPowerW => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Cache of callsign → grid locator, sourced from our own decodes/logs and
/// (optionally) PSK Reporter lookups. Used to place CB callsigns on the map
/// when the decode text itself has no grid.
class CallsignGrids extends Table {
  TextColumn get call => text()();
  TextColumn get grid => text()();
  /// 'log' | 'decode' | 'pskreporter'
  TextColumn get source => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {call};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Qsos, Settings, CallsignGrids, Antennas, Rigs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(qsos, qsos.rawFields);
            await m.createTable(callsignGrids);
          }
          if (from < 3) {
            await m.createTable(antennas);
            await m.createTable(rigs);
            await m.addColumn(qsos, qsos.antennaId);
            await m.addColumn(qsos, qsos.radioId);
            await m.addColumn(qsos, qsos.personalNotes);
            await m.addColumn(qsos, qsos.rating);
            await m.addColumn(qsos, qsos.reviewedAt);
          }
        },
      );

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(SettingsCompanion(key: Value(key), value: Value(value)));
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'QSOBook'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final file = File(p.join(dbDir.path, 'qsobook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
