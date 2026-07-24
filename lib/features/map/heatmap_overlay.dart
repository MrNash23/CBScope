import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/util/maidenhead.dart';
import '../../data/db/database.dart';

/// Which end of an FT8 QSO supplies the signal report for the heatmap.
enum HeatmapSignalDirection {
  /// Outbound propagation: the report the other station gave us.
  send,

  /// Inbound propagation: the report we gave the other station.
  receive,
}

extension HeatmapSignalDirectionX on HeatmapSignalDirection {
  String get label => switch (this) {
        HeatmapSignalDirection.send => 'Send',
        HeatmapSignalDirection.receive => 'Receive',
      };

  String get explanation => switch (this) {
        HeatmapSignalDirection.send =>
          'How strongly the other stations heard you · RST_RCVD',
        HeatmapSignalDirection.receive =>
          'How strongly you heard the other stations · RST_SENT',
      };
}

/// A signal-propagation cloud made from independent radial station fields.
///
/// Every locator contributes a soft colour cloud based on its FT8 dB report.
/// Overlaps use a distance-weighted report average and never add intensity:
/// overlap therefore cannot imply a stronger signal than was measured.
/// Clouds independently decay to transparency; there is no enclosing polygon.
class HeatmapOverlay extends StatefulWidget {
  final List<Qso> qsos;
  final HeatmapSignalDirection direction;

