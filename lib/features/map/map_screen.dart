import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/maidenhead.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/propagation_card.dart';
import '../../data/db/database.dart';
import '../../data/db/qso_repository.dart' show ReviewState;
import '../../data/psk_reporter/psk_reporter_client.dart';
import '../../providers/providers.dart';

enum QsoAgeFilter { custom, last24h, week, month, year, all }

extension QsoAgeFilterX on QsoAgeFilter {
  String get label => switch (this) {
        QsoAgeFilter.custom  => 'Custom',
        QsoAgeFilter.last24h => 'Last 24 h',
        QsoAgeFilter.week    => 'Last week',
        QsoAgeFilter.month   => 'Last month',
        QsoAgeFilter.year    => 'Last year',
        QsoAgeFilter.all     => 'All time',
      };
  Duration? get maxAge => switch (this) {
        QsoAgeFilter.custom  => const Duration(hours: 24), // fallback, real value comes from slider
        QsoAgeFilter.last24h => const Duration(hours: 24),
        QsoAgeFilter.week    => const Duration(days: 7),
        QsoAgeFilter.month   => const Duration(days: 30),
        QsoAgeFilter.year    => const Duration(days: 365),
        QsoAgeFilter.all     => null,
      };
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  bool _showQsos = true;
  bool _showDecodes = true;
  bool _showLines = true;
  bool _showMe = true;
  bool _showPskSpots = true;
  bool _filtersOpen = false;
  QsoAgeFilter _ageFilter = QsoAgeFilter.all;
  int _ageCustomHours = 24; // used when _ageFilter == custom (1-720h)
  double _minSnr = -30; // dB
  Timer? _fadeTick;

