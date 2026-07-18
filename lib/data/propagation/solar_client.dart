import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Fetches solar / propagation data from hamqsl.com (N0NBH's free feed).
///
/// The XML is stable and updated every ~15 min. No API key required.
/// Sample fields we care about for 11m CB:
///   solarflux, kindex, aindex, xray, sunspots, solarwind,
///   calculatedconditions/band(name, time)
class SolarClient {
  final HttpClient _http;
  SolarClient() : _http = HttpClient()..userAgent = 'CBScope/0.1 (11m CB companion)';

  Future<SolarData?> fetch({Duration timeout = const Duration(seconds: 8)}) async {
    final uri = Uri.https('www.hamqsl.com', '/solarxml.php');
    try {
      final req = await _http.getUrl(uri).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      return _parse(body);
    } catch (_) {
      return null;
    }
  }

  SolarData? _parse(String xml) {
    String? tag(String name) {
      final m = RegExp('<$name>\\s*(.*?)\\s*</$name>', dotAll: true).firstMatch(xml);
      return m?.group(1)?.trim();
    }

    final bands = <BandCondition>[];
    final bandRe = RegExp(
      r'<band\s+name="([^"]+)"\s+time="([^"]+)">\s*([^<]+)\s*</band>',
      caseSensitive: false,
    );
    for (final m in bandRe.allMatches(xml)) {
      bands.add(BandCondition(
        band: m.group(1)!.trim(),
        time: m.group(2)!.trim().toLowerCase(),
        condition: m.group(3)!.trim(),
      ));
    }

    final sfi = double.tryParse(tag('solarflux') ?? '');
    if (sfi == null && bands.isEmpty) return null;

    return SolarData(
      sfi: sfi,
      kIndex: double.tryParse(tag('kindex') ?? ''),
      aIndex: double.tryParse(tag('aindex') ?? ''),
      xray: tag('xray'),
      sunspots: int.tryParse(tag('sunspots') ?? ''),
      solarWind: double.tryParse(tag('solarwind') ?? ''),
      magneticField: double.tryParse(tag('magneticfield') ?? ''),
      updated: tag('updated'),
      bands: bands,
    );
  }

  void close() => _http.close(force: true);
}

class SolarData {
  final double? sfi;
  final double? kIndex;
  final double? aIndex;
  final String? xray;
  final int? sunspots;
  final double? solarWind;
  final double? magneticField;
  final String? updated;
  final List<BandCondition> bands;

  const SolarData({
    required this.sfi,
    required this.kIndex,
    required this.aIndex,
    required this.xray,
    required this.sunspots,
    required this.solarWind,
    required this.magneticField,
    required this.updated,
    required this.bands,
  });

  /// Condition for the 10-12 m band range (relevant for 11m CB) at
  /// [dayNight] ('day' or 'night'). Returns null if not present.
  String? twelveTenCondition(String dayNight) {
    for (final b in bands) {
      final n = b.band.toLowerCase().replaceAll(' ', '');
      if ((n.contains('12m') && n.contains('10m')) || n == '12m-10m') {
        if (b.time == dayNight) return b.condition;
      }
    }
    return null;
  }
}

class BandCondition {
  final String band;
  final String time;
  final String condition;
  const BandCondition({required this.band, required this.time, required this.condition});
}
