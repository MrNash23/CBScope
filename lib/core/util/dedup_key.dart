import 'package:intl/intl.dart';

/// Build a deterministic dedup key for a QSO across sources.
///
/// UDP `QSO Logged` and the ADIF tail can deliver the same contact —
/// we bucket time-on to the minute and join on (call, date, minute, band, mode).
String qsoDedupKey({
  required String call,
  required DateTime timeOnUtc,
  required String band,
  required String mode,
}) {
  final d = timeOnUtc.toUtc();
  final date = DateFormat('yyyyMMdd').format(d);
  final time = DateFormat('HHmm').format(d);
  return '${call.toUpperCase()}|$date|$time|${band.toUpperCase()}|${mode.toUpperCase()}';
}

/// Convert a frequency in Hz to an amateur radio band label (e.g. "20m").
String freqToBand(int hz) {
  final mhz = hz / 1e6;
  if (mhz < 0.2) return 'LF';
  if (mhz < 0.6) return '2200m';
  if (mhz < 1.9) return '630m';
  if (mhz < 2.0) return '160m';
  if (mhz >= 3.5 && mhz < 4.0) return '80m';
  if (mhz >= 5.2 && mhz < 5.5) return '60m';
  if (mhz >= 7.0 && mhz < 7.3) return '40m';
  if (mhz >= 10.1 && mhz < 10.15) return '30m';
  if (mhz >= 14.0 && mhz < 14.35) return '20m';
  if (mhz >= 18.068 && mhz < 18.168) return '17m';
  if (mhz >= 21.0 && mhz < 21.45) return '15m';
  if (mhz >= 24.89 && mhz < 24.99) return '12m';
  // 11 m CB / freeband — WSJT-CB emits `<band:3>11m` in ADIF, so the UDP path
  // must produce the same label or dedup misses and the row gets logged twice.
  if (mhz >= 26.9 && mhz < 27.5) return '11m';
  if (mhz >= 28.0 && mhz < 29.7) return '10m';
  if (mhz >= 50.0 && mhz < 54.0) return '6m';
  if (mhz >= 70.0 && mhz < 71.0) return '4m';
  if (mhz >= 144.0 && mhz < 148.0) return '2m';
  if (mhz >= 222.0 && mhz < 225.0) return '1.25m';
  if (mhz >= 420.0 && mhz < 450.0) return '70cm';
  if (mhz >= 902.0 && mhz < 928.0) return '33cm';
  if (mhz >= 1240.0 && mhz < 1300.0) return '23cm';
  return '${mhz.toStringAsFixed(3)}MHz';
}
