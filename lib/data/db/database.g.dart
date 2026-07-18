// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $QsosTable extends Qsos with TableInfo<$QsosTable, Qso> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QsosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _callMeta = const VerificationMeta('call');
  @override
  late final GeneratedColumn<String> call = GeneratedColumn<String>(
      'call', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timeOnMeta = const VerificationMeta('timeOn');
  @override
  late final GeneratedColumn<DateTime> timeOn = GeneratedColumn<DateTime>(
      'time_on', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _timeOffMeta =
      const VerificationMeta('timeOff');
  @override
  late final GeneratedColumn<DateTime> timeOff = GeneratedColumn<DateTime>(
      'time_off', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _bandMeta = const VerificationMeta('band');
  @override
  late final GeneratedColumn<String> band = GeneratedColumn<String>(
      'band', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _submodeMeta =
      const VerificationMeta('submode');
  @override
  late final GeneratedColumn<String> submode = GeneratedColumn<String>(
      'submode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _freqMhzMeta =
      const VerificationMeta('freqMhz');
  @override
  late final GeneratedColumn<double> freqMhz = GeneratedColumn<double>(
      'freq_mhz', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _rstSentMeta =
      const VerificationMeta('rstSent');
  @override
  late final GeneratedColumn<String> rstSent = GeneratedColumn<String>(
      'rst_sent', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rstRcvdMeta =
      const VerificationMeta('rstRcvd');
  @override
  late final GeneratedColumn<String> rstRcvd = GeneratedColumn<String>(
      'rst_rcvd', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gridsquareMeta =
      const VerificationMeta('gridsquare');
  @override
  late final GeneratedColumn<String> gridsquare = GeneratedColumn<String>(
      'gridsquare', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _myCallMeta = const VerificationMeta('myCall');
  @override
  late final GeneratedColumn<String> myCall = GeneratedColumn<String>(
      'my_call', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _myGridMeta = const VerificationMeta('myGrid');
  @override
  late final GeneratedColumn<String> myGrid = GeneratedColumn<String>(
      'my_grid', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _countryMeta =
      const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
      'country', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('adif'));
  static const VerificationMeta _dedupKeyMeta =
      const VerificationMeta('dedupKey');
  @override
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
      'dedup_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _rawFieldsMeta =
      const VerificationMeta('rawFields');
  @override
  late final GeneratedColumn<String> rawFields = GeneratedColumn<String>(
      'raw_fields', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _antennaIdMeta =
      const VerificationMeta('antennaId');
  @override
  late final GeneratedColumn<int> antennaId = GeneratedColumn<int>(
      'antenna_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _radioIdMeta =
      const VerificationMeta('radioId');
  @override
  late final GeneratedColumn<int> radioId = GeneratedColumn<int>(
      'radio_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _personalNotesMeta =
      const VerificationMeta('personalNotes');
  @override
  late final GeneratedColumn<String> personalNotes = GeneratedColumn<String>(
      'personal_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _reviewedAtMeta =
      const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
      'reviewed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        call,
        timeOn,
        timeOff,
        band,
        mode,
        submode,
        freqMhz,
        rstSent,
        rstRcvd,
        gridsquare,
        myCall,
        myGrid,
        name,
        country,
        comment,
        source,
        dedupKey,
        createdAt,
        rawFields,
        antennaId,
        radioId,
        personalNotes,
        rating,
        reviewedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qsos';
  @override
  VerificationContext validateIntegrity(Insertable<Qso> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('call')) {
      context.handle(
          _callMeta, call.isAcceptableOrUnknown(data['call']!, _callMeta));
    } else if (isInserting) {
      context.missing(_callMeta);
    }
    if (data.containsKey('time_on')) {
      context.handle(_timeOnMeta,
          timeOn.isAcceptableOrUnknown(data['time_on']!, _timeOnMeta));
    } else if (isInserting) {
      context.missing(_timeOnMeta);
    }
    if (data.containsKey('time_off')) {
      context.handle(_timeOffMeta,
          timeOff.isAcceptableOrUnknown(data['time_off']!, _timeOffMeta));
    }
    if (data.containsKey('band')) {
      context.handle(
          _bandMeta, band.isAcceptableOrUnknown(data['band']!, _bandMeta));
    } else if (isInserting) {
      context.missing(_bandMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('submode')) {
      context.handle(_submodeMeta,
          submode.isAcceptableOrUnknown(data['submode']!, _submodeMeta));
    }
    if (data.containsKey('freq_mhz')) {
      context.handle(_freqMhzMeta,
          freqMhz.isAcceptableOrUnknown(data['freq_mhz']!, _freqMhzMeta));
    }
    if (data.containsKey('rst_sent')) {
      context.handle(_rstSentMeta,
          rstSent.isAcceptableOrUnknown(data['rst_sent']!, _rstSentMeta));
    }
    if (data.containsKey('rst_rcvd')) {
      context.handle(_rstRcvdMeta,
          rstRcvd.isAcceptableOrUnknown(data['rst_rcvd']!, _rstRcvdMeta));
    }
    if (data.containsKey('gridsquare')) {
      context.handle(
          _gridsquareMeta,
          gridsquare.isAcceptableOrUnknown(
              data['gridsquare']!, _gridsquareMeta));
    }
    if (data.containsKey('my_call')) {
      context.handle(_myCallMeta,
          myCall.isAcceptableOrUnknown(data['my_call']!, _myCallMeta));
    }
    if (data.containsKey('my_grid')) {
      context.handle(_myGridMeta,
          myGrid.isAcceptableOrUnknown(data['my_grid']!, _myGridMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta,
          country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('dedup_key')) {
      context.handle(_dedupKeyMeta,
          dedupKey.isAcceptableOrUnknown(data['dedup_key']!, _dedupKeyMeta));
    } else if (isInserting) {
      context.missing(_dedupKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('raw_fields')) {
      context.handle(_rawFieldsMeta,
          rawFields.isAcceptableOrUnknown(data['raw_fields']!, _rawFieldsMeta));
    }
    if (data.containsKey('antenna_id')) {
      context.handle(_antennaIdMeta,
          antennaId.isAcceptableOrUnknown(data['antenna_id']!, _antennaIdMeta));
    }
    if (data.containsKey('radio_id')) {
      context.handle(_radioIdMeta,
          radioId.isAcceptableOrUnknown(data['radio_id']!, _radioIdMeta));
    }
    if (data.containsKey('personal_notes')) {
      context.handle(
          _personalNotesMeta,
          personalNotes.isAcceptableOrUnknown(
              data['personal_notes']!, _personalNotesMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
          _reviewedAtMeta,
          reviewedAt.isAcceptableOrUnknown(
              data['reviewed_at']!, _reviewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Qso map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Qso(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      call: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}call'])!,
      timeOn: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time_on'])!,
      timeOff: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time_off']),
      band: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}band'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      submode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}submode']),
      freqMhz: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}freq_mhz']),
      rstSent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rst_sent']),
      rstRcvd: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rst_rcvd']),
      gridsquare: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gridsquare']),
      myCall: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_call']),
      myGrid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}my_grid']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      country: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country']),
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      dedupKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dedup_key'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      rawFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_fields']),
      antennaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}antenna_id']),
      radioId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}radio_id']),
      personalNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}personal_notes']),
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      reviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reviewed_at']),
    );
  }

  @override
  $QsosTable createAlias(String alias) {
    return $QsosTable(attachedDatabase, alias);
  }
}

class Qso extends DataClass implements Insertable<Qso> {
  final int id;
  final String call;
  final DateTime timeOn;
  final DateTime? timeOff;
  final String band;
  final String mode;
  final String? submode;
  final double? freqMhz;
  final String? rstSent;
  final String? rstRcvd;
  final String? gridsquare;
  final String? myCall;
  final String? myGrid;
  final String? name;
  final String? country;
  final String? comment;
  final String source;
  final String dedupKey;
  final DateTime createdAt;

  /// JSON blob of the full original ADIF/UDP record. Preserves every field
  /// (including QSLMSG, NOTES, APP_*, user-defined) so nothing is lost on import.
  final String? rawFields;
  final int? antennaId;
  final int? radioId;
  final String? personalNotes;

  /// 0 = unrated, 1-5 stars.
  final int rating;

  /// Null → still needs review; non-null → user has approved/enriched it.
  final DateTime? reviewedAt;
  const Qso(
      {required this.id,
      required this.call,
      required this.timeOn,
      this.timeOff,
      required this.band,
      required this.mode,
      this.submode,
      this.freqMhz,
      this.rstSent,
      this.rstRcvd,
      this.gridsquare,
      this.myCall,
      this.myGrid,
      this.name,
      this.country,
      this.comment,
      required this.source,
      required this.dedupKey,
      required this.createdAt,
      this.rawFields,
      this.antennaId,
      this.radioId,
      this.personalNotes,
      required this.rating,
      this.reviewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['call'] = Variable<String>(call);
    map['time_on'] = Variable<DateTime>(timeOn);
    if (!nullToAbsent || timeOff != null) {
      map['time_off'] = Variable<DateTime>(timeOff);
    }
    map['band'] = Variable<String>(band);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || submode != null) {
      map['submode'] = Variable<String>(submode);
    }
    if (!nullToAbsent || freqMhz != null) {
      map['freq_mhz'] = Variable<double>(freqMhz);
    }
    if (!nullToAbsent || rstSent != null) {
      map['rst_sent'] = Variable<String>(rstSent);
    }
    if (!nullToAbsent || rstRcvd != null) {
      map['rst_rcvd'] = Variable<String>(rstRcvd);
    }
    if (!nullToAbsent || gridsquare != null) {
      map['gridsquare'] = Variable<String>(gridsquare);
    }
    if (!nullToAbsent || myCall != null) {
      map['my_call'] = Variable<String>(myCall);
    }
    if (!nullToAbsent || myGrid != null) {
      map['my_grid'] = Variable<String>(myGrid);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['source'] = Variable<String>(source);
    map['dedup_key'] = Variable<String>(dedupKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || rawFields != null) {
      map['raw_fields'] = Variable<String>(rawFields);
    }
    if (!nullToAbsent || antennaId != null) {
      map['antenna_id'] = Variable<int>(antennaId);
    }
    if (!nullToAbsent || radioId != null) {
      map['radio_id'] = Variable<int>(radioId);
    }
    if (!nullToAbsent || personalNotes != null) {
      map['personal_notes'] = Variable<String>(personalNotes);
    }
    map['rating'] = Variable<int>(rating);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    return map;
  }

  QsosCompanion toCompanion(bool nullToAbsent) {
    return QsosCompanion(
      id: Value(id),
      call: Value(call),
      timeOn: Value(timeOn),
      timeOff: timeOff == null && nullToAbsent
          ? const Value.absent()
          : Value(timeOff),
      band: Value(band),
      mode: Value(mode),
      submode: submode == null && nullToAbsent
          ? const Value.absent()
          : Value(submode),
      freqMhz: freqMhz == null && nullToAbsent
          ? const Value.absent()
          : Value(freqMhz),
      rstSent: rstSent == null && nullToAbsent
          ? const Value.absent()
          : Value(rstSent),
      rstRcvd: rstRcvd == null && nullToAbsent
          ? const Value.absent()
          : Value(rstRcvd),
      gridsquare: gridsquare == null && nullToAbsent
          ? const Value.absent()
          : Value(gridsquare),
      myCall:
          myCall == null && nullToAbsent ? const Value.absent() : Value(myCall),
      myGrid:
          myGrid == null && nullToAbsent ? const Value.absent() : Value(myGrid),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      source: Value(source),
      dedupKey: Value(dedupKey),
      createdAt: Value(createdAt),
      rawFields: rawFields == null && nullToAbsent
          ? const Value.absent()
          : Value(rawFields),
      antennaId: antennaId == null && nullToAbsent
          ? const Value.absent()
          : Value(antennaId),
      radioId: radioId == null && nullToAbsent
          ? const Value.absent()
          : Value(radioId),
      personalNotes: personalNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(personalNotes),
      rating: Value(rating),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
    );
  }

  factory Qso.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Qso(
      id: serializer.fromJson<int>(json['id']),
      call: serializer.fromJson<String>(json['call']),
      timeOn: serializer.fromJson<DateTime>(json['timeOn']),
      timeOff: serializer.fromJson<DateTime?>(json['timeOff']),
      band: serializer.fromJson<String>(json['band']),
      mode: serializer.fromJson<String>(json['mode']),
      submode: serializer.fromJson<String?>(json['submode']),
      freqMhz: serializer.fromJson<double?>(json['freqMhz']),
      rstSent: serializer.fromJson<String?>(json['rstSent']),
      rstRcvd: serializer.fromJson<String?>(json['rstRcvd']),
      gridsquare: serializer.fromJson<String?>(json['gridsquare']),
      myCall: serializer.fromJson<String?>(json['myCall']),
      myGrid: serializer.fromJson<String?>(json['myGrid']),
      name: serializer.fromJson<String?>(json['name']),
      country: serializer.fromJson<String?>(json['country']),
      comment: serializer.fromJson<String?>(json['comment']),
      source: serializer.fromJson<String>(json['source']),
      dedupKey: serializer.fromJson<String>(json['dedupKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      rawFields: serializer.fromJson<String?>(json['rawFields']),
      antennaId: serializer.fromJson<int?>(json['antennaId']),
      radioId: serializer.fromJson<int?>(json['radioId']),
      personalNotes: serializer.fromJson<String?>(json['personalNotes']),
      rating: serializer.fromJson<int>(json['rating']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'call': serializer.toJson<String>(call),
      'timeOn': serializer.toJson<DateTime>(timeOn),
      'timeOff': serializer.toJson<DateTime?>(timeOff),
      'band': serializer.toJson<String>(band),
      'mode': serializer.toJson<String>(mode),
      'submode': serializer.toJson<String?>(submode),
      'freqMhz': serializer.toJson<double?>(freqMhz),
      'rstSent': serializer.toJson<String?>(rstSent),
      'rstRcvd': serializer.toJson<String?>(rstRcvd),
      'gridsquare': serializer.toJson<String?>(gridsquare),
      'myCall': serializer.toJson<String?>(myCall),
      'myGrid': serializer.toJson<String?>(myGrid),
      'name': serializer.toJson<String?>(name),
      'country': serializer.toJson<String?>(country),
      'comment': serializer.toJson<String?>(comment),
      'source': serializer.toJson<String>(source),
      'dedupKey': serializer.toJson<String>(dedupKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'rawFields': serializer.toJson<String?>(rawFields),
      'antennaId': serializer.toJson<int?>(antennaId),
      'radioId': serializer.toJson<int?>(radioId),
      'personalNotes': serializer.toJson<String?>(personalNotes),
      'rating': serializer.toJson<int>(rating),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
    };
  }

  Qso copyWith(
          {int? id,
          String? call,
          DateTime? timeOn,
          Value<DateTime?> timeOff = const Value.absent(),
          String? band,
          String? mode,
          Value<String?> submode = const Value.absent(),
          Value<double?> freqMhz = const Value.absent(),
          Value<String?> rstSent = const Value.absent(),
          Value<String?> rstRcvd = const Value.absent(),
          Value<String?> gridsquare = const Value.absent(),
          Value<String?> myCall = const Value.absent(),
          Value<String?> myGrid = const Value.absent(),
          Value<String?> name = const Value.absent(),
          Value<String?> country = const Value.absent(),
          Value<String?> comment = const Value.absent(),
          String? source,
          String? dedupKey,
          DateTime? createdAt,
          Value<String?> rawFields = const Value.absent(),
          Value<int?> antennaId = const Value.absent(),
          Value<int?> radioId = const Value.absent(),
          Value<String?> personalNotes = const Value.absent(),
          int? rating,
          Value<DateTime?> reviewedAt = const Value.absent()}) =>
      Qso(
        id: id ?? this.id,
        call: call ?? this.call,
        timeOn: timeOn ?? this.timeOn,
        timeOff: timeOff.present ? timeOff.value : this.timeOff,
        band: band ?? this.band,
        mode: mode ?? this.mode,
        submode: submode.present ? submode.value : this.submode,
        freqMhz: freqMhz.present ? freqMhz.value : this.freqMhz,
        rstSent: rstSent.present ? rstSent.value : this.rstSent,
        rstRcvd: rstRcvd.present ? rstRcvd.value : this.rstRcvd,
        gridsquare: gridsquare.present ? gridsquare.value : this.gridsquare,
        myCall: myCall.present ? myCall.value : this.myCall,
        myGrid: myGrid.present ? myGrid.value : this.myGrid,
        name: name.present ? name.value : this.name,
        country: country.present ? country.value : this.country,
        comment: comment.present ? comment.value : this.comment,
        source: source ?? this.source,
        dedupKey: dedupKey ?? this.dedupKey,
        createdAt: createdAt ?? this.createdAt,
        rawFields: rawFields.present ? rawFields.value : this.rawFields,
        antennaId: antennaId.present ? antennaId.value : this.antennaId,
        radioId: radioId.present ? radioId.value : this.radioId,
        personalNotes:
            personalNotes.present ? personalNotes.value : this.personalNotes,
        rating: rating ?? this.rating,
        reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
      );
  Qso copyWithCompanion(QsosCompanion data) {
    return Qso(
      id: data.id.present ? data.id.value : this.id,
      call: data.call.present ? data.call.value : this.call,
      timeOn: data.timeOn.present ? data.timeOn.value : this.timeOn,
      timeOff: data.timeOff.present ? data.timeOff.value : this.timeOff,
      band: data.band.present ? data.band.value : this.band,
      mode: data.mode.present ? data.mode.value : this.mode,
      submode: data.submode.present ? data.submode.value : this.submode,
      freqMhz: data.freqMhz.present ? data.freqMhz.value : this.freqMhz,
      rstSent: data.rstSent.present ? data.rstSent.value : this.rstSent,
      rstRcvd: data.rstRcvd.present ? data.rstRcvd.value : this.rstRcvd,
      gridsquare:
          data.gridsquare.present ? data.gridsquare.value : this.gridsquare,
      myCall: data.myCall.present ? data.myCall.value : this.myCall,
      myGrid: data.myGrid.present ? data.myGrid.value : this.myGrid,
      name: data.name.present ? data.name.value : this.name,
      country: data.country.present ? data.country.value : this.country,
      comment: data.comment.present ? data.comment.value : this.comment,
      source: data.source.present ? data.source.value : this.source,
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      rawFields: data.rawFields.present ? data.rawFields.value : this.rawFields,
      antennaId: data.antennaId.present ? data.antennaId.value : this.antennaId,
      radioId: data.radioId.present ? data.radioId.value : this.radioId,
      personalNotes: data.personalNotes.present
          ? data.personalNotes.value
          : this.personalNotes,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Qso(')
          ..write('id: $id, ')
          ..write('call: $call, ')
          ..write('timeOn: $timeOn, ')
          ..write('timeOff: $timeOff, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('submode: $submode, ')
          ..write('freqMhz: $freqMhz, ')
          ..write('rstSent: $rstSent, ')
          ..write('rstRcvd: $rstRcvd, ')
          ..write('gridsquare: $gridsquare, ')
          ..write('myCall: $myCall, ')
          ..write('myGrid: $myGrid, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('comment: $comment, ')
          ..write('source: $source, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawFields: $rawFields, ')
          ..write('antennaId: $antennaId, ')
          ..write('radioId: $radioId, ')
          ..write('personalNotes: $personalNotes, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        call,
        timeOn,
        timeOff,
        band,
        mode,
        submode,
        freqMhz,
        rstSent,
        rstRcvd,
        gridsquare,
        myCall,
        myGrid,
        name,
        country,
        comment,
        source,
        dedupKey,
        createdAt,
        rawFields,
        antennaId,
        radioId,
        personalNotes,
        rating,
        reviewedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Qso &&
          other.id == this.id &&
          other.call == this.call &&
          other.timeOn == this.timeOn &&
          other.timeOff == this.timeOff &&
          other.band == this.band &&
          other.mode == this.mode &&
          other.submode == this.submode &&
          other.freqMhz == this.freqMhz &&
          other.rstSent == this.rstSent &&
          other.rstRcvd == this.rstRcvd &&
          other.gridsquare == this.gridsquare &&
          other.myCall == this.myCall &&
          other.myGrid == this.myGrid &&
          other.name == this.name &&
          other.country == this.country &&
          other.comment == this.comment &&
          other.source == this.source &&
          other.dedupKey == this.dedupKey &&
          other.createdAt == this.createdAt &&
          other.rawFields == this.rawFields &&
          other.antennaId == this.antennaId &&
          other.radioId == this.radioId &&
          other.personalNotes == this.personalNotes &&
          other.rating == this.rating &&
          other.reviewedAt == this.reviewedAt);
}

class QsosCompanion extends UpdateCompanion<Qso> {
  final Value<int> id;
  final Value<String> call;
  final Value<DateTime> timeOn;
  final Value<DateTime?> timeOff;
  final Value<String> band;
  final Value<String> mode;
  final Value<String?> submode;
  final Value<double?> freqMhz;
  final Value<String?> rstSent;
  final Value<String?> rstRcvd;
  final Value<String?> gridsquare;
  final Value<String?> myCall;
  final Value<String?> myGrid;
  final Value<String?> name;
  final Value<String?> country;
  final Value<String?> comment;
  final Value<String> source;
  final Value<String> dedupKey;
  final Value<DateTime> createdAt;
  final Value<String?> rawFields;
  final Value<int?> antennaId;
  final Value<int?> radioId;
  final Value<String?> personalNotes;
  final Value<int> rating;
  final Value<DateTime?> reviewedAt;
  const QsosCompanion({
    this.id = const Value.absent(),
    this.call = const Value.absent(),
    this.timeOn = const Value.absent(),
    this.timeOff = const Value.absent(),
    this.band = const Value.absent(),
    this.mode = const Value.absent(),
    this.submode = const Value.absent(),
    this.freqMhz = const Value.absent(),
    this.rstSent = const Value.absent(),
    this.rstRcvd = const Value.absent(),
    this.gridsquare = const Value.absent(),
    this.myCall = const Value.absent(),
    this.myGrid = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.comment = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rawFields = const Value.absent(),
    this.antennaId = const Value.absent(),
    this.radioId = const Value.absent(),
    this.personalNotes = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviewedAt = const Value.absent(),
  });
  QsosCompanion.insert({
    this.id = const Value.absent(),
    required String call,
    required DateTime timeOn,
    this.timeOff = const Value.absent(),
    required String band,
    required String mode,
    this.submode = const Value.absent(),
    this.freqMhz = const Value.absent(),
    this.rstSent = const Value.absent(),
    this.rstRcvd = const Value.absent(),
    this.gridsquare = const Value.absent(),
    this.myCall = const Value.absent(),
    this.myGrid = const Value.absent(),
    this.name = const Value.absent(),
    this.country = const Value.absent(),
    this.comment = const Value.absent(),
    this.source = const Value.absent(),
    required String dedupKey,
    this.createdAt = const Value.absent(),
    this.rawFields = const Value.absent(),
    this.antennaId = const Value.absent(),
    this.radioId = const Value.absent(),
    this.personalNotes = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviewedAt = const Value.absent(),
  })  : call = Value(call),
        timeOn = Value(timeOn),
        band = Value(band),
        mode = Value(mode),
        dedupKey = Value(dedupKey);
  static Insertable<Qso> custom({
    Expression<int>? id,
    Expression<String>? call,
    Expression<DateTime>? timeOn,
    Expression<DateTime>? timeOff,
    Expression<String>? band,
    Expression<String>? mode,
    Expression<String>? submode,
    Expression<double>? freqMhz,
    Expression<String>? rstSent,
    Expression<String>? rstRcvd,
    Expression<String>? gridsquare,
    Expression<String>? myCall,
    Expression<String>? myGrid,
    Expression<String>? name,
    Expression<String>? country,
    Expression<String>? comment,
    Expression<String>? source,
    Expression<String>? dedupKey,
    Expression<DateTime>? createdAt,
    Expression<String>? rawFields,
    Expression<int>? antennaId,
    Expression<int>? radioId,
    Expression<String>? personalNotes,
    Expression<int>? rating,
    Expression<DateTime>? reviewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (call != null) 'call': call,
      if (timeOn != null) 'time_on': timeOn,
      if (timeOff != null) 'time_off': timeOff,
      if (band != null) 'band': band,
      if (mode != null) 'mode': mode,
      if (submode != null) 'submode': submode,
      if (freqMhz != null) 'freq_mhz': freqMhz,
      if (rstSent != null) 'rst_sent': rstSent,
      if (rstRcvd != null) 'rst_rcvd': rstRcvd,
      if (gridsquare != null) 'gridsquare': gridsquare,
      if (myCall != null) 'my_call': myCall,
      if (myGrid != null) 'my_grid': myGrid,
      if (name != null) 'name': name,
      if (country != null) 'country': country,
      if (comment != null) 'comment': comment,
      if (source != null) 'source': source,
      if (dedupKey != null) 'dedup_key': dedupKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rawFields != null) 'raw_fields': rawFields,
      if (antennaId != null) 'antenna_id': antennaId,
      if (radioId != null) 'radio_id': radioId,
      if (personalNotes != null) 'personal_notes': personalNotes,
      if (rating != null) 'rating': rating,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
    });
  }

  QsosCompanion copyWith(
      {Value<int>? id,
      Value<String>? call,
      Value<DateTime>? timeOn,
      Value<DateTime?>? timeOff,
      Value<String>? band,
      Value<String>? mode,
      Value<String?>? submode,
      Value<double?>? freqMhz,
      Value<String?>? rstSent,
      Value<String?>? rstRcvd,
      Value<String?>? gridsquare,
      Value<String?>? myCall,
      Value<String?>? myGrid,
      Value<String?>? name,
      Value<String?>? country,
      Value<String?>? comment,
      Value<String>? source,
      Value<String>? dedupKey,
      Value<DateTime>? createdAt,
      Value<String?>? rawFields,
      Value<int?>? antennaId,
      Value<int?>? radioId,
      Value<String?>? personalNotes,
      Value<int>? rating,
      Value<DateTime?>? reviewedAt}) {
    return QsosCompanion(
      id: id ?? this.id,
      call: call ?? this.call,
      timeOn: timeOn ?? this.timeOn,
      timeOff: timeOff ?? this.timeOff,
      band: band ?? this.band,
      mode: mode ?? this.mode,
      submode: submode ?? this.submode,
      freqMhz: freqMhz ?? this.freqMhz,
      rstSent: rstSent ?? this.rstSent,
      rstRcvd: rstRcvd ?? this.rstRcvd,
      gridsquare: gridsquare ?? this.gridsquare,
      myCall: myCall ?? this.myCall,
      myGrid: myGrid ?? this.myGrid,
      name: name ?? this.name,
      country: country ?? this.country,
      comment: comment ?? this.comment,
      source: source ?? this.source,
      dedupKey: dedupKey ?? this.dedupKey,
      createdAt: createdAt ?? this.createdAt,
      rawFields: rawFields ?? this.rawFields,
      antennaId: antennaId ?? this.antennaId,
      radioId: radioId ?? this.radioId,
      personalNotes: personalNotes ?? this.personalNotes,
      rating: rating ?? this.rating,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (call.present) {
      map['call'] = Variable<String>(call.value);
    }
    if (timeOn.present) {
      map['time_on'] = Variable<DateTime>(timeOn.value);
    }
    if (timeOff.present) {
      map['time_off'] = Variable<DateTime>(timeOff.value);
    }
    if (band.present) {
      map['band'] = Variable<String>(band.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (submode.present) {
      map['submode'] = Variable<String>(submode.value);
    }
    if (freqMhz.present) {
      map['freq_mhz'] = Variable<double>(freqMhz.value);
    }
    if (rstSent.present) {
      map['rst_sent'] = Variable<String>(rstSent.value);
    }
    if (rstRcvd.present) {
      map['rst_rcvd'] = Variable<String>(rstRcvd.value);
    }
    if (gridsquare.present) {
      map['gridsquare'] = Variable<String>(gridsquare.value);
    }
    if (myCall.present) {
      map['my_call'] = Variable<String>(myCall.value);
    }
    if (myGrid.present) {
      map['my_grid'] = Variable<String>(myGrid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupKey.present) {
      map['dedup_key'] = Variable<String>(dedupKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rawFields.present) {
      map['raw_fields'] = Variable<String>(rawFields.value);
    }
    if (antennaId.present) {
      map['antenna_id'] = Variable<int>(antennaId.value);
    }
    if (radioId.present) {
      map['radio_id'] = Variable<int>(radioId.value);
    }
    if (personalNotes.present) {
      map['personal_notes'] = Variable<String>(personalNotes.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QsosCompanion(')
          ..write('id: $id, ')
          ..write('call: $call, ')
          ..write('timeOn: $timeOn, ')
          ..write('timeOff: $timeOff, ')
          ..write('band: $band, ')
          ..write('mode: $mode, ')
          ..write('submode: $submode, ')
          ..write('freqMhz: $freqMhz, ')
          ..write('rstSent: $rstSent, ')
          ..write('rstRcvd: $rstRcvd, ')
          ..write('gridsquare: $gridsquare, ')
          ..write('myCall: $myCall, ')
          ..write('myGrid: $myGrid, ')
          ..write('name: $name, ')
          ..write('country: $country, ')
          ..write('comment: $comment, ')
          ..write('source: $source, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rawFields: $rawFields, ')
          ..write('antennaId: $antennaId, ')
          ..write('radioId: $radioId, ')
          ..write('personalNotes: $personalNotes, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CallsignGridsTable extends CallsignGrids
    with TableInfo<$CallsignGridsTable, CallsignGrid> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CallsignGridsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _callMeta = const VerificationMeta('call');
  @override
  late final GeneratedColumn<String> call = GeneratedColumn<String>(
      'call', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gridMeta = const VerificationMeta('grid');
  @override
  late final GeneratedColumn<String> grid = GeneratedColumn<String>(
      'grid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [call, grid, source, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'callsign_grids';
  @override
  VerificationContext validateIntegrity(Insertable<CallsignGrid> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('call')) {
      context.handle(
          _callMeta, call.isAcceptableOrUnknown(data['call']!, _callMeta));
    } else if (isInserting) {
      context.missing(_callMeta);
    }
    if (data.containsKey('grid')) {
      context.handle(
          _gridMeta, grid.isAcceptableOrUnknown(data['grid']!, _gridMeta));
    } else if (isInserting) {
      context.missing(_gridMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {call};
  @override
  CallsignGrid map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CallsignGrid(
      call: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}call'])!,
      grid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grid'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CallsignGridsTable createAlias(String alias) {
    return $CallsignGridsTable(attachedDatabase, alias);
  }
}

class CallsignGrid extends DataClass implements Insertable<CallsignGrid> {
  final String call;
  final String grid;

  /// 'log' | 'decode' | 'pskreporter'
  final String source;
  final DateTime updatedAt;
  const CallsignGrid(
      {required this.call,
      required this.grid,
      required this.source,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['call'] = Variable<String>(call);
    map['grid'] = Variable<String>(grid);
    map['source'] = Variable<String>(source);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CallsignGridsCompanion toCompanion(bool nullToAbsent) {
    return CallsignGridsCompanion(
      call: Value(call),
      grid: Value(grid),
      source: Value(source),
      updatedAt: Value(updatedAt),
    );
  }

  factory CallsignGrid.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CallsignGrid(
      call: serializer.fromJson<String>(json['call']),
      grid: serializer.fromJson<String>(json['grid']),
      source: serializer.fromJson<String>(json['source']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'call': serializer.toJson<String>(call),
      'grid': serializer.toJson<String>(grid),
      'source': serializer.toJson<String>(source),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CallsignGrid copyWith(
          {String? call, String? grid, String? source, DateTime? updatedAt}) =>
      CallsignGrid(
        call: call ?? this.call,
        grid: grid ?? this.grid,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CallsignGrid copyWithCompanion(CallsignGridsCompanion data) {
    return CallsignGrid(
      call: data.call.present ? data.call.value : this.call,
      grid: data.grid.present ? data.grid.value : this.grid,
      source: data.source.present ? data.source.value : this.source,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CallsignGrid(')
          ..write('call: $call, ')
          ..write('grid: $grid, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(call, grid, source, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CallsignGrid &&
          other.call == this.call &&
          other.grid == this.grid &&
          other.source == this.source &&
          other.updatedAt == this.updatedAt);
}

class CallsignGridsCompanion extends UpdateCompanion<CallsignGrid> {
  final Value<String> call;
  final Value<String> grid;
  final Value<String> source;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CallsignGridsCompanion({
    this.call = const Value.absent(),
    this.grid = const Value.absent(),
    this.source = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CallsignGridsCompanion.insert({
    required String call,
    required String grid,
    required String source,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : call = Value(call),
        grid = Value(grid),
        source = Value(source);
  static Insertable<CallsignGrid> custom({
    Expression<String>? call,
    Expression<String>? grid,
    Expression<String>? source,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (call != null) 'call': call,
      if (grid != null) 'grid': grid,
      if (source != null) 'source': source,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CallsignGridsCompanion copyWith(
      {Value<String>? call,
      Value<String>? grid,
      Value<String>? source,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CallsignGridsCompanion(
      call: call ?? this.call,
      grid: grid ?? this.grid,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (call.present) {
      map['call'] = Variable<String>(call.value);
    }
    if (grid.present) {
      map['grid'] = Variable<String>(grid.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CallsignGridsCompanion(')
          ..write('call: $call, ')
          ..write('grid: $grid, ')
          ..write('source: $source, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AntennasTable extends Antennas with TableInfo<$AntennasTable, Antenna> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AntennasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gainDbiMeta =
      const VerificationMeta('gainDbi');
  @override
  late final GeneratedColumn<double> gainDbi = GeneratedColumn<double>(
      'gain_dbi', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, kind, gainDbi, createdAt, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'antennas';
  @override
  VerificationContext validateIntegrity(Insertable<Antenna> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('gain_dbi')) {
      context.handle(_gainDbiMeta,
          gainDbi.isAcceptableOrUnknown(data['gain_dbi']!, _gainDbiMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Antenna map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Antenna(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind']),
      gainDbi: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}gain_dbi']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
    );
  }

  @override
  $AntennasTable createAlias(String alias) {
    return $AntennasTable(attachedDatabase, alias);
  }
}

class Antenna extends DataClass implements Insertable<Antenna> {
  final int id;
  final String name;
  final String? description;

  /// e.g. "Vertical", "Dipole", "Beam", "Loop"
  final String? kind;

  /// Gain in dBi (optional).
  final double? gainDbi;
  final DateTime createdAt;
  final bool archived;
  const Antenna(
      {required this.id,
      required this.name,
      this.description,
      this.kind,
      this.gainDbi,
      required this.createdAt,
      required this.archived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || gainDbi != null) {
      map['gain_dbi'] = Variable<double>(gainDbi);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  AntennasCompanion toCompanion(bool nullToAbsent) {
    return AntennasCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      gainDbi: gainDbi == null && nullToAbsent
          ? const Value.absent()
          : Value(gainDbi),
      createdAt: Value(createdAt),
      archived: Value(archived),
    );
  }

  factory Antenna.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Antenna(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      kind: serializer.fromJson<String?>(json['kind']),
      gainDbi: serializer.fromJson<double?>(json['gainDbi']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'kind': serializer.toJson<String?>(kind),
      'gainDbi': serializer.toJson<double?>(gainDbi),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Antenna copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          Value<String?> kind = const Value.absent(),
          Value<double?> gainDbi = const Value.absent(),
          DateTime? createdAt,
          bool? archived}) =>
      Antenna(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        kind: kind.present ? kind.value : this.kind,
        gainDbi: gainDbi.present ? gainDbi.value : this.gainDbi,
        createdAt: createdAt ?? this.createdAt,
        archived: archived ?? this.archived,
      );
  Antenna copyWithCompanion(AntennasCompanion data) {
    return Antenna(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      kind: data.kind.present ? data.kind.value : this.kind,
      gainDbi: data.gainDbi.present ? data.gainDbi.value : this.gainDbi,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Antenna(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('gainDbi: $gainDbi, ')
          ..write('createdAt: $createdAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, kind, gainDbi, createdAt, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Antenna &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.kind == this.kind &&
          other.gainDbi == this.gainDbi &&
          other.createdAt == this.createdAt &&
          other.archived == this.archived);
}

class AntennasCompanion extends UpdateCompanion<Antenna> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> kind;
  final Value<double?> gainDbi;
  final Value<DateTime> createdAt;
  final Value<bool> archived;
  const AntennasCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.gainDbi = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archived = const Value.absent(),
  });
  AntennasCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.gainDbi = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archived = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Antenna> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? kind,
    Expression<double>? gainDbi,
    Expression<DateTime>? createdAt,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (kind != null) 'kind': kind,
      if (gainDbi != null) 'gain_dbi': gainDbi,
      if (createdAt != null) 'created_at': createdAt,
      if (archived != null) 'archived': archived,
    });
  }

  AntennasCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String?>? kind,
      Value<double?>? gainDbi,
      Value<DateTime>? createdAt,
      Value<bool>? archived}) {
    return AntennasCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      gainDbi: gainDbi ?? this.gainDbi,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (gainDbi.present) {
      map['gain_dbi'] = Variable<double>(gainDbi.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AntennasCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('gainDbi: $gainDbi, ')
          ..write('createdAt: $createdAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

class $RigsTable extends Rigs with TableInfo<$RigsTable, Rig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _maxPowerWMeta =
      const VerificationMeta('maxPowerW');
  @override
  late final GeneratedColumn<int> maxPowerW = GeneratedColumn<int>(
      'max_power_w', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, maxPowerW, createdAt, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rigs';
  @override
  VerificationContext validateIntegrity(Insertable<Rig> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('max_power_w')) {
      context.handle(
          _maxPowerWMeta,
          maxPowerW.isAcceptableOrUnknown(
              data['max_power_w']!, _maxPowerWMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rig(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      maxPowerW: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_power_w']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
    );
  }

  @override
  $RigsTable createAlias(String alias) {
    return $RigsTable(attachedDatabase, alias);
  }
}

class Rig extends DataClass implements Insertable<Rig> {
  final int id;
  final String name;
  final String? description;

  /// Nominal power in watts (optional).
  final int? maxPowerW;
  final DateTime createdAt;
  final bool archived;
  const Rig(
      {required this.id,
      required this.name,
      this.description,
      this.maxPowerW,
      required this.createdAt,
      required this.archived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || maxPowerW != null) {
      map['max_power_w'] = Variable<int>(maxPowerW);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  RigsCompanion toCompanion(bool nullToAbsent) {
    return RigsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      maxPowerW: maxPowerW == null && nullToAbsent
          ? const Value.absent()
          : Value(maxPowerW),
      createdAt: Value(createdAt),
      archived: Value(archived),
    );
  }

  factory Rig.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rig(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      maxPowerW: serializer.fromJson<int?>(json['maxPowerW']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'maxPowerW': serializer.toJson<int?>(maxPowerW),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Rig copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          Value<int?> maxPowerW = const Value.absent(),
          DateTime? createdAt,
          bool? archived}) =>
      Rig(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        maxPowerW: maxPowerW.present ? maxPowerW.value : this.maxPowerW,
        createdAt: createdAt ?? this.createdAt,
        archived: archived ?? this.archived,
      );
  Rig copyWithCompanion(RigsCompanion data) {
    return Rig(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      maxPowerW: data.maxPowerW.present ? data.maxPowerW.value : this.maxPowerW,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rig(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('maxPowerW: $maxPowerW, ')
          ..write('createdAt: $createdAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, maxPowerW, createdAt, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rig &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.maxPowerW == this.maxPowerW &&
          other.createdAt == this.createdAt &&
          other.archived == this.archived);
}

class RigsCompanion extends UpdateCompanion<Rig> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int?> maxPowerW;
  final Value<DateTime> createdAt;
  final Value<bool> archived;
  const RigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.maxPowerW = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archived = const Value.absent(),
  });
  RigsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.maxPowerW = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archived = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Rig> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? maxPowerW,
    Expression<DateTime>? createdAt,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (maxPowerW != null) 'max_power_w': maxPowerW,
      if (createdAt != null) 'created_at': createdAt,
      if (archived != null) 'archived': archived,
    });
  }

  RigsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<int?>? maxPowerW,
      Value<DateTime>? createdAt,
      Value<bool>? archived}) {
    return RigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      maxPowerW: maxPowerW ?? this.maxPowerW,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (maxPowerW.present) {
      map['max_power_w'] = Variable<int>(maxPowerW.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('maxPowerW: $maxPowerW, ')
          ..write('createdAt: $createdAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QsosTable qsos = $QsosTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $CallsignGridsTable callsignGrids = $CallsignGridsTable(this);
  late final $AntennasTable antennas = $AntennasTable(this);
  late final $RigsTable rigs = $RigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [qsos, settings, callsignGrids, antennas, rigs];
}

typedef $$QsosTableCreateCompanionBuilder = QsosCompanion Function({
  Value<int> id,
  required String call,
  required DateTime timeOn,
  Value<DateTime?> timeOff,
  required String band,
  required String mode,
  Value<String?> submode,
  Value<double?> freqMhz,
  Value<String?> rstSent,
  Value<String?> rstRcvd,
  Value<String?> gridsquare,
  Value<String?> myCall,
  Value<String?> myGrid,
  Value<String?> name,
  Value<String?> country,
  Value<String?> comment,
  Value<String> source,
  required String dedupKey,
  Value<DateTime> createdAt,
  Value<String?> rawFields,
  Value<int?> antennaId,
  Value<int?> radioId,
  Value<String?> personalNotes,
  Value<int> rating,
  Value<DateTime?> reviewedAt,
});
typedef $$QsosTableUpdateCompanionBuilder = QsosCompanion Function({
  Value<int> id,
  Value<String> call,
  Value<DateTime> timeOn,
  Value<DateTime?> timeOff,
  Value<String> band,
  Value<String> mode,
  Value<String?> submode,
  Value<double?> freqMhz,
  Value<String?> rstSent,
  Value<String?> rstRcvd,
  Value<String?> gridsquare,
  Value<String?> myCall,
  Value<String?> myGrid,
  Value<String?> name,
  Value<String?> country,
  Value<String?> comment,
  Value<String> source,
  Value<String> dedupKey,
  Value<DateTime> createdAt,
  Value<String?> rawFields,
  Value<int?> antennaId,
  Value<int?> radioId,
  Value<String?> personalNotes,
  Value<int> rating,
  Value<DateTime?> reviewedAt,
});

class $$QsosTableFilterComposer extends Composer<_$AppDatabase, $QsosTable> {
  $$QsosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get call => $composableBuilder(
      column: $table.call, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timeOn => $composableBuilder(
      column: $table.timeOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timeOff => $composableBuilder(
      column: $table.timeOff, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get band => $composableBuilder(
      column: $table.band, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get submode => $composableBuilder(
      column: $table.submode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get freqMhz => $composableBuilder(
      column: $table.freqMhz, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rstSent => $composableBuilder(
      column: $table.rstSent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rstRcvd => $composableBuilder(
      column: $table.rstRcvd, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gridsquare => $composableBuilder(
      column: $table.gridsquare, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get myCall => $composableBuilder(
      column: $table.myCall, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get myGrid => $composableBuilder(
      column: $table.myGrid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawFields => $composableBuilder(
      column: $table.rawFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get antennaId => $composableBuilder(
      column: $table.antennaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get radioId => $composableBuilder(
      column: $table.radioId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get personalNotes => $composableBuilder(
      column: $table.personalNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnFilters(column));
}

class $$QsosTableOrderingComposer extends Composer<_$AppDatabase, $QsosTable> {
  $$QsosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get call => $composableBuilder(
      column: $table.call, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timeOn => $composableBuilder(
      column: $table.timeOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timeOff => $composableBuilder(
      column: $table.timeOff, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get band => $composableBuilder(
      column: $table.band, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get submode => $composableBuilder(
      column: $table.submode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get freqMhz => $composableBuilder(
      column: $table.freqMhz, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rstSent => $composableBuilder(
      column: $table.rstSent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rstRcvd => $composableBuilder(
      column: $table.rstRcvd, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gridsquare => $composableBuilder(
      column: $table.gridsquare, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get myCall => $composableBuilder(
      column: $table.myCall, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get myGrid => $composableBuilder(
      column: $table.myGrid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dedupKey => $composableBuilder(
      column: $table.dedupKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawFields => $composableBuilder(
      column: $table.rawFields, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get antennaId => $composableBuilder(
      column: $table.antennaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get radioId => $composableBuilder(
      column: $table.radioId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get personalNotes => $composableBuilder(
      column: $table.personalNotes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));
}

class $$QsosTableAnnotationComposer
    extends Composer<_$AppDatabase, $QsosTable> {
  $$QsosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get call =>
      $composableBuilder(column: $table.call, builder: (column) => column);

  GeneratedColumn<DateTime> get timeOn =>
      $composableBuilder(column: $table.timeOn, builder: (column) => column);

  GeneratedColumn<DateTime> get timeOff =>
      $composableBuilder(column: $table.timeOff, builder: (column) => column);

  GeneratedColumn<String> get band =>
      $composableBuilder(column: $table.band, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get submode =>
      $composableBuilder(column: $table.submode, builder: (column) => column);

  GeneratedColumn<double> get freqMhz =>
      $composableBuilder(column: $table.freqMhz, builder: (column) => column);

  GeneratedColumn<String> get rstSent =>
      $composableBuilder(column: $table.rstSent, builder: (column) => column);

  GeneratedColumn<String> get rstRcvd =>
      $composableBuilder(column: $table.rstRcvd, builder: (column) => column);

  GeneratedColumn<String> get gridsquare => $composableBuilder(
      column: $table.gridsquare, builder: (column) => column);

  GeneratedColumn<String> get myCall =>
      $composableBuilder(column: $table.myCall, builder: (column) => column);

  GeneratedColumn<String> get myGrid =>
      $composableBuilder(column: $table.myGrid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get rawFields =>
      $composableBuilder(column: $table.rawFields, builder: (column) => column);

  GeneratedColumn<int> get antennaId =>
      $composableBuilder(column: $table.antennaId, builder: (column) => column);

  GeneratedColumn<int> get radioId =>
      $composableBuilder(column: $table.radioId, builder: (column) => column);

  GeneratedColumn<String> get personalNotes => $composableBuilder(
      column: $table.personalNotes, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => column);
}

class $$QsosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QsosTable,
    Qso,
    $$QsosTableFilterComposer,
    $$QsosTableOrderingComposer,
    $$QsosTableAnnotationComposer,
    $$QsosTableCreateCompanionBuilder,
    $$QsosTableUpdateCompanionBuilder,
    (Qso, BaseReferences<_$AppDatabase, $QsosTable, Qso>),
    Qso,
    PrefetchHooks Function()> {
  $$QsosTableTableManager(_$AppDatabase db, $QsosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QsosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QsosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QsosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> call = const Value.absent(),
            Value<DateTime> timeOn = const Value.absent(),
            Value<DateTime?> timeOff = const Value.absent(),
            Value<String> band = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<String?> submode = const Value.absent(),
            Value<double?> freqMhz = const Value.absent(),
            Value<String?> rstSent = const Value.absent(),
            Value<String?> rstRcvd = const Value.absent(),
            Value<String?> gridsquare = const Value.absent(),
            Value<String?> myCall = const Value.absent(),
            Value<String?> myGrid = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> country = const Value.absent(),
            Value<String?> comment = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> dedupKey = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> rawFields = const Value.absent(),
            Value<int?> antennaId = const Value.absent(),
            Value<int?> radioId = const Value.absent(),
            Value<String?> personalNotes = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<DateTime?> reviewedAt = const Value.absent(),
          }) =>
              QsosCompanion(
            id: id,
            call: call,
            timeOn: timeOn,
            timeOff: timeOff,
            band: band,
            mode: mode,
            submode: submode,
            freqMhz: freqMhz,
            rstSent: rstSent,
            rstRcvd: rstRcvd,
            gridsquare: gridsquare,
            myCall: myCall,
            myGrid: myGrid,
            name: name,
            country: country,
            comment: comment,
            source: source,
            dedupKey: dedupKey,
            createdAt: createdAt,
            rawFields: rawFields,
            antennaId: antennaId,
            radioId: radioId,
            personalNotes: personalNotes,
            rating: rating,
            reviewedAt: reviewedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String call,
            required DateTime timeOn,
            Value<DateTime?> timeOff = const Value.absent(),
            required String band,
            required String mode,
            Value<String?> submode = const Value.absent(),
            Value<double?> freqMhz = const Value.absent(),
            Value<String?> rstSent = const Value.absent(),
            Value<String?> rstRcvd = const Value.absent(),
            Value<String?> gridsquare = const Value.absent(),
            Value<String?> myCall = const Value.absent(),
            Value<String?> myGrid = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> country = const Value.absent(),
            Value<String?> comment = const Value.absent(),
            Value<String> source = const Value.absent(),
            required String dedupKey,
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> rawFields = const Value.absent(),
            Value<int?> antennaId = const Value.absent(),
            Value<int?> radioId = const Value.absent(),
            Value<String?> personalNotes = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<DateTime?> reviewedAt = const Value.absent(),
          }) =>
              QsosCompanion.insert(
            id: id,
            call: call,
            timeOn: timeOn,
            timeOff: timeOff,
            band: band,
            mode: mode,
            submode: submode,
            freqMhz: freqMhz,
            rstSent: rstSent,
            rstRcvd: rstRcvd,
            gridsquare: gridsquare,
            myCall: myCall,
            myGrid: myGrid,
            name: name,
            country: country,
            comment: comment,
            source: source,
            dedupKey: dedupKey,
            createdAt: createdAt,
            rawFields: rawFields,
            antennaId: antennaId,
            radioId: radioId,
            personalNotes: personalNotes,
            rating: rating,
            reviewedAt: reviewedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QsosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QsosTable,
    Qso,
    $$QsosTableFilterComposer,
    $$QsosTableOrderingComposer,
    $$QsosTableAnnotationComposer,
    $$QsosTableCreateCompanionBuilder,
    $$QsosTableUpdateCompanionBuilder,
    (Qso, BaseReferences<_$AppDatabase, $QsosTable, Qso>),
    Qso,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$CallsignGridsTableCreateCompanionBuilder = CallsignGridsCompanion
    Function({
  required String call,
  required String grid,
  required String source,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$CallsignGridsTableUpdateCompanionBuilder = CallsignGridsCompanion
    Function({
  Value<String> call,
  Value<String> grid,
  Value<String> source,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CallsignGridsTableFilterComposer
    extends Composer<_$AppDatabase, $CallsignGridsTable> {
  $$CallsignGridsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get call => $composableBuilder(
      column: $table.call, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get grid => $composableBuilder(
      column: $table.grid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CallsignGridsTableOrderingComposer
    extends Composer<_$AppDatabase, $CallsignGridsTable> {
  $$CallsignGridsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get call => $composableBuilder(
      column: $table.call, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get grid => $composableBuilder(
      column: $table.grid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CallsignGridsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CallsignGridsTable> {
  $$CallsignGridsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get call =>
      $composableBuilder(column: $table.call, builder: (column) => column);

  GeneratedColumn<String> get grid =>
      $composableBuilder(column: $table.grid, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CallsignGridsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CallsignGridsTable,
    CallsignGrid,
    $$CallsignGridsTableFilterComposer,
    $$CallsignGridsTableOrderingComposer,
    $$CallsignGridsTableAnnotationComposer,
    $$CallsignGridsTableCreateCompanionBuilder,
    $$CallsignGridsTableUpdateCompanionBuilder,
    (
      CallsignGrid,
      BaseReferences<_$AppDatabase, $CallsignGridsTable, CallsignGrid>
    ),
    CallsignGrid,
    PrefetchHooks Function()> {
  $$CallsignGridsTableTableManager(_$AppDatabase db, $CallsignGridsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CallsignGridsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CallsignGridsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CallsignGridsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> call = const Value.absent(),
            Value<String> grid = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CallsignGridsCompanion(
            call: call,
            grid: grid,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String call,
            required String grid,
            required String source,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CallsignGridsCompanion.insert(
            call: call,
            grid: grid,
            source: source,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CallsignGridsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CallsignGridsTable,
    CallsignGrid,
    $$CallsignGridsTableFilterComposer,
    $$CallsignGridsTableOrderingComposer,
    $$CallsignGridsTableAnnotationComposer,
    $$CallsignGridsTableCreateCompanionBuilder,
    $$CallsignGridsTableUpdateCompanionBuilder,
    (
      CallsignGrid,
      BaseReferences<_$AppDatabase, $CallsignGridsTable, CallsignGrid>
    ),
    CallsignGrid,
    PrefetchHooks Function()>;
typedef $$AntennasTableCreateCompanionBuilder = AntennasCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  Value<String?> kind,
  Value<double?> gainDbi,
  Value<DateTime> createdAt,
  Value<bool> archived,
});
typedef $$AntennasTableUpdateCompanionBuilder = AntennasCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<String?> kind,
  Value<double?> gainDbi,
  Value<DateTime> createdAt,
  Value<bool> archived,
});

class $$AntennasTableFilterComposer
    extends Composer<_$AppDatabase, $AntennasTable> {
  $$AntennasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get gainDbi => $composableBuilder(
      column: $table.gainDbi, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));
}

class $$AntennasTableOrderingComposer
    extends Composer<_$AppDatabase, $AntennasTable> {
  $$AntennasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get gainDbi => $composableBuilder(
      column: $table.gainDbi, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));
}

class $$AntennasTableAnnotationComposer
    extends Composer<_$AppDatabase, $AntennasTable> {
  $$AntennasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get gainDbi =>
      $composableBuilder(column: $table.gainDbi, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$AntennasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AntennasTable,
    Antenna,
    $$AntennasTableFilterComposer,
    $$AntennasTableOrderingComposer,
    $$AntennasTableAnnotationComposer,
    $$AntennasTableCreateCompanionBuilder,
    $$AntennasTableUpdateCompanionBuilder,
    (Antenna, BaseReferences<_$AppDatabase, $AntennasTable, Antenna>),
    Antenna,
    PrefetchHooks Function()> {
  $$AntennasTableTableManager(_$AppDatabase db, $AntennasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AntennasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AntennasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AntennasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> kind = const Value.absent(),
            Value<double?> gainDbi = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
          }) =>
              AntennasCompanion(
            id: id,
            name: name,
            description: description,
            kind: kind,
            gainDbi: gainDbi,
            createdAt: createdAt,
            archived: archived,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String?> kind = const Value.absent(),
            Value<double?> gainDbi = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
          }) =>
              AntennasCompanion.insert(
            id: id,
            name: name,
            description: description,
            kind: kind,
            gainDbi: gainDbi,
            createdAt: createdAt,
            archived: archived,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AntennasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AntennasTable,
    Antenna,
    $$AntennasTableFilterComposer,
    $$AntennasTableOrderingComposer,
    $$AntennasTableAnnotationComposer,
    $$AntennasTableCreateCompanionBuilder,
    $$AntennasTableUpdateCompanionBuilder,
    (Antenna, BaseReferences<_$AppDatabase, $AntennasTable, Antenna>),
    Antenna,
    PrefetchHooks Function()>;
typedef $$RigsTableCreateCompanionBuilder = RigsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  Value<int?> maxPowerW,
  Value<DateTime> createdAt,
  Value<bool> archived,
});
typedef $$RigsTableUpdateCompanionBuilder = RigsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<int?> maxPowerW,
  Value<DateTime> createdAt,
  Value<bool> archived,
});

class $$RigsTableFilterComposer extends Composer<_$AppDatabase, $RigsTable> {
  $$RigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxPowerW => $composableBuilder(
      column: $table.maxPowerW, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));
}

class $$RigsTableOrderingComposer extends Composer<_$AppDatabase, $RigsTable> {
  $$RigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxPowerW => $composableBuilder(
      column: $table.maxPowerW, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));
}

class $$RigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RigsTable> {
  $$RigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get maxPowerW =>
      $composableBuilder(column: $table.maxPowerW, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$RigsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RigsTable,
    Rig,
    $$RigsTableFilterComposer,
    $$RigsTableOrderingComposer,
    $$RigsTableAnnotationComposer,
    $$RigsTableCreateCompanionBuilder,
    $$RigsTableUpdateCompanionBuilder,
    (Rig, BaseReferences<_$AppDatabase, $RigsTable, Rig>),
    Rig,
    PrefetchHooks Function()> {
  $$RigsTableTableManager(_$AppDatabase db, $RigsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int?> maxPowerW = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
          }) =>
              RigsCompanion(
            id: id,
            name: name,
            description: description,
            maxPowerW: maxPowerW,
            createdAt: createdAt,
            archived: archived,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            Value<int?> maxPowerW = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
          }) =>
              RigsCompanion.insert(
            id: id,
            name: name,
            description: description,
            maxPowerW: maxPowerW,
            createdAt: createdAt,
            archived: archived,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RigsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RigsTable,
    Rig,
    $$RigsTableFilterComposer,
    $$RigsTableOrderingComposer,
    $$RigsTableAnnotationComposer,
    $$RigsTableCreateCompanionBuilder,
    $$RigsTableUpdateCompanionBuilder,
    (Rig, BaseReferences<_$AppDatabase, $RigsTable, Rig>),
    Rig,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QsosTableTableManager get qsos => $$QsosTableTableManager(_db, _db.qsos);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$CallsignGridsTableTableManager get callsignGrids =>
      $$CallsignGridsTableTableManager(_db, _db.callsignGrids);
  $$AntennasTableTableManager get antennas =>
      $$AntennasTableTableManager(_db, _db.antennas);
  $$RigsTableTableManager get rigs => $$RigsTableTableManager(_db, _db.rigs);
}
