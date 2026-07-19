import 'package:flutter_test/flutter_test.dart';
import 'package:qso_book/data/wsjtx/messages.dart';

WsjtxDecode decode(String message) => WsjtxDecode(
      id: 'test',
      isNew: true,
      timeMs: 0,
      snr: -10,
      deltaTime: 0,
      deltaFreq: 1000,
      mode: 'FT8',
      message: message,
      lowConfidence: false,
      offAir: false,
    );

void main() {
  test('parses station and locator from a directed grid response', () {
    final message = decode('SZ4YSZ RV1AAG R FE41');
    expect(message.stationCall(), 'RV1AAG');
    expect(message.gridHint(), 'FE41');
    expect(message.cqCall(), isNull);
  });

  test('parses a normal CQ with arbitrary 11m callsign', () {
    final message = decode('CQ 14XX000 JO62');
    expect(message.stationCall(), '14XX000');
    expect(message.cqCall(), '14XX000');
    expect(message.gridHint(), 'JO62');
  });

  test('parses a directed report without inventing a locator', () {
    final message = decode('14XX000 14AB123 R-12');
    expect(message.stationCall(), '14AB123');
    expect(message.gridHint(), isNull);
  });

  test('parses a CQ modifier', () {
    final message = decode('CQ DX 14AB123 JN18');
    expect(message.stationCall(), '14AB123');
    expect(message.gridHint(), 'JN18');
  });
}
