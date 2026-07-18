/// Minimal ADIF (.adi) parser sufficient for WSJT-X and most logger exports.
///
/// Format: `<FIELD:LEN[:T]>DATA` repeated; records terminated by `<EOR>`;
/// optional header terminated by `<EOH>`. Field names are case-insensitive.
class AdifRecord {
  final Map<String, String> fields; // lowercased keys
  const AdifRecord(this.fields);

  String? call() => fields['call'];
  String? band() => fields['band'];
  String? mode() => fields['mode'];
  String? submode() => fields['submode'];
  String? qsoDate() => fields['qso_date'];
  String? timeOn() => fields['time_on'];
  String? timeOff() => fields['time_off'];
  String? freqMhz() => fields['freq'];
  String? rstSent() => fields['rst_sent'];
  String? rstRcvd() => fields['rst_rcvd'];
  String? gridsquare() => fields['gridsquare'];
  String? myGridsquare() => fields['my_gridsquare'];
  String? stationCallsign() => fields['station_callsign'];
  String? operator_() => fields['operator'];
  String? name() => fields['name'];
  String? country() => fields['country'];
  String? dxcc() => fields['dxcc'];
  String? comment() => fields['comment'];

  DateTime? timeOnUtc() {
    final d = qsoDate();
    final t = timeOn();
    if (d == null || d.length != 8) return null;
    final y = int.tryParse(d.substring(0, 4));
    final mo = int.tryParse(d.substring(4, 6));
    final dd = int.tryParse(d.substring(6, 8));
    if (y == null || mo == null || dd == null) return null;
    int hh = 0, mm = 0, ss = 0;
    if (t != null && t.length >= 4) {
      hh = int.tryParse(t.substring(0, 2)) ?? 0;
      mm = int.tryParse(t.substring(2, 4)) ?? 0;
      if (t.length >= 6) ss = int.tryParse(t.substring(4, 6)) ?? 0;
    }
    return DateTime.utc(y, mo, dd, hh, mm, ss);
  }
}

class AdifParser {
  static List<AdifRecord> parse(String input) {
    final records = <AdifRecord>[];
    int i = 0;
    // Skip header if present: content up to <EOH> (case-insensitive), if any.
    final lower = input.toLowerCase();
    final eoh = lower.indexOf('<eoh>');
    if (eoh >= 0) {
      i = eoh + 5;
    } else if (input.isNotEmpty && input[0] != '<') {
      // header without <eoh>? skip to first '<'
      final firstTag = input.indexOf('<');
      if (firstTag < 0) return records;
      i = firstTag;
    }

    Map<String, String> current = {};
    while (i < input.length) {
      final lt = input.indexOf('<', i);
      if (lt < 0) break;
      final gt = input.indexOf('>', lt + 1);
      if (gt < 0) break;
      final tag = input.substring(lt + 1, gt).trim();
      i = gt + 1;
      if (tag.isEmpty) continue;
      final tagLower = tag.toLowerCase();

      if (tagLower == 'eor') {
        if (current.isNotEmpty) {
          records.add(AdifRecord(Map.unmodifiable(current)));
          current = {};
        }
        continue;
      }
      if (tagLower == 'eoh') continue;

      // Field tag: name:length[:type]
      final parts = tag.split(':');
      final name = parts[0].toLowerCase();
      if (parts.length < 2) continue;
      final len = int.tryParse(parts[1]);
      if (len == null || len < 0) continue;
      if (i + len > input.length) break;
      final value = input.substring(i, i + len);
      i += len;
      current[name] = value;
    }
    // Emit trailing record if the file wasn't terminated with <EOR>
    if (current.isNotEmpty) records.add(AdifRecord(Map.unmodifiable(current)));
    return records;
  }

  /// Streaming variant: returns records and the number of bytes actually
  /// consumed from [input]. Anything after the last `<EOR>` is left
  /// unconsumed so a tail watcher can resume with the leftover.
  static ({List<AdifRecord> records, int consumed}) parseStreaming(String input) {
    final lower = input.toLowerCase();
    int start = 0;
    final eoh = lower.indexOf('<eoh>');
    if (eoh >= 0) start = eoh + 5;

    final records = <AdifRecord>[];
    int i = start;
    int lastEor = start;
    Map<String, String> current = {};
    while (i < input.length) {
      final lt = input.indexOf('<', i);
      if (lt < 0) break;
      final gt = input.indexOf('>', lt + 1);
      if (gt < 0) break;
      final tag = input.substring(lt + 1, gt).trim();
      i = gt + 1;
      if (tag.isEmpty) continue;
      final tagLower = tag.toLowerCase();

      if (tagLower == 'eor') {
        if (current.isNotEmpty) {
          records.add(AdifRecord(Map.unmodifiable(current)));
          current = {};
        }
        lastEor = i;
        continue;
      }
      if (tagLower == 'eoh') continue;

      final parts = tag.split(':');
      final name = parts[0].toLowerCase();
      if (parts.length < 2) continue;
      final len = int.tryParse(parts[1]);
      if (len == null || len < 0) continue;
      if (i + len > input.length) {
        // truncated — stop consuming here; leave from lastEor
        break;
      }
      final value = input.substring(i, i + len);
      i += len;
      current[name] = value;
    }
    return (records: records, consumed: lastEor);
  }
}

String buildAdifExport(Iterable<Map<String, String>> records, {String? programId}) {
  final b = StringBuffer();
  b.writeln('CBScope ADIF export');
  b.writeln('<adif_ver:5>3.1.4');
  b.writeln('<programid:${programId?.length ?? 7}>${programId ?? 'CBScope'}');
  b.writeln('<eoh>');
  for (final r in records) {
    for (final e in r.entries) {
      final key = e.key.toUpperCase();
      final value = e.value;
      b.write('<$key:${value.length}>$value ');
    }
    b.writeln('<EOR>');
  }
  return b.toString();
}
