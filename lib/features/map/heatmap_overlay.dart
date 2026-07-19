import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/util/maidenhead.dart';
import '../../data/db/database.dart';

/// A continuous RST field clipped to the convex hull of the selected QSOs.
///
/// Every pixel inside the polygon receives an inverse-distance-weighted
/// interpolation of the surrounding received reports. This produces a single
/// coverage area whose colour changes continuously from weak (red) through
/// amber/green to strong (cyan), rather than a collection of circular blobs.
class HeatmapOverlay extends StatefulWidget {
  final List<Qso> qsos;

  const HeatmapOverlay({super.key, required this.qsos});

  @override
  State<HeatmapOverlay> createState() => _HeatmapOverlayState();
}

class _HeatmapOverlayState extends State<HeatmapOverlay> {
  ui.Image? _image;
  LatLngBounds? _bounds;
  int _inputHash = 0;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  @override
  void didUpdateWidget(covariant HeatmapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hashInputs() != _inputHash) _regenerate();
  }

  int _hashInputs() {
    var hash = widget.qsos.length;
    for (final qso in widget.qsos) {
      hash = Object.hash(hash, qso.id, qso.gridsquare, qso.rstRcvd);
    }
    return hash;
  }

  Future<void> _regenerate() async {
    _inputHash = _hashInputs();
    final samples = <_Sample>[];
    for (final qso in widget.qsos) {
      final point = gridToLatLng(qso.gridsquare);
      if (point == null) continue;
      samples.add(_Sample(point, _reportValue(qso.rstRcvd)));
    }

    if (samples.isEmpty) {
      if (mounted) {
        setState(() {
          _image = null;
          _bounds = null;
        });
      }
      return;
    }

    // Work in Web Mercator coordinates—the same projection flutter_map uses.
    // A latitude-linear raster drifts away from map markers at higher
    // latitudes even when both use the same geographic bounds.
    final mercatorSamples = samples
        .map(
          (sample) => _MercatorSample(
            Offset(_mercatorX(sample.point.longitude),
                _mercatorY(sample.point.latitude)),
            sample.report,
          ),
        )
        .toList();
    var minX = mercatorSamples.first.point.dx;
    var maxX = minX;
    var minY = mercatorSamples.first.point.dy;
    var maxY = minY;
    for (final sample in mercatorSamples.skip(1)) {
      minX = math.min(minX, sample.point.dx);
      maxX = math.max(maxX, sample.point.dx);
      minY = math.min(minY, sample.point.dy);
      maxY = math.max(maxY, sample.point.dy);
    }

    // Leave enough room to expand and round the hull while keeping all
    // measured points safely inside the final propagation envelope.
    final rawXSpan = math.max(maxX - minX, 0.0005);
    final rawYSpan = math.max(maxY - minY, 0.0005);
    minX -= rawXSpan * 0.20;
    maxX += rawXSpan * 0.20;
    minY -= rawYSpan * 0.20;
    maxY += rawYSpan * 0.20;

    final xSpan = math.max(maxX - minX, 0.0001);
    final ySpan = math.max(maxY - minY, 0.0001);
    final aspect = xSpan / ySpan;
    const longestSide = 640;
    final width = math.max(
      160,
      aspect >= 1 ? longestSide : (longestSide * aspect).round(),
    );
    final height = math.max(
      160,
      aspect >= 1 ? (longestSide / aspect).round() : longestSide,
    );

    Offset project(Offset point) => Offset(
          (point.dx - minX) / xSpan * (width - 1),
          (point.dy - minY) / ySpan * (height - 1),
        );

    final projectedSamples = mercatorSamples
        .map((sample) => _ProjectedSample(project(sample.point), sample.report))
        .toList();
    final samplePoints =
        projectedSamples.map((sample) => sample.point).toList();

    // Build the hull from a safety disc around every station. This is a
    // Minkowski-style buffer and, unlike radial expansion from a centroid,
    // guarantees that every contributing marker remains well inside even for
    // long, narrow or strongly asymmetric propagation footprints.
    const stationSafetyRadius = 34.0;
    final bufferedHull = _bufferedPointHull(
      samplePoints,
      stationSafetyRadius,
    );
    var projectedHull = _smoothClosed(bufferedHull, passes: 3);
    if (!samplePoints.every(
      (point) => _insideWithClearance(
        point,
        projectedHull,
        stationSafetyRadius * 0.35,
      ),
    )) {
      // Corner smoothing is intentionally allowed only when it preserves the
      // safety margin. The buffered hull is the guaranteed fallback.
      projectedHull = bufferedHull;
    }
    final pixels = Uint8List(width * height * 4);
    const edgeFeatherPx = 26.0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = Offset(x + 0.5, y + 0.5);
        final inside = _insidePolygon(pixel, projectedHull);
        final edgeDistance = _distanceToPolygonEdge(pixel, projectedHull);
        if (!inside && edgeDistance > edgeFeatherPx) continue;

        var weightedReport = 0.0;
        var totalWeight = 0.0;
        var nearestSquared = double.infinity;
        for (final sample in projectedSamples) {
          final dx = pixel.dx - sample.point.dx;
          final dy = pixel.dy - sample.point.dy;
          final distanceSquared = dx * dx + dy * dy;
          nearestSquared = math.min(nearestSquared, distanceSquared);
          // IDW power 1.7 gives smooth transitions without making distant
          // outliers dominate the entire coverage polygon.
          final weight = 1 / math.pow(distanceSquared + 16, 0.85);
          weightedReport += sample.report * weight;
          totalWeight += weight;
        }

        final report = weightedReport / totalWeight;
        final color = _reportColor(report);
        // Slightly lower alpha far away from every measured point, while
        // retaining one continuous filled polygon.
        final proximity = (1 - math.sqrt(nearestSquared) / 220).clamp(
          0.35,
          1.0,
        );
        // Keep the measured area solid up to the boundary and render a real
        // outer feather beyond it. Previously the fade happened only inside,
        // which looked like a hard cut-out rather than a blurred edge.
        final edgeFade = inside
            ? 1.0
            : 1 -
                _smoothStep(
                  0,
                  edgeFeatherPx,
                  edgeDistance,
                );
        final argb = color.toARGB32();
        final offset = (y * width + x) * 4;
        pixels[offset] = (argb >> 16) & 0xff;
        pixels[offset + 1] = (argb >> 8) & 0xff;
        pixels[offset + 2] = argb & 0xff;
        pixels[offset + 3] = (190 * proximity * edgeFade).round();
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (!mounted || _inputHash != _hashInputs()) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _bounds = LatLngBounds(
        LatLng(_inverseMercatorY(maxY), _inverseMercatorX(minX)),
        LatLng(_inverseMercatorY(minY), _inverseMercatorX(maxX)),
      );
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final bounds = _bounds;
    if (image == null || bounds == null) return const SizedBox.shrink();
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: bounds,
          opacity: 0.86,
          imageProvider: _UiImageProvider(image),
        ),
      ],
    );
  }
}

