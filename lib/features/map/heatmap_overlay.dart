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

    if (samples.length < 3) {
      if (mounted) {
        setState(() {
          _image = null;
          _bounds = null;
        });
      }
      return;
    }

    final hull = _convexHull(samples.map((sample) => sample.point).toList());
    if (hull.length < 3) return;

    var minLat = hull.first.latitude;
    var maxLat = minLat;
    var minLon = hull.first.longitude;
    var maxLon = minLon;
    for (final point in hull.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    // A small visual margin prevents the polygon stroke touching tile edges.
    final latPad = math.max((maxLat - minLat) * 0.04, 0.05);
    final lonPad = math.max((maxLon - minLon) * 0.04, 0.05);
    minLat -= latPad;
    maxLat += latPad;
    minLon -= lonPad;
    maxLon += lonPad;

    final latSpan = math.max(maxLat - minLat, 0.001);
    final lonSpan = math.max(maxLon - minLon, 0.001);
    final aspect = lonSpan / latSpan;
    const longestSide = 640;
    final width = math.max(
      160,
      aspect >= 1 ? longestSide : (longestSide * aspect).round(),
    );
    final height = math.max(
      160,
      aspect >= 1 ? (longestSide / aspect).round() : longestSide,
    );

    Offset project(LatLng point) => Offset(
      (point.longitude - minLon) / lonSpan * (width - 1),
      (maxLat - point.latitude) / latSpan * (height - 1),
    );

    final projectedHull = hull.map(project).toList();
    final projectedSamples = samples
        .map((sample) => _ProjectedSample(project(sample.point), sample.report))
        .toList();
    final pixels = Uint8List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = Offset(x + 0.5, y + 0.5);
        if (!_insidePolygon(pixel, projectedHull)) continue;

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
        final offset = (y * width + x) * 4;
        pixels[offset] = color.red;
        pixels[offset + 1] = color.green;
        pixels[offset + 2] = color.blue;
        pixels[offset + 3] = (190 * proximity).round();
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
      _bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
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

List<LatLng> _convexHull(List<LatLng> points) {
  if (points.length <= 2) return List.of(points);
  final sorted = List<LatLng>.of(points)
    ..sort((a, b) {
      final longitude = a.longitude.compareTo(b.longitude);
      return longitude != 0 ? longitude : a.latitude.compareTo(b.latitude);
    });

  double cross(LatLng origin, LatLng a, LatLng b) =>
      (a.longitude - origin.longitude) * (b.latitude - origin.latitude) -
      (a.latitude - origin.latitude) * (b.longitude - origin.longitude);

  final lower = <LatLng>[];
  for (final point in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }
  final upper = <LatLng>[];
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

bool _insidePolygon(Offset point, List<Offset> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final current = polygon[i];
    final previous = polygon[j];
    final intersects =
        (current.dy > point.dy) != (previous.dy > point.dy) &&
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
  ) => OneFrameImageStreamCompleter(
    Future.value(ImageInfo(image: image, scale: 1)),
  );

  @override
  bool operator ==(Object other) =>
      other is _UiImageProvider && identical(other.image, image);

  @override
  int get hashCode => image.hashCode;
}
