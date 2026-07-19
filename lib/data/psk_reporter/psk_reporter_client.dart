import 'dart:async';
import 'dart:convert';
import 'dart:io';

// jsonDecode is no longer used since the endpoint returns XML — keeping the
// convert import for utf8.

/// Parse the flat list of `<receptionReport ... />` self-closing tags
/// returned by PSK Reporter. Returns each as a map of attribute → value.
Iterable<Map<String, String>> _parseReceptionReportsXml(String body) sync* {
  final tag = RegExp(r'<receptionReport\b([^/>]*)/>', dotAll: true);
  final attr = RegExp(r'(\w+)="([^"]*)"');
  for (final m in tag.allMatches(body)) {
    final rawAttrs = m.group(1) ?? '';
    final map = <String, String>{};
    for (final a in attr.allMatches(rawAttrs)) {
      map[a.group(1)!] = a.group(2)!;
    }
    yield map;
  }
}

/// Thin HTTP client for retrieve.pskreporter.info.
///
/// The public API returns activity reports for a callsign. We use it as a
/// last-resort fallback to find a locator for CB callsigns that aren't in
/// our own logbook cache — mirroring the manual "look them up on PSK
/// Reporter" workflow.
///
/// Politeness policy (enforced in-process):
///   * Minimum 60 s between requests to any endpoint
///   * Results cached by the caller (we don't cache in-memory here)
///   * Times out after 8 s
class PskReporterClient {
  DateTime? _lastRequest;
  Future<void>? _inflightThrottle;
  final Duration minInterval;
  final Duration timeout;
  final HttpClient _http;

  /// Serialises callers so back-to-back calls wait for [minInterval]
  /// instead of racing / throwing.
  Future<void> _throttle() async {
    // Chain onto any in-flight throttle so callers queue in FIFO order.
    final prev = _inflightThrottle;
    final completer = Completer<void>();
    _inflightThrottle = completer.future;
    if (prev != null) await prev;

    final now = DateTime.now();
    if (_lastRequest != null) {
      final since = now.difference(_lastRequest!);
      if (since < minInterval) {
        await Future<void>.delayed(minInterval - since);
      }
    }
    _lastRequest = DateTime.now();
    completer.complete();
  }

  PskReporterClient({
    // PSK Reporter docs ask polling clients to stay under 1 request/minute,
    // but interactive apps that fetch on-demand are fine with a shorter
    // window. 15 s balances politeness with responsive UI.
    this.minInterval = const Duration(seconds: 15),
    // PSK Reporter's servers are slow / occasionally return 503 under load.
    // Give the request a full 30 s and follow it up with automatic retries.
    this.timeout = const Duration(seconds: 30),
  }) : _http = HttpClient()..userAgent = 'CBScope/0.1 (11m CB companion)';

  /// Returns the most recent locator reported for [callsign] in the last
  /// [lookbackDays], or null if the API has nothing.
  Future<PskReport?> lookup(String callsign, {int lookbackDays = 30}) async {
    await _throttle();

    final flowSecs = -lookbackDays * 24 * 3600;
    // PSK Reporter's HTTP endpoint returns XML — we parse the flat list of
    // <receptionReport ...> tags ourselves. (The `modify=json` param is
    // documented but sometimes still returns XML depending on the host.)
    final uri = Uri.https('retrieve.pskreporter.info', '/query', {
      'senderCallsign': callsign.toUpperCase(),
      'flowStartSeconds': '$flowSecs',
      'rronly': '1',
    });

    return _getWithRetry(
        uri, (body) => _parseNewestReport(body, callsign), null);
  }

