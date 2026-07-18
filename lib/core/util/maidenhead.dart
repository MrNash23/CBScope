import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Convert a Maidenhead grid locator (4 or 6 chars, optional 8) to its
/// center [LatLng]. Returns null for invalid input.
///
/// Format: `AA00aa[00]`, e.g. `JO62QN`.
///   - Chars 1-2: field (A-R), longitude 20°, latitude 10°
///   - Chars 3-4: square (0-9), longitude 2°, latitude 1°
///   - Chars 5-6: subsquare (a-x), longitude 5', latitude 2.5'
///   - Chars 7-8: extended square (0-9), longitude 30", latitude 15"
LatLng? gridToLatLng(String? grid) {
  if (grid == null) return null;
  final g = grid.trim();
  if (g.length < 4) return null;

  final up = g.toUpperCase();
  final lo = g.toLowerCase();

  final f1 = up.codeUnitAt(0) - 0x41; // A=0
  final f2 = up.codeUnitAt(1) - 0x41;
  if (f1 < 0 || f1 > 17 || f2 < 0 || f2 > 17) return null;

  final s1 = up.codeUnitAt(2) - 0x30; // '0'
  final s2 = up.codeUnitAt(3) - 0x30;
  if (s1 < 0 || s1 > 9 || s2 < 0 || s2 > 9) return null;

  double lon = -180 + f1 * 20 + s1 * 2;
  double lat = -90 + f2 * 10 + s2 * 1;

  // Default center of the 2°x1° square
  double lonSize = 2;
  double latSize = 1;

  if (g.length >= 6) {
    final ss1 = lo.codeUnitAt(4) - 0x61; // 'a'
    final ss2 = lo.codeUnitAt(5) - 0x61;
    if (ss1 < 0 || ss1 > 23 || ss2 < 0 || ss2 > 23) return null;
    lon += ss1 * (2 / 24);
    lat += ss2 * (1 / 24);
    lonSize = 2 / 24;
    latSize = 1 / 24;

    if (g.length >= 8) {
      final e1 = up.codeUnitAt(6) - 0x30;
      final e2 = up.codeUnitAt(7) - 0x30;
      if (e1 < 0 || e1 > 9 || e2 < 0 || e2 > 9) return null;
      lon += e1 * (lonSize / 10);
      lat += e2 * (latSize / 10);
      lonSize /= 10;
      latSize /= 10;
    }
  }

  return LatLng(lat + latSize / 2, lon + lonSize / 2);
}

/// Initial great-circle bearing (azimuth) in degrees from [from] to [to],
/// normalised to [0, 360). 0° = true north, 90° = east.
double bearingDegrees(LatLng from, LatLng to) {
  final phi1 = from.latitude  * math.pi / 180;
  final phi2 = to.latitude    * math.pi / 180;
  final dLon = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  final brg = math.atan2(y, x) * 180 / math.pi;
  return (brg + 360) % 360;
}

/// Round the given lat/lon to a Maidenhead 6-character grid.
String latLngToGrid(double lat, double lon) {
  double lonAdj = lon + 180;
  double latAdj = lat + 90;

  final f1 = (lonAdj / 20).floor();
  final f2 = (latAdj / 10).floor();
  lonAdj -= f1 * 20;
  latAdj -= f2 * 10;

  final s1 = (lonAdj / 2).floor();
  final s2 = latAdj.floor();
  lonAdj -= s1 * 2;
  latAdj -= s2;

  final ss1 = (lonAdj * 12).floor(); // 24 subsquares per 2°
  final ss2 = (latAdj * 24).floor();

  return String.fromCharCodes([
    0x41 + f1,
    0x41 + f2,
    0x30 + s1,
    0x30 + s2,
    0x61 + ss1,
    0x61 + ss2,
  ]);
}
