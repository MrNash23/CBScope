import 'package:flutter_test/flutter_test.dart';
import 'package:qso_book/core/util/maidenhead.dart';

void main() {
  group('gridToLatLng', () {
    test('4-char JO62 (near Berlin, DE)', () {
      final ll = gridToLatLng('JO62')!;
      // Center of JO62 = 13°E, 52.5°N
      expect(ll.longitude, closeTo(13.0, 0.1));
      expect(ll.latitude,  closeTo(52.5, 0.1));
    });

    test('4-char IO91 (near London)', () {
      final ll = gridToLatLng('IO91')!;
      // Center of IO91 = -1°E, 51.5°N
      expect(ll.longitude, closeTo(-1.0, 0.1));
      expect(ll.latitude,  closeTo(51.5, 0.1));
    });

    test('6-char FN31PR (near Hartford, CT)', () {
      final ll = gridToLatLng('FN31PR')!;
      expect(ll.latitude,  closeTo(41.72, 0.1));
      expect(ll.longitude, closeTo(-72.71, 0.1));
    });

    test('invalid returns null', () {
      expect(gridToLatLng(null), isNull);
      expect(gridToLatLng(''), isNull);
      expect(gridToLatLng('ZZ99'), isNull);
    });
  });

  group('latLngToGrid', () {
    test('round-trip Berlin', () {
      // Berlin ≈ 52.52N, 13.40E → JO62
      final g = latLngToGrid(52.52, 13.40);
      expect(g.substring(0, 4), 'JO62');
    });

    test('round-trip London', () {
      // London ≈ 51.50N, -0.13E → IO91
      final g = latLngToGrid(51.50, -0.13);
      expect(g.substring(0, 4), 'IO91');
    });
  });
}