  /// Fetch all recent reports where [myCall] appears in the given [direction].
  ///
  /// - direction=sent     → we were the transmitter (senderCallsign=myCall).
  ///   Each spot means "someone heard me at that receiver location".
  /// - direction=received → we were the receiver (receiverCallsign=myCall).
  ///   Each spot means "I heard this DX from their transmitter location".
  ///
  /// Uses the same 60s min-interval rate limit.
  Future<List<PskSpot>> fetchSpots({
    required String myCall,
    required PskDirection direction,
    Duration since = const Duration(hours: 6),
  }) async {
    // The public API explicitly rejects lookbacks over 24h and often times
    // out on expensive 24h callsign queries. Longer CBScope views therefore
    // come from our rolling cache; the fresh sync uses a bounded 6h window
    // and progressively falls back when PSK Reporter's backend is busy.
    final requested =
        since > const Duration(hours: 6) ? const Duration(hours: 6) : since;
    final windows = <Duration>[
      requested,
      if (requested > const Duration(hours: 1)) const Duration(hours: 1),
      if (requested > const Duration(minutes: 15)) const Duration(minutes: 15),
    ];

    Object? lastError;
    for (final window in windows.toSet()) {
      await _throttle();
      final params = <String, String>{
        'flowStartSeconds': '${-window.inSeconds}',
        'rronly': '1',
        'rptlimit': '5000',
        // CBScope is specifically an 11m FT8 application. These constraints
        // materially reduce load on PSK Reporter's shared query service.
        'mode': 'FT8',
        'frange': '26000000-28000000',
        if (direction == PskDirection.sent)
          'senderCallsign': myCall.toUpperCase(),
        if (direction == PskDirection.received)
          'receiverCallsign': myCall.toUpperCase(),
      };
      final uri = Uri.https('retrieve.pskreporter.info', '/query', params);
      try {
        return await _getWithRetry(
          uri,
          (body) => _parseSpots(body, myCall, direction),
          const [],
          throwOnFailure: true,
          maxAttempts: 1,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw PskReporterUnavailable(lastError);
  }

  /// GET [uri] with one retry on 503 / timeout. Uses long backoff so we
  /// don't hammer PSK Reporter (they aggressively 503 offending clients).
  Future<T> _getWithRetry<T>(
    Uri uri,
    T Function(String body) parse,
    T empty, {
    bool throwOnFailure = false,
    int maxAttempts = 2,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final req = await _http.getUrl(uri).timeout(timeout);
        // PSK Reporter's server returns 503 for requests that carry Dart's
        // default `Accept-Encoding: gzip`. Force identity + a permissive
        // Accept + close so the server treats us like curl.
        req.headers.removeAll(HttpHeaders.acceptEncodingHeader);
        req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        req.headers.set(HttpHeaders.acceptHeader, '*/*');
        req.headers.set(HttpHeaders.connectionHeader, 'close');
        req.persistentConnection = false;
        final resp = await req.close().timeout(timeout);
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          return parse(body);
        }
        if (resp.statusCode == 503 && attempt < maxAttempts - 1) {
          // One long backoff, then give up — we'll try again on the next
          // 5-min poll cycle.
          await Future<void>.delayed(const Duration(seconds: 45));
          continue;
        }
        if (throwOnFailure) {
          throw HttpException(
            'PSK Reporter HTTP ${resp.statusCode}',
            uri: uri,
          );
        }
        return empty;
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts - 1) {
          if (throwOnFailure) throw PskReporterUnavailable(lastError);
          return empty;
        }
        await Future<void>.delayed(const Duration(seconds: 30));
      }
    }
    if (throwOnFailure) throw PskReporterUnavailable(lastError);
    return empty;
  }

  List<PskSpot> _parseSpots(
      String body, String myCall, PskDirection direction) {
    final out = <PskSpot>[];
    final me = myCall.toUpperCase();
    for (final r in _parseReceptionReportsXml(body)) {
      final sender = (r['senderCallsign'] ?? '').toUpperCase();
      final receiver = (r['receiverCallsign'] ?? '').toUpperCase();
      final senderLoc = (r['senderLocator'] ?? '').toUpperCase();
      final receiverLoc = (r['receiverLocator'] ?? '').toUpperCase();
      final ts = int.tryParse(r['flowStartSeconds'] ?? '0') ?? 0;
      final at = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
      final freqHz = int.tryParse(r['frequency'] ?? '0') ?? 0;
      final snr = int.tryParse(r['sNR'] ?? '0') ?? 0;
      final mode = r['mode'] ?? '';

      String otherCall, otherGrid;
      if (direction == PskDirection.sent) {
        if (sender != me) continue;
        otherCall = receiver;
        otherGrid = receiverLoc;
      } else {
        if (receiver != me) continue;
        otherCall = sender;
        otherGrid = senderLoc;
      }
      if (otherGrid.length < 4) continue;
      out.add(PskSpot(
        otherCall: otherCall,
        otherGrid: otherGrid,
        direction: direction,
        at: at,
        freqHz: freqHz,
        snr: snr,
        mode: mode,
      ));
    }
    return out;
  }

  PskReport? _parseNewestReport(String body, String callsign) {
    PskReport? newest;
    final target = callsign.toUpperCase();
    for (final r in _parseReceptionReportsXml(body)) {
      final sender = (r['senderCallsign'] ?? '').toUpperCase();
      final loc = (r['senderLocator'] ?? '');
      if (sender != target || loc.length < 4) continue;
      final ts = int.tryParse(r['flowStartSeconds'] ?? '0') ?? 0;
      final at = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
      if (newest == null || at.isAfter(newest.at)) {
        newest = PskReport(callsign: sender, grid: loc.toUpperCase(), at: at);
      }
    }
    return newest;
  }

  void close() => _http.close(force: true);
}

class PskReport {
  final String callsign;
  final String grid;
  final DateTime at;
  const PskReport(
      {required this.callsign, required this.grid, required this.at});
}

enum PskDirection { sent, received }

class PskSpot {
  /// Callsign of the "other" party (not the user).
  final String otherCall;

  /// Locator of the other party (that's where we plot the marker).
  final String otherGrid;
  final PskDirection direction;
  final DateTime at;
  final int freqHz;
  final int snr;
  final String mode;
  const PskSpot({
    required this.otherCall,
    required this.otherGrid,
    required this.direction,
    required this.at,
    required this.freqHz,
    required this.snr,
    required this.mode,
  });
}

// (Rate-limiting is now handled transparently by [_throttle] — the client
//  awaits the minimum interval instead of throwing. Kept as an unused stub
//  in case some callers still catch it.)
class PskReporterRateLimited implements Exception {
  const PskReporterRateLimited();
  @override
  String toString() => 'PskReporterRateLimited';
}

class PskReporterUnavailable implements Exception {
  final Object? cause;
  const PskReporterUnavailable([this.cause]);

  @override
  String toString() =>
      'PskReporterUnavailable${cause == null ? '' : ': $cause'}';
}