  @override
  void initState() {
    super.initState();
    _fadeTick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _fadeTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Read QSOs from the filtered logbook stream so enrichment filters (radio,
    // antenna, review status, rating) apply here too.
    final qsos = ref.watch(logbookProvider).valueOrNull ?? const [];
    final decodes = ref.watch(liveDecodesProvider);
    final mySettings = ref.watch(settingsProvider);
    final myLatLng = gridToLatLng(mySettings.myGrid);
    final unit = mySettings.distanceUnit;
    final resolver = ref.watch(callsignResolverProvider);
    final pskSpots = ref.watch(pskSpotsProvider).valueOrNull ?? const <PskSpot>[];
    final pskLoading = ref.watch(pskSpotsProvider).isLoading;
    final workedCalls = ref.watch(workedCallsignsProvider).valueOrNull ?? const <String>{};
    final qsoColor    = mySettings.qsoColor;
    final decodeColor = mySettings.decodeColor;
    final pskColor    = mySettings.pskColor;
    final meColor     = mySettings.meColor;

    final now = DateTime.now();
    final ageMaxDur = _ageFilter == QsoAgeFilter.custom
        ? Duration(hours: _ageCustomHours)
        : _ageFilter.maxAge;
    final ageCutoff = ageMaxDur == null ? null : now.subtract(ageMaxDur);

    final qsoMarkers = <Marker>[];
    if (_showQsos) {
      for (final q in qsos) {
        if (ageCutoff != null && q.timeOn.isBefore(ageCutoff)) continue;
        final ll = gridToLatLng(q.gridsquare);
        if (ll == null) continue;
        final distKm = myLatLng == null
            ? null
            : const Distance().as(LengthUnit.Kilometer, myLatLng, ll);
        qsoMarkers.add(Marker(
          point: ll,
          width: 22, height: 22,
          child: _QsoMarker(qso: q, distanceKm: distKm, unit: unit, color: qsoColor),
        ));
      }
    }

    final decodeMarkers = <Marker>[];
    final decodeLines = <Polyline>[];
    if (_showDecodes) {
      for (final d in decodes) {
        final call = d.decode.cqCall();
        if (call == null) continue;
        if (d.decode.snr < _minSnr) continue;
        final hintedGrid = d.decode.cqGrid();
        final resolvedGrid = resolver.gridFor(call, seenGridHint: hintedGrid);
        if (resolvedGrid == null) continue;
        final ll = gridToLatLng(resolvedGrid);
        if (ll == null) continue;
        final age = now.difference(d.receivedAt).inSeconds;
        if (age > 90) continue;
        final alpha = (1 - age / 90).clamp(0.0, 1.0);
        final distKm = myLatLng == null
            ? null
            : const Distance().as(LengthUnit.Kilometer, myLatLng, ll);
        final isNewCq = d.decode.message.trim().startsWith('CQ ') &&
            !workedCalls.contains(call.toUpperCase());
        decodeMarkers.add(Marker(
          point: ll,
          // Slightly larger marker + badge overhead when NEW CQ.
          width: isNewCq ? 60 : 22, height: isNewCq ? 32 : 22,
          child: _DecodeMarker(
            call: call,
            grid: resolvedGrid,
            snr: d.decode.snr,
            mode: d.decode.mode,
            alpha: alpha,
            distanceKm: distKm,
            unit: unit,
            gridWasHinted: hintedGrid != null,
            color: decodeColor,
            isNewCq: isNewCq,
          ),
        ));
        if (_showLines && myLatLng != null) {
          decodeLines.add(Polyline(
            points: [myLatLng, ll],
            color: decodeColor.withOpacity(0.25 * alpha),
            strokeWidth: 1.2,
          ));
        }
      }
    }

    // PSK Reporter spots — diamond markers using the user's chosen color.
    final pskMarkers = <Marker>[];
    final pskLines = <Polyline>[];
    if (_showPskSpots && mySettings.pskSpotDirection != PskSpotDirection.off) {
      for (final s in pskSpots) {
        final ll = gridToLatLng(s.otherGrid);
        if (ll == null) continue;
        final distKm = myLatLng == null ? null : const Distance().as(LengthUnit.Kilometer, myLatLng, ll);
        pskMarkers.add(Marker(
          point: ll,
          width: 20, height: 20,
          child: _PskSpotMarker(spot: s, color: pskColor, distanceKm: distKm, unit: unit),
        ));
        if (_showLines && myLatLng != null) {
          pskLines.add(Polyline(
            points: [myLatLng, ll],
            color: pskColor.withOpacity(0.18),
            strokeWidth: 1,
          ));
        }
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: const MapOptions(
            initialCenter: LatLng(30, 10),
            initialZoom: 2.4,
            minZoom: 1.5,
            maxZoom: 12,
          ),
          children: [
            _buildTileLayer(mySettings.mapStyle),
            if (mySettings.mapStyle == MapStyle.cbscopeRetro) _RetroMapOverlay(),
            if (decodeLines.isNotEmpty || pskLines.isNotEmpty)
              PolylineLayer(polylines: [...decodeLines, ...pskLines]),
            MarkerLayer(markers: [...qsoMarkers, ...pskMarkers, ...decodeMarkers]),
            if (_showMe && myLatLng != null)
              MarkerLayer(markers: [
                Marker(
                  point: myLatLng,
                  width: 24, height: 24,
                  child: Tooltip(
                    message: 'You  ·  ${mySettings.myCall ?? ''}  ·  ${mySettings.myGrid}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: meColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: meColor.withOpacity(0.4), blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ]),
          ],
        ),

        // Top toolbar: quick counts + filter open + zoom
        Positioned(
          top: 16, left: 16, right: 16,
          child: Row(
            children: [
              _pill(
                icon: Icons.radio_button_checked,
                color: qsoColor,
                label: '${qsoMarkers.length} QSOs',
                active: _showQsos,
                onTap: () => setState(() => _showQsos = !_showQsos),
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.wifi_tethering,
                color: decodeColor,
                label: '${decodeMarkers.length} live',
                active: _showDecodes,
                onTap: () => setState(() => _showDecodes = !_showDecodes),
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.satellite_alt,
                color: pskColor,
                label: pskLoading && pskMarkers.isEmpty
                    ? 'PSK…'
                    : '${pskMarkers.length} PSK',
                active: _showPskSpots && mySettings.pskSpotDirection != PskSpotDirection.off,
                onTap: () => setState(() => _showPskSpots = !_showPskSpots),
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.tune,
                color: c.text,
                label: 'Filters',
                active: _filtersOpen,
                onTap: () => setState(() => _filtersOpen = !_filtersOpen),
              ),
              const Spacer(),
              _iconButton(Icons.zoom_out, () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
              const SizedBox(width: 6),
              _iconButton(Icons.zoom_in, () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
            ],
          ),
        ),

        // Bottom-left: compact propagation strip
        Positioned(
          left: 16, bottom: 16, width: 360,
          child: const PropagationCard(compact: true),
        ),

        // Right-side sliding filter panel
        Positioned(
          top: 64, right: _filtersOpen ? 16 : -320, bottom: 16, width: 300,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _FilterPanel(
              showQsos: _showQsos,
              showDecodes: _showDecodes,
              showLines: _showLines,
              showMe: _showMe,
              showPskSpots: _showPskSpots,
              ageFilter: _ageFilter,
              ageCustomHours: _ageCustomHours,
              minSnr: _minSnr,
              onChanged: (next) => setState(() {
                _showQsos       = next.showQsos;
                _showDecodes    = next.showDecodes;
                _showLines      = next.showLines;
                _showMe         = next.showMe;
                _showPskSpots   = next.showPskSpots;
                _ageFilter      = next.ageFilter;
                _ageCustomHours = next.ageCustomHours;
                _minSnr         = next.minSnr;
              }),
              onClose: () => setState(() => _filtersOpen = false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTileLayer(MapStyle style) {
    // CBScope Retro = Carto Dark Matter (dark gray tiles) tinted green via a
    // per-tile color filter that keeps roads/labels legible while giving the
    // whole map the retro terminal glow. Regular = OpenStreetMap standard.
    if (style == MapStyle.cbscopeRetro) {
      return TileLayer(
        urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'app.cbscope',
        tileProvider: NetworkTileProvider(),
        tileBuilder: (context, tileWidget, tile) {
          // Blend the dark tile with a green so the base map takes on the
          // signature #49FF7A hue while retaining structure.
          return ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              // R' — kept very low so nothing looks red-ish.
              0.02, 0.35, 0.02, 0,  2,
              // G' — punchy: bright pixels amplify to near-mint, offset adds
              // an overall glow so land/water separation is legible.
              0.20, 1.55, 0.20, 0, 18,
              // B' — small residue for a hint of teal; kills warm cast.
              0.06, 0.40, 0.06, 0,  4,
              0,    0,    0,    1,  0,
            ]),
            child: tileWidget,
          );
        },
      );
    }
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'net.xzgroup.cbscope',
      tileProvider: NetworkTileProvider(),
    );
  }

  Widget _pill({
    required IconData icon,
    required Color color,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: c.card.withOpacity(0.92),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: active ? color : c.subtle,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: active ? c.text : c.subtle),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: active ? c.text : c.subtle,
                    )),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: c.card.withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Icon(icon, size: 16, color: c.text),
      ),
    );
  }
}

class _FilterState {
  final bool showQsos, showDecodes, showLines, showMe, showPskSpots;
  final QsoAgeFilter ageFilter;
  final int ageCustomHours;
  final double minSnr;
  const _FilterState({
    required this.showQsos, required this.showDecodes, required this.showLines,
    required this.showMe, required this.showPskSpots,
    required this.ageFilter, required this.ageCustomHours, required this.minSnr,
  });
}

class _FilterPanel extends ConsumerWidget {
  final bool showQsos, showDecodes, showLines, showMe, showPskSpots;
  final QsoAgeFilter ageFilter;
  final int ageCustomHours;
  final double minSnr;
  final ValueChanged<_FilterState> onChanged;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.showQsos,
    required this.showDecodes,
    required this.showLines,
    required this.showMe,
    required this.showPskSpots,
    required this.ageFilter,
    required this.ageCustomHours,
    required this.minSnr,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header stays OUTSIDE the scroll view so the close X is always
          // reachable and never obscured by the scrollbar gutter.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(Icons.tune, size: 14, color: c.subtle),
                const SizedBox(width: 6),
                Text('FILTERS', style: t.labelSmall),
                const Spacer(),
                InkWell(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 16, color: c.text),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: c.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _section(context, 'Layers'),
              _switchRow(context, 'Logged QSOs',        showQsos,     (v) => _emit(showQsos: v)),
              _switchRow(context, 'Live decodes',       showDecodes,  (v) => _emit(showDecodes: v)),
              _switchRow(context, 'PSK Reporter spots', showPskSpots, (v) => _emit(showPskSpots: v)),
              _switchRow(context, 'Great-circle lines', showLines,    (v) => _emit(showLines: v)),
              _switchRow(context, 'My location',        showMe,       (v) => _emit(showMe: v)),
              const SizedBox(height: 16),
              _section(context, 'PSK Reporter (my callsign)'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  for (final d in PskSpotDirection.values)
                    _chipToggle(context, _pskDirLabel(d), settings.pskSpotDirection == d, () {
                      ref.read(settingsProvider.notifier).update(settings.copyWith(pskSpotDirection: d));
                    }),
                ],
              ),
              const SizedBox(height: 8),
              _section(context, 'PSK — timespan'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  for (final w in PskSpotWindow.values)
                    _chipToggle(context, w.label, settings.pskSpotWindow == w, () {
                      ref.read(settingsProvider.notifier).update(settings.copyWith(pskSpotWindow: w));
                    }),
                ],
              ),
              if (settings.pskSpotWindow == PskSpotWindow.custom) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.pskSpotCustomMinutes.toDouble().clamp(1, 60),
                        min: 1, max: 60, divisions: 59,
                        label: '${settings.pskSpotCustomMinutes} min',
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).update(
                                settings.copyWith(pskSpotCustomMinutes: v.round()),
                              );
                        },
                      ),
                    ),
                    SizedBox(width: 52,
                      child: Text('${settings.pskSpotCustomMinutes} min',
                          style: t.bodySmall, textAlign: TextAlign.right)),
                  ],
                ),
              ],
              if (settings.myCall == null || settings.myCall!.isEmpty) ...[
                const SizedBox(height: 6),
                Text('Set your callsign in Settings to enable PSK Reporter spots.',
                    style: t.bodySmall?.copyWith(color: c.warning)),
              ],
              const SizedBox(height: 16),
              _section(context, 'QSOs — age'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  for (final f in QsoAgeFilter.values)
                    _chipToggle(context, f.label, ageFilter == f, () => _emit(ageFilter: f)),
                ],
              ),
              if (ageFilter == QsoAgeFilter.custom) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: ageCustomHours.toDouble().clamp(1, 720),
                        min: 1, max: 720, divisions: 719,
                        label: _humanHours(ageCustomHours),
                        onChanged: (v) => _emit(ageCustomHours: v.round()),
                      ),
                    ),
                    SizedBox(width: 72,
                      child: Text(_humanHours(ageCustomHours),
                          style: t.bodySmall, textAlign: TextAlign.right)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _EnrichmentFilters(),
              const SizedBox(height: 16),
              _section(context, 'Live decodes — min SNR'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: minSnr,
                      min: -30, max: 10, divisions: 40,
                      label: '${minSnr.round()} dB',
                      onChanged: (v) => _emit(minSnr: v),
                    ),
                  ),
                  SizedBox(width: 46, child: Text('${minSnr.round()} dB',
                    style: t.bodySmall, textAlign: TextAlign.right)),
                ],
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _humanHours(int h) {
    if (h < 24) return '$h h';
    final d = h ~/ 24;
    final rest = h % 24;
    return rest == 0 ? '$d d' : '${d}d ${rest}h';
  }

  void _emit({
    bool? showQsos, bool? showDecodes, bool? showLines, bool? showMe, bool? showPskSpots,
    QsoAgeFilter? ageFilter, int? ageCustomHours, double? minSnr,
  }) {
    onChanged(_FilterState(
      showQsos:       showQsos       ?? this.showQsos,
      showDecodes:    showDecodes    ?? this.showDecodes,
      showLines:      showLines      ?? this.showLines,
      showMe:         showMe         ?? this.showMe,
      showPskSpots:   showPskSpots   ?? this.showPskSpots,
      ageFilter:      ageFilter      ?? this.ageFilter,
      ageCustomHours: ageCustomHours ?? this.ageCustomHours,
      minSnr:         minSnr         ?? this.minSnr,
    ));
  }

  String _pskDirLabel(PskSpotDirection d) => switch (d) {
        PskSpotDirection.off      => 'Off',
        PskSpotDirection.sent     => 'Heard me',
        PskSpotDirection.received => 'I heard',
        PskSpotDirection.both     => 'Both',
      };

  Widget _section(BuildContext context, String label) => Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );

  Widget _switchRow(BuildContext context, String label, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _chipToggle(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent.withOpacity(0.14) : c.surface,
          border: Border.all(color: selected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
          style: t.bodySmall?.copyWith(
            color: selected ? c.accent : c.text,
            fontWeight: selected ? FontWeight.w600 : null,
          )),
      ),
    );
  }
}

