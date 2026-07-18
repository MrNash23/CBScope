import 'package:flutter_test/flutter_test.dart';
import 'package:qso_book/core/util/dedup_key.dart';

void main() {
  test('dedup key is stable', () {
    final k1 = qsoDedupKey(
      call: 'K1ABC',
      timeOnUtc: DateTime.utc(2026, 1, 1, 12, 0, 15),
      band: '20m',
      mode: 'FT8',
    );
    final k2 = qsoDedupKey(
      call: 'k1abc',
      timeOnUtc: DateTime.utc(2026, 1, 1, 12, 0, 45),
      band: '20M',
      mode: 'ft8',
    );
    expect(k1, k2, reason: 'same minute + call + band + mode should dedup');
  });

  test('freqToBand', () {
    expect(freqToBand(14074000), '20m');
    expect(freqToBand(7074000), '40m');
    expect(freqToBand(50313000), '6m');
  });
}