class _Sample {
  final LatLng point;
  final double report;

  const _Sample(this.point, this.report);
}

class _ProjectedSample {
  final Offset point;
  final double report;

  const _ProjectedSample(this.point, this.report);
}

class _MercatorSample {
  final Offset point;
  final double report;

  const _MercatorSample(this.point, this.report);
}

double _mercatorX(double longitude) => (longitude + 180) / 360;

double _mercatorY(double latitude) {
  final radians = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  return (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
      2;
}

double _inverseMercatorX(double x) => x * 360 - 180;

double _inverseMercatorY(double y) {
  final value = math.pi * (1 - 2 * y);
  final sinh = (math.exp(value) - math.exp(-value)) / 2;
  return math.atan(sinh) * 180 / math.pi;
}

double _reportValue(String? raw) {
  if (raw == null) return -20;
  return (double.tryParse(raw.replaceAll(RegExp(r'[^0-9+.-]'), '')) ?? -20)
      .clamp(-30, 10);
}

Color _reportColor(double report) {
  final t = ((report.clamp(-30, 10) + 30) / 40).toDouble();
  if (t < 0.33) {
    return Color.lerp(
      const Color(0xFFFF3B4E),
      const Color(0xFFFFB000),
      t / 0.33,
    )!;
  }
  if (t < 0.66) {
    return Color.lerp(
      const Color(0xFFFFB000),
      const Color(0xFF00FF88),
      (t - 0.33) / 0.33,
    )!;
  }
  return Color.lerp(
    const Color(0xFF00FF88),
    const Color(0xFF00E5FF),
    (t - 0.66) / 0.34,
  )!;
}

List<Offset> _convexHull(List<Offset> points) {
  if (points.length <= 2) return List.of(points);
  final sorted = List<Offset>.of(points)
    ..sort((a, b) {
      final x = a.dx.compareTo(b.dx);
      return x != 0 ? x : a.dy.compareTo(b.dy);
    });

  double cross(Offset origin, Offset a, Offset b) =>
      (a.dx - origin.dx) * (b.dy - origin.dy) -
      (a.dy - origin.dy) * (b.dx - origin.dx);

  final lower = <Offset>[];
  for (final point in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }
  final upper = <Offset>[];
  for (final point in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

/// Supplies a real area even when an equipment combination has only one or
/// two QSOs. Multiple tiny circles are hulled into either a round island or a
/// capsule, while 3+ locations use their actual outer hull.
List<Offset> _bufferedPointHull(List<Offset> points, double radius) {
  final support = <Offset>[];
  for (final point in points) {
    for (var step = 0; step < 24; step++) {
      final angle = step / 24 * math.pi * 2;
      support.add(
        point + Offset(math.cos(angle), math.sin(angle)) * radius,
      );
    }
  }
  return _convexHull(support);
}

/// Chaikin corner cutting is equivalent to chaining quadratic Bézier segments
/// and gives a stable, organic closed outline without overshooting the hull.
List<Offset> _smoothClosed(List<Offset> polygon, {int passes = 2}) {
  var result = List<Offset>.of(polygon);
  for (var pass = 0; pass < passes; pass++) {
    final next = <Offset>[];
    for (var i = 0; i < result.length; i++) {
      final a = result[i];
      final b = result[(i + 1) % result.length];
      next
        ..add(a * 0.75 + b * 0.25)
        ..add(a * 0.25 + b * 0.75);
    }
    result = next;
  }
  return result;
}

bool _insideWithClearance(
  Offset point,
  List<Offset> polygon,
  double clearance,
) {
  return _insidePolygon(point, polygon) &&
      _distanceToPolygonEdge(point, polygon) >= clearance;
}

double _distanceToSegment(Offset point, Offset a, Offset b) {
  final segment = b - a;
  final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared == 0) return (point - a).distance;
  final relative = point - a;
  final t =
      ((relative.dx * segment.dx + relative.dy * segment.dy) / lengthSquared)
          .clamp(0.0, 1.0);
  return (point - (a + segment * t)).distance;
}

double _distanceToPolygonEdge(Offset point, List<Offset> polygon) {
  var nearest = double.infinity;
  for (var i = 0; i < polygon.length; i++) {
    nearest = math.min(
      nearest,
      _distanceToSegment(
        point,
        polygon[i],
        polygon[(i + 1) % polygon.length],
      ),
    );
  }
  return nearest;
}

double _smoothStep(double edge0, double edge1, double value) {
  final t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

bool _insidePolygon(Offset point, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final current = polygon[i];
    final previous = polygon[j];
    final intersects = (current.dy > point.dy) != (previous.dy > point.dy) &&
        point.dx <
            (previous.dx - current.dx) *
                    (point.dy - current.dy) /
                    (previous.dy - current.dy + 1e-12) +
                current.dx;
    if (intersects) inside = !inside;
  }
  return inside;
}

class _UiImageProvider extends ImageProvider<_UiImageProvider> {
  final ui.Image image;

  const _UiImageProvider(this.image);

  @override
  Future<_UiImageProvider> obtainKey(ImageConfiguration configuration) async =>
      this;

  @override
  ImageStreamCompleter loadImage(
    _UiImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: image, scale: 1)),
      );

  @override
  bool operator ==(Object other) =>
      other is _UiImageProvider && identical(other.image, image);

  @override
  int get hashCode => image.hashCode;
}