/// Hoverable QSO marker with a rich tooltip.
class _QsoMarker extends StatelessWidget {
  final Qso qso;
  final double? distanceKm;
  final DistanceUnit unit;
  final Color color;
  const _QsoMarker({required this.qso, this.distanceKm, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _QsoTooltipCard(qso: qso, distanceKm: distanceKm, unit: unit),
      ),
      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(6),
      preferBelow: false,
      triggerMode: TooltipTriggerMode.tap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Center(
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.88),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class _QsoTooltipCard extends StatelessWidget {
  final Qso qso;
  final double? distanceKm;
  final DistanceUnit unit;
  const _QsoTooltipCard({required this.qso, this.distanceKm, required this.unit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final df = DateFormat('yyyy-MM-dd HH:mm \'UTC\'');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(qso.call, style: t.headlineSmall),
                  const Spacer(),
                  _chip(context, qso.mode.toUpperCase()),
                  if (qso.freqMhz != null) ...[
                    const SizedBox(width: 4),
                    _chip(context, '${qso.freqMhz!.toStringAsFixed(3)} MHz'),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(df.format(qso.timeOn.toUtc()),
                  style: t.bodySmall?.copyWith(fontFamily: 'Menlo')),
              const SizedBox(height: 8),
              _kv(context, 'Grid', qso.gridsquare ?? '—'),
              _kv(context, 'RST S/R', '${qso.rstSent ?? '-'} / ${qso.rstRcvd ?? '-'}'),
              if (qso.name != null && qso.name!.isNotEmpty)  _kv(context, 'Name', qso.name!),
              if (qso.country != null && qso.country!.isNotEmpty) _kv(context, 'Country', qso.country!),
              if (qso.comment != null && qso.comment!.isNotEmpty) _kv(context, 'Comment', qso.comment!),
              if (qso.myGrid != null && qso.myGrid!.isNotEmpty) _kv(context, 'My QTH', qso.myGrid!),
              _WeatherRow(rawFields: qso.rawFields),
              if (distanceKm != null) ...[
                const Divider(height: 12),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 12, color: c.subtle),
                    const SizedBox(width: 6),
                    Text('${unit.from(distanceKm!).toStringAsFixed(0)} ${unit.label}',
                        style: t.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 68, child: Text(k, style: t.labelSmall?.copyWith(color: c.subtle))),
          Expanded(child: Text(v, style: t.bodySmall)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String s) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
      ),
      child: Text(s, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// Reads solar/propagation fields out of a QSO's `raw_fields` JSON and
/// renders a compact chip line inside the tooltip. Nothing shown if the
/// record wasn't stamped with weather at ingest.
class _WeatherRow extends StatelessWidget {
  final String? rawFields;
  const _WeatherRow({required this.rawFields});
  @override
  Widget build(BuildContext context) {
    if (rawFields == null || rawFields!.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic>? m;
    try { m = jsonDecode(rawFields!) as Map<String, dynamic>; } catch (_) { return const SizedBox.shrink(); }
    final sfi  = m['app_qsobook_sfi'];
    final k    = m['app_qsobook_k_index'];
    final a    = m['app_qsobook_a_index'];
    final ss   = m['app_qsobook_sunspots'];
    final cond = m['app_qsobook_band_condition'];
    if (sfi == null && k == null && a == null && ss == null && cond == null) {
      return const SizedBox.shrink();
    }
    final parts = <String>[
      if (sfi != null) 'SFI $sfi',
      if (k   != null) 'K $k',
      if (a   != null) 'A $a',
      if (ss  != null) 'SS $ss',
      if (cond != null) 'Band: $cond',
    ];
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 12, color: c.subtle),
          const SizedBox(width: 6),
          Expanded(child: Text(parts.join('  ·  '),
            style: t.labelSmall?.copyWith(color: c.subtle, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Enrichment filters (antenna / radio / review status / rating) rendered
/// as a section inside the map filter panel. Mutates the shared
/// [logbookFilterProvider] so the Logbook screen shows the same slice.
class _EnrichmentFilters extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final f = ref.watch(logbookFilterProvider);
    final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
    final rigs     = ref.watch(rigsProvider).valueOrNull ?? const [];
    void update({
      int? antennaId, int? radioId,
      bool clearAntenna = false, bool clearRadio = false,
    }) {
      ref.read(logbookFilterProvider.notifier).state = (
        search: f.search,
        band: f.band,
        mode: f.mode,
        antennaId: clearAntenna ? null : (antennaId ?? f.antennaId),
        radioId:   clearRadio   ? null : (radioId   ?? f.radioId),
        minRating: f.minRating,
        reviewState: f.reviewState,
      );
    }

    Widget chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? c.accent.withOpacity(0.14) : c.surface,
              border: Border.all(color: selected ? c.accent : c.border),
            ),
            child: Text(label, style: t.bodySmall?.copyWith(
              color: selected ? c.accent : c.text,
              fontWeight: selected ? FontWeight.w700 : null,
            )),
          ),
        );

    // Review status + rating filters intentionally live only on the Logbook
    // screen — the map should stay a lightweight geo view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rigs.isNotEmpty) ...[
          Text('QSOs — RADIO', style: t.labelSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            chip('Any', f.radioId == null, () => update(clearRadio: true)),
            for (final r in rigs)
              chip(r.name, f.radioId == r.id, () => update(radioId: r.id)),
          ]),
        ],
        if (antennas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('QSOs — ANTENNA', style: t.labelSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            chip('Any', f.antennaId == null, () => update(clearAntenna: true)),
            for (final a in antennas)
              chip(a.name, f.antennaId == a.id, () => update(antennaId: a.id)),
          ]),
        ],
      ],
    );
  }
}

/// Scanline overlay drawn above tiles for the CBScope Retro map style.
/// Draws thin horizontal lines every 3 px + a subtle green vignette.
class _RetroMapOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RetroOverlayPainter(color: const Color(0xFF49FF7A)),
        size: Size.infinite,
      ),
    );
  }
}

