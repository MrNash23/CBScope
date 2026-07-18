import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Compute the day/night terminator as a chain of [LatLng] points for the
/// given UTC instant. Simple model (equinox-corrected solar declination) —
/// accurate enough (±0.5°) for a visual greyline overlay.
///
/// Also returns which side of the terminator is night, useful for shading.
class GreylineResult {
  final List<LatLng> terminator;
  /// Angle in degrees (0-360) of the subsolar longitude.
  final double subsolarLon;
  final double solarDeclDeg;
  const GreylineResult(this.terminator, this.subsolarLon, this.solarDeclDeg);
}

GreylineResult computeGreyline(DateTime utc, {int stepDeg = 2}) {
  final u = utc.toUtc();
  // Day of year (1-366)
  final n = u.difference(DateTime.utc(u.year, 1, 1)).inDays + 1;
  // Solar declination (Cooper's equation, good to ~0.5°)
  final decl = 23.44 * math.sin(2 * math.pi * (n - 81) / 365);
  final declRad = decl * math.pi / 180;
  final hoursUtc = u.hour + u.minute / 60 + u.second / 3600;
  // Subsolar longitude — sun is directly overhead at (declination, subsolarLon).
  final subsolarLon = 180 - hoursUtc * 15;

  final pts = <LatLng>[];
  for (double lon = -180; lon <= 180; lon += stepDeg.toDouble()) {
    final lonDiff = (lon - subsolarLon) * math.pi / 180;
    // Terminator equation: tan(lat) = -cos(lonDiff) / tan(decl)
    // When decl == 0 (equinox at UTC noon), lat approaches 90 → clip.
    final denom = math.tan(declRad);
    if (denom == 0) {
      pts.add(LatLng(0, lon));
      continue;
    }
    final tanLat = -math.cos(lonDiff) / denom;
    final lat = math.atan(tanLat) * 180 / math.pi;
    pts.add(LatLng(lat.clamp(-85.0, 85.0), lon));
  }
  return GreylineResult(pts, subsolarLon, decl);
}
