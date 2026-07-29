import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// CB (11 m) callsign → country lookup.
///
/// The 11 m CB "Alpha Tango" style callsigns use a numeric division prefix
/// that maps to a country. The hard-coded table below is a best-effort
/// starting point — it's overlaid at lookup time by a "learned" map that
/// grows every time WSJT-CB's ADIF gives us a fresh (prefix, country)
/// pair, so the app self-corrects as the user works more DX.
String? countryFromCbCallsign(String callsign) {
  final prefix = _prefixOf(callsign);
  if (prefix == null) return null;
  return _learnedPrefixes[prefix] ?? _cbPrefixCountry[prefix];
}

/// Extract the leading 1–3 digit CB prefix from a callsign, or null if
/// the callsign doesn't start with digits.
int? _prefixOf(String callsign) {
  final c = callsign.trim().toUpperCase();
  if (c.isEmpty) return null;
  final match = RegExp(r'^(\d{1,3})').firstMatch(c);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// Runtime cache of (prefix → country) pairs learned from WSJT-CB's ADIF
/// output. Wins over the hard-coded table on lookup.
final Map<int, String> _learnedPrefixes = {};
SharedPreferences? _prefsRef;
const _prefsKey = 'cb.learnedPrefixes';

/// Load persisted learnings from SharedPreferences and remember the prefs
/// handle for future writes. Call once at app boot (from the prefs
/// provider). Cheap enough that calling it a second time is a no-op.
Future<void> initCbPrefixLearner(SharedPreferences prefs) async {
  _prefsRef = prefs;
  final raw = prefs.getString(_prefsKey);
  if (raw == null || raw.isEmpty) return;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _learnedPrefixes.clear();
    decoded.forEach((k, v) {
      final pfx = int.tryParse(k);
      if (pfx != null && v is String && v.isNotEmpty) {
        _learnedPrefixes[pfx] = v;
      }
    });
  } catch (_) {
    // Corrupt payload — start over.
  }
}

/// Remember a (callsign prefix, country) pair. No-op when either the
/// callsign has no numeric prefix, the country is empty, or the mapping
/// is already known. Fire-and-forget from callers.
void learnCbPrefixCountry(String callsign, String? country) {
  if (country == null || country.trim().isEmpty) return;
  final prefix = _prefixOf(callsign);
  if (prefix == null) return;
  final trimmed = country.trim();
  if (_learnedPrefixes[prefix] == trimmed) return;
  _learnedPrefixes[prefix] = trimmed;
  // Any encode/setString failure must NOT propagate — this is a
  // fire-and-forget best-effort persistence and an unhandled async error
  // here can crash the Dart isolate.
  try {
    final json = jsonEncode({
      for (final e in _learnedPrefixes.entries) e.key.toString(): e.value,
    });
    final f = _prefsRef?.setString(_prefsKey, json);
    if (f != null) f.catchError((_) => false);
  } catch (_) {
    // Swallow — the in-memory learning is already applied.
  }
}

/// Alpha Tango DX Group division → country map. The AT divisions are NOT
/// a simple sequential numbering of European countries — many entries
/// here are best-effort. Confirmed against WSJT-CB's own display:
///   13 → Germany, 14 → France, 26 → England.
/// If you see a wrong country label in a decode / voice announcement,
/// file it against this table.
const Map<int, String> _cbPrefixCountry = {
  1:  'Germany',
  2:  'United Kingdom',
  3:  'France',
  4:  'Spain',
  5:  'Italy',
  6:  'Belgium',
  7:  'Netherlands',
  8:  'Switzerland',
  9:  'Austria',
  10: 'Poland',
  11: 'Portugal',
  12: 'Ireland',
  13: 'Germany',
  14: 'France',
  15: 'Italy',
  16: 'Denmark',
  17: 'Norway',
  18: 'Sweden',
  19: 'Finland',
  20: 'Czech Republic',
  21: 'Slovakia',
  22: 'Hungary',
  23: 'Romania',
  24: 'Bulgaria',
  25: 'Greece',
  26: 'England',
  27: 'Russia',
  28: 'Ukraine',
  29: 'Belarus',
  30: 'Serbia',
  31: 'Croatia',
  32: 'Bosnia and Herzegovina',
  33: 'Slovenia',
  34: 'North Macedonia',
  35: 'Albania',
  36: 'Montenegro',
  37: 'Moldova',
  38: 'Lithuania',
  39: 'Latvia',
  40: 'Estonia',
  41: 'Iceland',
  42: 'Luxembourg',
  43: 'Malta',
  44: 'Cyprus',
  45: 'Andorra',
  46: 'Monaco',
  47: 'Liechtenstein',
  48: 'San Marino',
  49: 'Vatican City',
  50: 'Kosovo',
  51: 'Israel',
  60: 'Morocco',
  61: 'Algeria',
  62: 'Tunisia',
  63: 'Libya',
  64: 'Egypt',
  70: 'Canada',
  71: 'USA',
  72: 'Mexico',
  73: 'Brazil',
  74: 'Argentina',
  80: 'Japan',
  81: 'Australia',
  82: 'New Zealand',
};
