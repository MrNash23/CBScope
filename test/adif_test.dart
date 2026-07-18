import 'package:flutter_test/flutter_test.dart';
import 'package:qso_book/data/adif/adif_parser.dart';

void main() {
  test('parses a minimal ADIF file', () {
    const s = '''Sample export
<adif_ver:5>3.1.4
<programid:6>WSJT-X
<eoh>
<call:5>K1ABC <qso_date:8>20260101 <time_on:6>120000 <band:3>20m <mode:3>FT8 <rst_sent:3>-05 <rst_rcvd:3>-11 <gridsquare:6>FN31PR <eor>
<call:6>DL2XYZ <qso_date:8>20260101 <time_on:4>1215 <band:3>40m <mode:3>FT8 <eor>
''';
    final rs = AdifParser.parse(s);
    expect(rs.length, 2);
    expect(rs.first.call(), 'K1ABC');
    expect(rs.first.gridsquare(), 'FN31PR');
    expect(rs.first.timeOnUtc()!.toIso8601String(), '2026-01-01T12:00:00.000Z');
    expect(rs[1].call(), 'DL2XYZ');
    expect(rs[1].timeOnUtc()!.toIso8601String(), '2026-01-01T12:15:00.000Z');
  });

  test('streaming parser leaves truncated record unconsumed', () {
    const s = '''<eoh>
<call:5>K1ABC <qso_date:8>20260101 <time_on:6>120000 <band:3>20m <mode:3>FT8 <eor>
<call:6>DL2XY''';
    final r = AdifParser.parseStreaming(s);
    expect(r.records.length, 1);
    expect(s.substring(r.consumed).contains('DL2XY'), isTrue);
  });
}
