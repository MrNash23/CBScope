import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/maidenhead.dart';
import '../../data/db/database.dart';
import '../../providers/providers.dart';

/// Polar plot: azimuth (0° = North, clockwise) vs distance (km).
///
/// Each logged QSO becomes one dot placed at (bearing-from-me, distance).
/// Rings show 1000/2500/5000/10000 km. Bearing spokes at 30° steps with
/// N/E/S/W labels. Optimized for 11 m CB — good for spotting which direction
/// your antenna favours and the propagation reach.
class DistancePolarChart extends ConsumerWidget {
  const DistancePolarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qsos = ref.watch(allQsosProvider).valueOrNull ?? const <Qso>[];
    final s = ref.watch(settingsProvider);
    final me = gridToLatLng(s.myGrid);
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    if (me == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Set your grid locator in Settings to see the distance plot.',
              textAlign: TextAlign.center, style: t.bodySmall),
        ),
      );
    }

    final points = <_PolarPoint>[];
    double maxDist = 0;
    for (final q in qsos) {
      final to = gridToLatLng(q.gridsquare);
      if (to == null) continue;
      final d = const Distance().as(LengthUnit.Kilometer, me, to);
      if (d <= 0) continue;
      final b = bearingDegrees(me, to);
      points.add(_PolarPoint(bearing: b, distanceKm: d));
      if (d > maxDist) maxDist = d;
    }

    // Choose the outer ring: next round scale above the farthest QSO.
    // At least 1000 km so an empty log still shows a useful compass.
    final scale = _pickScale(maxDist);
    final unit = s.distanceUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Distances', style: t.titleSmall),
            const SizedBox(width: 8),
            Text('(bearing × range from ${s.myGrid ?? '?'})', style: t.bodySmall),
            const Spacer(),
            Text('${points.length} QSOs plotted',
                style: t.labelSmall?.copyWith(color: c.subtle)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final side = math.min(box.maxWidth, box.maxHeight);
              return Center(
                child: SizedBox(
                  width: side, height: side,
                  child: CustomPaint(
                    painter: _PolarPainter(
                      points: points,
                      scaleKm: scale.toDouble(),
                      rings: _rings(scale),
                      colors: c,
                      pointColor: s.qsoColor,
                      unit: unit,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  int _pickScale(double maxKm) {
    for (final s in const [1000, 2500, 5000, 7500, 10000, 15000, 20000]) {
      if (maxKm <= s) return s;
    }
    return 20000;
  }

  List<int> _rings(int scale) {
    switch (scale) {
      case 1000:  return const [250, 500, 750, 1000];
      case 2500:  return const [500, 1000, 1500, 2000, 2500];
      case 5000:  return const [1000, 2500, 5000];
      case 7500:  return const [2500, 5000, 7500];
      case 10000: return const [2500, 5000, 7500, 10000];
      case 15000: return const [5000, 10000, 15000];
      case 20000: return const [5000, 10000, 15000, 20000];
    }
    return [scale ~/ 2, scale];
  }
}

class _PolarPoint {
  final double bearing; // deg, 0=N
  final double distanceKm;
  const _PolarPoint({required this.bearing, required this.distanceKm});
}

class _PolarPainter extends CustomPainter {
  final List<_PolarPoint> points;
  final double scaleKm;
  final List<int> rings;
  final AppColors colors;
  final Color pointColor;
  final DistanceUnit unit;

  _PolarPainter({
    required this.points,
    required this.scaleKm,
    required this.rings,
    required this.colors,
    required this.pointColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 22;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = colors.border
      ..strokeWidth = 1;
    final spokePaint = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: colors.subtle, fontSize: 10, fontFamily: 'Menlo');
    final headingStyle = TextStyle(color: colors.text, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Menlo');

    // Rings
    for (final ringKm in rings) {
      final r = radius * (ringKm / scaleKm);
      canvas.drawCircle(center, r, ringPaint);
      final label = unit == DistanceUnit.mi
          ? '${(ringKm / 1.60934).round()} mi'
          : '$ringKm km';
      _paintText(canvas, label, center.translate(6, -r - 2), labelStyle);
    }

    // Spokes every 30°, labels at N/E/S/W
    for (int deg = 0; deg < 360; deg += 30) {
      final rad = (deg - 90) * math.pi / 180; // 0° up
      final p2 = center + Offset(math.cos(rad) * radius, math.sin(rad) * radius);
      canvas.drawLine(center, p2, spokePaint..color = colors.border.withOpacity(0.5));
    }
    for (final entry in const {0: 'N', 90: 'E', 180: 'S', 270: 'W'}.entries) {
      final rad = (entry.key - 90) * math.pi / 180;
      final labelP = center + Offset(math.cos(rad) * (radius + 12), math.sin(rad) * (radius + 12));
      _paintText(canvas, entry.value, labelP.translate(-6, -8), headingStyle);
    }

    // Center dot = my location
    canvas.drawCircle(center, 3, Paint()..color = colors.accent);

    // Points
    final pointPaint = Paint()..color = pointColor.withOpacity(0.75);
    final glowPaint  = Paint()..color = pointColor.withOpacity(0.25);
    for (final p in points) {
      final r = radius * (p.distanceKm / scaleKm).clamp(0.0, 1.0);
      final rad = (p.bearing - 90) * math.pi / 180;
      final pt = center + Offset(math.cos(rad) * r, math.sin(rad) * r);
      canvas.drawCircle(pt, 5, glowPaint);
      canvas.drawCircle(pt, 2.4, pointPaint);
    }
  }

  void _paintText(Canvas canvas, String s, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _PolarPainter old) =>
      old.points != points ||
      old.scaleKm != scaleKm ||
      old.pointColor != pointColor ||
      old.colors.accent != colors.accent;
}
