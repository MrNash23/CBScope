/// CB (11 m) callsign → country lookup.
///
/// The 11 m CB "Alpha Tango" style callsigns use a numeric division prefix
/// that maps to a country/region (mostly following the WPX-like allocation
/// used across European CB DX clubs). Not every CB org uses the same table,
/// so this only covers the widely-agreed defaults — good enough to fill an
/// empty `country` field on import for the common cases.
String? countryFromCbCallsign(String callsign) {
  final c = callsign.trim().toUpperCase();
  if (c.isEmpty) return null;

  // Split leading digits from the rest — CB prefixes are 1-3 leading digits.
  final match = RegExp(r'^(\d{1,3})').firstMatch(c);
  if (match == null) return null;
  final prefix = int.tryParse(match.group(1)!);
  if (prefix == null) return null;

  return _cbPrefixCountry[prefix];
}

/// Widely-used European CB DX division → country map. Add to this table over
/// time; empty result means "unknown, don't overwrite whatever the ADIF said".
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
  26: 'Turkey',
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