  const HeatmapOverlay({
    super.key,
    required this.qsos,
    required this.direction,
  });

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
    var hash = Object.hash(widget.qsos.length, widget.direction);
    for (final qso in widget.qsos) {
      hash = Object.hash(
        hash,
        qso.id,
        qso.gridsquare,
        widget.direction == HeatmapSignalDirection.send
            ? qso.rstRcvd
            : qso.rstSent,
      );
    }
    return hash;
  }

  Future<void> _regenerate() async {
    _inputHash = _hashInputs();

    // Average repeated QSOs in the same locator. This prevents frequently
    // worked stations from becoming artificially opaque and keeps rendering
    // fast even for large logbooks.
    final grouped = <String, _SampleAccumulator>{};
    for (final qso in widget.qsos) {
      final grid = qso.gridsquare?.trim().toUpperCase();
      if (grid == null || grid.isEmpty) continue;
      final point = gridToLatLng(grid);
      final report = _parseReport(
        widget.direction == HeatmapSignalDirection.send
            ? qso.rstRcvd
            : qso.rstSent,
      );
      if (point == null || report == null) continue;
      grouped.putIfAbsent(grid, () => _SampleAccumulator(point)).add(report);
    }

    final samples = grouped.values
        .map((value) => _Sample(value.point, value.average))
        .toList(growable: false);
    if (samples.isEmpty) {
      if (mounted) {
        setState(() {
          _image?.dispose();
          _image = null;
          _bounds = null;
        });
      }
      return;
    }

    final mercatorSamples = samples
        .map(
          (sample) => _MercatorSample(
            Offset(
              _mercatorX(sample.point.longitude),
              _mercatorY(sample.point.latitude),
            ),
            sample.report,
          ),
        )
        .toList(growable: false);

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

    // Each station uses a long Gaussian tail. At 3.5 sigma it is already
    // visually transparent, so stopping there cannot reveal a circular edge.
    const innerLongestSide = 640.0;
    const cloudSigma = 40.0;
    const cloudExtent = cloudSigma * 3.5;
    const rasterPadding = cloudExtent + 12;
    final rawXSpan = math.max(maxX - minX, 0.0005);
    final rawYSpan = math.max(maxY - minY, 0.0005);
    final pixelsPerMercatorUnit =
        innerLongestSide / math.max(rawXSpan, rawYSpan);
    final innerWidth = math.max(1.0, rawXSpan * pixelsPerMercatorUnit);
    final innerHeight = math.max(1.0, rawYSpan * pixelsPerMercatorUnit);

    minX -= rasterPadding / pixelsPerMercatorUnit;
    maxX += rasterPadding / pixelsPerMercatorUnit;
    minY -= rasterPadding / pixelsPerMercatorUnit;
    maxY += rasterPadding / pixelsPerMercatorUnit;

    final xSpan = maxX - minX;
    final ySpan = maxY - minY;
    final width = (innerWidth + rasterPadding * 2).ceil();
    final height = (innerHeight + rasterPadding * 2).ceil();

    Offset project(Offset point) => Offset(
          (point.dx - minX) / xSpan * (width - 1),
          (point.dy - minY) / ySpan * (height - 1),
        );

    final pixelCount = width * height;
    final weightedReports = Float32List(pixelCount);
    final totalWeights = Float32List(pixelCount);
    final maximumOpacity = Float32List(pixelCount);
    const extentSquared = cloudExtent * cloudExtent;

    // Accumulate only inside each cloud's bounding box. Report values are
    // averaged by radial influence; opacity uses max(), never addition.
    for (final sample in mercatorSamples) {
      final center = project(sample.point);
      final left = math.max(0, (center.dx - cloudExtent).floor());
      final right = math.min(width - 1, (center.dx + cloudExtent).ceil());
      final top = math.max(0, (center.dy - cloudExtent).floor());
      final bottom = math.min(height - 1, (center.dy + cloudExtent).ceil());
      for (var y = top; y <= bottom; y++) {
        final dy = y + 0.5 - center.dy;
        for (var x = left; x <= right; x++) {
          final dx = x + 0.5 - center.dx;
          final distanceSquared = dx * dx + dy * dy;
          if (distanceSquared >= extentSquared) continue;
          final influence = _cloudInfluence(
            math.sqrt(distanceSquared),
            cloudSigma,
          );
          if (influence <= 0) continue;
          final index = y * width + x;
          weightedReports[index] += sample.report * influence;
          totalWeights[index] += influence;
          maximumOpacity[index] = math.max(maximumOpacity[index], influence);
        }
      }
    }

    final pixels = Uint8List(pixelCount * 4);
    for (var index = 0; index < pixelCount; index++) {
      final weight = totalWeights[index];
      if (weight <= 0) continue;
      final report = weightedReports[index] / weight;
      final color = _reportColor(report).toARGB32();
      final opacity = maximumOpacity[index].clamp(0.0, 1.0);
      final offset = index * 4;
      // PixelFormat.rgba8888 requires premultiplied alpha. Writing straight
      // RGB here leaves vivid colour in nearly transparent pixels and makes
      // the Gaussian tail look like a large solid circle.
      pixels[offset] = (((color >> 16) & 0xff) * opacity).round();
      pixels[offset + 1] = (((color >> 8) & 0xff) * opacity).round();
      pixels[offset + 2] = ((color & 0xff) * opacity).round();
      pixels[offset + 3] = (255 * opacity).round();
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
          opacity: 0.9,
          imageProvider: _UiImageProvider(image),
        ),
      ],
    );
  }
}

class _SampleAccumulator {
  final LatLng point;
  double _total = 0;
  int _count = 0;

  _SampleAccumulator(this.point);

  void add(double report) {
    _total += report;
    _count++;
  }

  double get average => _total / _count;
}

class _Sample {
  final LatLng point;
  final double report;

  const _Sample(this.point, this.report);
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

double? _parseReport(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return double.tryParse(raw.replaceAll(RegExp(r'[^0-9+.-]'), ''))
      ?.clamp(-30, 10)
      .toDouble();
}

double _cloudInfluence(double distance, double sigma) {
  final sigmaSquared = sigma * sigma;
  return 0.72 * math.exp(-(distance * distance) / (2 * sigmaSquared));
}

/// Public alias so map overlays (e.g. the legend) can render the same
/// gradient used by the heatmap raster.
Color heatmapReportColor(double report) => _reportColor(report);

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