class _RetroOverlayPainter extends CustomPainter {
  final Color color;
  _RetroOverlayPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle scanlines only — no vignette. Keeps the retro feel without
    // hurting map readability.
    final scan = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
  }
  @override
  bool shouldRepaint(covariant _RetroOverlayPainter old) => old.color != color;
}

/// PSK Reporter spot marker: rotated square (diamond) with a magenta tint
/// and a "PSK" chip in the tooltip so it's visually distinct from our own
/// QSOs and live decodes.
class _PskSpotMarker extends StatelessWidget {
  final PskSpot spot;
  final Color color;
  final double? distanceKm;
  final DistanceUnit unit;
  const _PskSpotMarker({required this.spot, required this.color, this.distanceKm, required this.unit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final freqMhz = spot.freqHz / 1e6;
    final tip = StringBuffer()
      ..write('[PSK REPORTER]\n')
      ..write(spot.direction == PskDirection.sent ? 'HEARD ME:  ' : 'I HEARD:  ')
      ..write(spot.otherCall)
      ..write('  ·  ')
      ..write(spot.otherGrid)
      ..write('\n')
      ..write('${freqMhz.toStringAsFixed(3)} MHz  ·  ')
      ..write(spot.snr >= 0 ? '+${spot.snr}' : '${spot.snr}')
      ..write(' dB  ·  ')
      ..write(spot.mode);
    if (distanceKm != null) {
      tip
        ..write('\n')
        ..write('${unit.from(distanceKm!).toStringAsFixed(0)} ${unit.label}');
    }
    return Tooltip(
      message: tip.toString(),
      waitDuration: const Duration(milliseconds: 200),
      textStyle: t.bodySmall?.copyWith(color: c.text, fontFamily: 'Menlo'),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: color),
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.785398, // 45°
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecodeMarker extends StatelessWidget {
  final String call;
  final String grid;
  final int snr;
  final String mode;
  final double alpha;
  final double? distanceKm;
  final DistanceUnit unit;
  final bool gridWasHinted;
  final Color color;
  final bool isNewCq;
  const _DecodeMarker({
    required this.call,
    required this.grid,
    required this.snr,
    required this.mode,
    required this.alpha,
    this.distanceKm,
    required this.unit,
    required this.gridWasHinted,
    required this.color,
    required this.isNewCq,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tooltip = StringBuffer()
      ..write(isNewCq ? '[NEW CQ] ' : '')
      ..write(call)
      ..write('  ·  ')
      ..write(grid)
      ..write(gridWasHinted ? '' : '  (looked up)')
      ..write('  ·  ')
      ..write(snr >= 0 ? '+$snr' : '$snr')
      ..write(' dB  ·  ')
      ..write(mode);
    if (distanceKm != null) {
      tooltip
        ..write('\n')
        ..write('${unit.from(distanceKm!).toStringAsFixed(0)} ${unit.label}');
    }
    final dot = Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: color.withOpacity(alpha),
        shape: BoxShape.circle,
        border: gridWasHinted
            ? null
            : Border.all(color: Colors.white.withOpacity(0.9 * alpha), width: 1.4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.6 * alpha), blurRadius: 8, spreadRadius: 2)],
      ),
    );
    return Tooltip(
      message: tooltip.toString(),
      waitDuration: const Duration(milliseconds: 250),
      child: isNewCq
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: c.success.withOpacity(0.90 * alpha),
                  border: Border.all(color: Colors.white.withOpacity(0.9 * alpha), width: 0.8),
                ),
                child: Text('NEW CQ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        )),
              ),
              const SizedBox(height: 3),
              dot,
            ])
          : Center(child: dot),
    );
  }
}
