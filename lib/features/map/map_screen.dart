import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/greyline.dart';
import '../../core/util/maidenhead.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/propagation_card.dart';
import '../../data/db/database.dart';
import '../../data/psk_reporter/psk_reporter_client.dart';
import '../../providers/providers.dart';
import '../station/station_profile_sheet.dart';
import 'heatmap_overlay.dart';

enum QsoAgeFilter { custom, last24h, week, month, year, all }

extension QsoAgeFilterX on QsoAgeFilter {
  String get label => switch (this) {
        QsoAgeFilter.custom => 'Custom',
        QsoAgeFilter.last24h => 'Last 24 h',
        QsoAgeFilter.week => 'Last week',
        QsoAgeFilter.month => 'Last month',
        QsoAgeFilter.year => 'Last year',
        QsoAgeFilter.all => 'All time',
      };
  Duration? get maxAge => switch (this) {
        QsoAgeFilter.custom => const Duration(
            hours: 24,
          ), // fallback, real value comes from slider
        QsoAgeFilter.last24h => const Duration(hours: 24),
        QsoAgeFilter.week => const Duration(days: 7),
        QsoAgeFilter.month => const Duration(days: 30),
        QsoAgeFilter.year => const Duration(days: 365),
        QsoAgeFilter.all => null,
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
  bool _showGreyline = false;
  bool _showRunningQso = true;
  bool _filtersOpen = false;
  int? _pinnedRadioId;
  int? _pinnedAntennaId;
  int? _hoverRadioId;
  int? _hoverAntennaId;
  HeatmapSignalDirection _heatmapDirection = HeatmapSignalDirection.send;
  QsoAgeFilter _ageFilter = QsoAgeFilter.all;
  int _ageCustomMinutes = 15; // used when _ageFilter == custom (1-60 min)
  double _minSnr = -30; // dB

  // Time-replay: when active, all layers are filtered to "before or at _replayAt".
  bool _replayEnabled = false;
  DateTime _replayAt = DateTime.now().toUtc();
  int _replaySpanHours = 24;
  Timer? _replayAutoplay;
  Timer? _fadeTick;

  /// Fit-to-QSOs runs once per screen mount. We wait for the first non-
  /// empty logbook emission (so the map isn't zoomed to an empty set) and
  /// fire exactly once — moving the camera on every rebuild would fight
  /// the user's pinch/pan.
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    _showGreyline = ref.read(settingsProvider).mapGreylineEnabled;
    // 200 ms tick: drives both the live-decode fade AND the flowing PSK dots.
    _fadeTick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
  }

  /// Compute a bounding box that covers every logged QSO with a resolvable
  /// grid (plus the operator's own QTH if set), pad it slightly, and
  /// animate the camera to fit. No-op if there are no QSOs — the default
  /// world view stays.
  void _fitToQsos(List<Qso> qsos, LatLng? myLatLng) {
    if (_initialFitDone) return;
    final points = <LatLng>[];
    if (myLatLng != null) points.add(myLatLng);
    for (final q in qsos) {
      final ll = gridToLatLng(q.gridsquare);
      if (ll != null) points.add(ll);
    }
    if (points.length < 2) return;
    _initialFitDone = true;
    // Schedule the camera move for after this build completes — flutter_map
    // rejects camera changes made mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
          maxZoom: 8,
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeTick?.cancel();
    _replayAutoplay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Normal map QSOs keep using the regular logbook filters. Equipment
    // comparison is map-local and uses the complete QSO set below.
    final qsos = ref.watch(logbookProvider).valueOrNull ?? const [];
    final allQsos = ref.watch(allQsosProvider).valueOrNull ?? const <Qso>[];
    final decodes = ref.watch(liveDecodesProvider);
    final wsjtxStatus = ref.watch(wsjtxStatusProvider);
    final mySettings = ref.watch(settingsProvider);
    final myLatLng = gridToLatLng(mySettings.myGrid);
    final unit = mySettings.distanceUnit;
    final resolver = ref.watch(callsignResolverProvider);
    final pskSpots =
        ref.watch(pskSpotsProvider).valueOrNull ?? const <PskSpot>[];
    final pskLoading = ref.watch(pskSpotsProvider).isLoading;
    final workedCalls =
        ref.watch(workedCallsignsProvider).valueOrNull ?? const <String>{};
    final qsoColor = mySettings.qsoColor;
    final decodeColor = mySettings.decodeColor;
    final pskColor = mySettings.pskColor;
    final meColor = mySettings.meColor;
    final previewRadioId = _hoverRadioId ?? _pinnedRadioId;
    final previewAntennaId = _hoverAntennaId ?? _pinnedAntennaId;
    final heatmapQsos = allQsos.where((qso) {
      if (previewRadioId != null && qso.radioId != previewRadioId) return false;
      if (previewAntennaId != null && qso.antennaId != previewAntennaId) {
        return false;
      }
      return true;
    }).toList(growable: false);

    // Auto-fit the camera to include every logged QSO the first time the
    // logbook data is available. Once done, hands the map back to the user.
    _fitToQsos(allQsos, myLatLng);

    final now = DateTime.now();
    // Replay "now" is either the wallclock or the timeline scrubber value.
    final effectiveNow = _replayEnabled ? _replayAt : now;
    final ageMaxDur = _ageFilter == QsoAgeFilter.custom
        ? Duration(minutes: _ageCustomMinutes)
        : _ageFilter.maxAge;
    final ageCutoff =
        ageMaxDur == null ? null : effectiveNow.subtract(ageMaxDur);

    final qsoMarkers = <Marker>[];
    if (_showQsos) {
      for (final q in qsos) {
        // Age window (min <= timeOn <= max).
        if (ageCutoff != null && q.timeOn.isBefore(ageCutoff)) continue;
        if (_replayEnabled && q.timeOn.isAfter(effectiveNow)) continue;
        final ll = gridToLatLng(q.gridsquare);
        if (ll == null) continue;
        final distKm = myLatLng == null
            ? null
            : const Distance().as(LengthUnit.Kilometer, myLatLng, ll);
        qsoMarkers.add(
          Marker(
            point: ll,
            width: 22,
            height: 22,
            child: _QsoMarker(
              qso: q,
              distanceKm: distKm,
              unit: unit,
              color: qsoColor,
            ),
          ),
        );
      }
    }

    final decodeMarkers = <Marker>[];
    final decodeLines = <Polyline>[];
    if (_showDecodes) {
      for (final d in decodes) {
        final call = d.decode.stationCall();
        if (call == null) continue;
        if (d.decode.snr < _minSnr) continue;
        // Replay hides decodes newer than the scrubber.
        if (_replayEnabled && d.receivedAt.toUtc().isAfter(effectiveNow))
          continue;
        final hintedGrid = d.decode.gridHint();
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
        decodeMarkers.add(
          Marker(
            point: ll,
            // Slightly larger marker + badge overhead when NEW CQ (badge
            // now includes the callsign, so we need more horizontal room).
            width: isNewCq ? 130 : 22,
            height: isNewCq ? 32 : 22,
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
          ),
        );
        if (_showLines && myLatLng != null) {
          decodeLines.add(
            Polyline(
              points: [myLatLng, ll],
              color: decodeColor.withOpacity(0.25 * alpha),
              strokeWidth: 1.2,
            ),
          );
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
        final distKm = myLatLng == null
            ? null
            : const Distance().as(LengthUnit.Kilometer, myLatLng, ll);
        pskMarkers.add(
          Marker(
            point: ll,
            width: 20,
            height: 20,
            child: _PskSpotMarker(
              spot: s,
              color: pskColor,
              distanceKm: distKm,
              unit: unit,
            ),
          ),
        );
        if (_showLines && myLatLng != null) {
          pskLines.add(
            Polyline(
              points: [myLatLng, ll],
              color: pskColor.withOpacity(0.18),
              strokeWidth: 1,
            ),
          );
        }
      }
    }

    // Running-QSO layer: WSJT-CB leaves `dxCall` populated in Status long
    // after a QSO ends (sticky DX Call text field), so we can't use that
    // alone. Instead we walk two independent evidence trails:
    //
    //  ENGAGED   → we've received a decode from `dxCall` addressed to *us*
    //              (they replied — the QSO is live). Rendered bright/bold.
    //  CALLING   → we've transmitted (offAir decode) addressed to `dxCall`,
    //              but haven't heard back yet. Rendered softer so the user
    //              still sees the outbound attempt from the moment they hit
    //              Enable Tx.
    //
    // Both cases are hidden once a QSO with that call has been logged in
    // the last 5 minutes (Log button or auto-log after RR73).
    LatLng? runningLatLng;
    String? runningCall;
    String? runningGrid;
    bool runningTx = false;
    bool hasRunning = false;
    bool isEngaged = false; // false → "calling", true → full "working"
    if (!_replayEnabled &&
        wsjtxStatus != null &&
        wsjtxStatus.dxCall != null &&
        wsjtxStatus.dxCall!.trim().isNotEmpty) {
      final call = wsjtxStatus.dxCall!.trim().toUpperCase();
      final decodeCutoff = now.subtract(const Duration(seconds: 120));
      final myCall = mySettings.myCall?.trim().toUpperCase();
      // WSJT-CB wraps hash-compressed callsigns in `<...>` (e.g.
      // `<19XX999> 14XX000`); strip them so token comparisons match the
      // plain-string dxCall / myCall values.
      String firstToken(String msg) {
        final tokens = msg.trim().split(RegExp(r'\s+'));
        if (tokens.isEmpty) return '';
        return tokens.first.replaceAll(RegExp(r'^<|>$'), '').toUpperCase();
      }

      // Engaged: DX sent a message addressed to *us*. CB decodes often
      // arrive abbreviated as `MYCALL -08` / `MYCALL RR73` — the sender
      // isn't in the string, so we trust `wsjtxStatus.dxCall` (which is
      // authoritative for who we're working) rather than parsing it out.
      final engagedByReply = myCall != null && myCall.isNotEmpty &&
          decodes.any((d) {
            if (!d.receivedAt.isAfter(decodeCutoff)) return false;
            final msg = d.decode.message.trim().toUpperCase();
            if (msg.isEmpty || msg.startsWith('CQ ')) return false;
            return firstToken(msg) == myCall;
          });
      // Calling: our own transmission is directed at `dxCall`. Primary
      // signal is the schema-3 `txMessage` from Status; fallback to offAir
      // Decode echoes if Status didn't carry it. Gated on transmitting=true
      // because Status keeps the queued txMessage populated long after a
      // QSO ends — without the gate, a past QSO's target keeps showing.
      bool callingTarget = false;
      if (wsjtxStatus.transmitting) {
        final txMsg = wsjtxStatus.txMessage?.trim().toUpperCase();
        if (txMsg != null && txMsg.isNotEmpty) {
          callingTarget = firstToken(txMsg) == call;
        } else {
          final selfCutoff = now.subtract(const Duration(seconds: 60));
          callingTarget = decodes.any((d) {
            if (!d.receivedAt.isAfter(selfCutoff)) return false;
            if (!d.decode.offAir) return false;
            return firstToken(d.decode.message) == call;
          });
        }
      }
      final logCutoff = now.toUtc().subtract(const Duration(minutes: 5));
      // Use the *unfiltered* QSO stream — the user's Logbook filter (e.g.
      // rating ≥ 3, specific antenna) would otherwise hide a freshly-
      // logged row and leave the overlay lingering.
      final alreadyLogged = allQsos.any((q) =>
          q.call.toUpperCase() == call && q.timeOn.isAfter(logCutoff));
      // Also treat an observed 73 / RR73 exchange as "QSO complete" so the
      // overlay drops the moment WSJT-CB sees the final message, even
      // before the operator hits the Log button. Windowed at 60 s.
      final completionCutoff = now.subtract(const Duration(seconds: 60));
      final justCompleted = decodes.any((d) {
        if (!d.receivedAt.isAfter(completionCutoff)) return false;
        final msg = d.decode.message.trim().toUpperCase();
        final tokens = msg.split(RegExp(r'\s+'));
        if (tokens.length < 3) return false;
        final last = tokens.last;
        if (last != '73' && last != 'RR73') return false;
        // Match either direction: DX told us 73 (first token = my call,
        // sender = dxCall via Status), or we told DX 73 via offAir echo
        // (first token = dxCall, message we just transmitted).
        final first = firstToken(msg);
        if (myCall != null && first == myCall) return true;
        if (d.decode.offAir && first == call) return true;
        return false;
      });
      if ((engagedByReply || callingTarget) &&
          !alreadyLogged &&
          !justCompleted) {
        hasRunning = true;
        isEngaged = engagedByReply;
        runningCall = call;
        runningTx = wsjtxStatus.transmitting;
        final rawGrid = (wsjtxStatus.dxGrid != null &&
                wsjtxStatus.dxGrid!.trim().length >= 4)
            ? wsjtxStatus.dxGrid!.trim().toUpperCase()
            : resolver.gridFor(call);
        if (rawGrid != null) {
          runningGrid = rawGrid;
          runningLatLng = gridToLatLng(rawGrid);
        }
      }
    }
    final showRunningLayer = _showRunningQso && hasRunning;
    // Bright red so the running-QSO line/marker is unmistakable — a tick
    // brighter than the app's danger-red so it still reads at small size.
    const runningColor = Color(0xFFFF3050);

    // "Calling CQ" detection for the QTH marker.
    // Primary signal: WSJT-X schema-3 Status carries the exact TX message
    // string — we can just look at whether it starts with "CQ ".
    // Fallback (older schemas / truncated packets): scan recent Decode
    // messages with offAir=true. If neither exists but `transmitting=true`
    // and `dxCall` is empty (WSJT-X clears the DX Call field when the CQ
    // button is used), it's very likely a CQ.
    bool callingCq = false;
    if (!_replayEnabled && wsjtxStatus != null && wsjtxStatus.transmitting) {
      final txMsg = wsjtxStatus.txMessage?.trim().toUpperCase();
      if (txMsg != null && txMsg.isNotEmpty) {
        callingCq = txMsg.startsWith('CQ ');
      } else {
        bool foundSelfDecode = false;
        final selfCutoff = now.subtract(const Duration(seconds: 45));
        for (final d in decodes) {
          if (d.receivedAt.isBefore(selfCutoff)) break; // newest-first
          if (!d.decode.offAir) continue;
          foundSelfDecode = true;
          callingCq =
              d.decode.message.trim().toUpperCase().startsWith('CQ ');
          break;
        }
        if (!foundSelfDecode) {
          final dx = wsjtxStatus.dxCall?.trim() ?? '';
          callingCq = dx.isEmpty;
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
            if (mySettings.mapStyle == MapStyle.cbscopeRetro)
              _RetroMapOverlay(),
            if (_showGreyline) _GreylineLayer(),
            if (decodeLines.isNotEmpty || pskLines.isNotEmpty)
              PolylineLayer(polylines: [...decodeLines, ...pskLines]),
            if (showRunningLayer && runningLatLng != null && myLatLng != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [myLatLng, runningLatLng],
                    color: runningColor.withOpacity(isEngaged ? 0.75 : 0.35),
                    strokeWidth: isEngaged ? 2.2 : 1.4,
                  ),
                ],
              ),
            // Animated dots flowing along each PSK great-circle line.
            if (_showPskSpots && myLatLng != null && pskMarkers.isNotEmpty)
              MarkerLayer(
                markers: _flowingPskDots(myLatLng, pskSpots, pskColor),
              ),
            // Running-QSO flowing dots — direction reflects TX/RX so the user
            // can see whether *they* are transmitting or the DX is replying.
            if (showRunningLayer && runningLatLng != null && myLatLng != null)
              MarkerLayer(
                markers: _flowingRunningDots(
                  myLatLng,
                  runningLatLng,
                  runningColor,
                  transmitting: runningTx,
                ),
              ),
            if (previewRadioId != null || previewAntennaId != null)
              HeatmapOverlay(
                qsos: heatmapQsos,
                direction: _heatmapDirection,
              ),
            MarkerLayer(
              markers: [...qsoMarkers, ...pskMarkers, ...decodeMarkers],
            ),
            if (showRunningLayer && runningLatLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: runningLatLng,
                    width: 140,
                    height: 60,
                    child: _RunningQsoMarker(
                      call: runningCall!,
                      grid: runningGrid!,
                      transmitting: runningTx,
                      color: runningColor,
                      engaged: isEngaged,
                    ),
                  ),
                ],
              ),
            if (_showMe && myLatLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: myLatLng,
                    // Wide enough to fit the "CQ" badge + halo when active,
                    // small when idle — flutter_map centres on the point.
                    width: callingCq ? 70 : 24,
                    height: callingCq ? 56 : 24,
                    child: _MeMarker(
                      color: meColor,
                      call: mySettings.myCall,
                      grid: mySettings.myGrid,
                      callingCq: callingCq,
                    ),
                  ),
                ],
              ),
          ],
        ),

        // WSJT connection indicator, upper-left corner, above the toolbar.
        Positioned(top: 16, left: 16, child: _WsjtStatusPill()),
        // Top toolbar: quick counts + filter open + zoom
        Positioned(
          top: 56,
          left: 16,
          right: 16,
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
                active: _showPskSpots &&
                    mySettings.pskSpotDirection != PskSpotDirection.off,
                onTap: () => setState(() => _showPskSpots = !_showPskSpots),
              ),
              if (hasRunning && runningCall != null) ...[
                const SizedBox(width: 8),
                _pill(
                  icon: runningTx ? Icons.podcasts : Icons.headset_mic,
                  color: runningColor,
                  label: isEngaged
                      ? (runningTx
                          ? 'TX → $runningCall'
                          : 'Working $runningCall')
                      : 'Calling $runningCall',
                  active: _showRunningQso,
                  onTap: () =>
                      setState(() => _showRunningQso = !_showRunningQso),
                ),
              ],
              const SizedBox(width: 8),
              _pill(
                icon: Icons.tune,
                color: c.text,
                label: 'Filters',
                active: _filtersOpen,
                onTap: () => setState(() {
                  _filtersOpen = !_filtersOpen;
                  if (!_filtersOpen) {
                    _pinnedRadioId = null;
                    _pinnedAntennaId = null;
                    _hoverRadioId = null;
                    _hoverAntennaId = null;
                  }
                }),
              ),
              const SizedBox(width: 8),
              _pill(
                icon: Icons.history,
                color: c.text,
                label:
                    _replayEnabled ? 'Replay ${_shortHm(_replayAt)}' : 'Replay',
                active: _replayEnabled,
                onTap: () {
                  setState(() {
                    _replayEnabled = !_replayEnabled;
                    if (_replayEnabled) {
                      _replayAt = DateTime.now().toUtc();
                    } else {
                      _replayAutoplay?.cancel();
                    }
                  });
                },
              ),
              const Spacer(),
              _iconButton(
                Icons.zoom_out,
                () => _map.move(_map.camera.center, _map.camera.zoom - 1),
              ),
              const SizedBox(width: 6),
              _iconButton(
                Icons.zoom_in,
                () => _map.move(_map.camera.center, _map.camera.zoom + 1),
              ),
            ],
          ),
        ),

        // Bottom-left: compact propagation strip (hidden while replay bar is up
        // so the two don't collide at the bottom of the map).
        if (!_replayEnabled)
          Positioned(
            left: 16,
            bottom: 16,
            width: 360,
            child: const PropagationCard(compact: true),
          ),

        // Heatmap legend: only visible when a radio/antenna preview is
        // driving the heatmap raster. Right side above the filter panel gap.
        if (previewRadioId != null || previewAntennaId != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: _HeatmapLegend(direction: _heatmapDirection),
          ),

        // Bottom: time-replay scrubber
        if (_replayEnabled)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ReplayBar(
              at: _replayAt,
              spanHours: _replaySpanHours,
              autoplay: _replayAutoplay != null,
              onSeek: (dt) => setState(() => _replayAt = dt),
              onSpanChanged: (h) => setState(() => _replaySpanHours = h),
              onPlayToggle: () {
                setState(() {
                  if (_replayAutoplay != null) {
                    _replayAutoplay!.cancel();
                    _replayAutoplay = null;
                  } else {
                    _replayAutoplay = Timer.periodic(
                      const Duration(milliseconds: 200),
                      (_) {
                        final now = DateTime.now().toUtc();
                        final start = now.subtract(
                          Duration(hours: _replaySpanHours),
                        );
                        // Step 1% of the span per tick; wrap when we hit "now".
                        final stepMs =
                            (Duration(hours: _replaySpanHours).inMilliseconds *
                                    0.01)
                                .round();
                        var next = _replayAt.add(
                          Duration(milliseconds: stepMs),
                        );
                        if (next.isAfter(now)) next = start;
                        setState(() => _replayAt = next);
                      },
                    );
                  }
                });
              },
              onClose: () => setState(() {
                _replayEnabled = false;
                _replayAutoplay?.cancel();
                _replayAutoplay = null;
              }),
            ),
          ),

        // Right-side sliding filter panel
        Positioned(
          top: 64,
          right: _filtersOpen ? 16 : -320,
          bottom: 16,
          width: 300,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _FilterPanel(
              showQsos: _showQsos,
              showDecodes: _showDecodes,
              showLines: _showLines,
              showMe: _showMe,
              showPskSpots: _showPskSpots,
              showGreyline: _showGreyline,
              showRunningQso: _showRunningQso,
              ageFilter: _ageFilter,
              ageCustomMinutes: _ageCustomMinutes,
              minSnr: _minSnr,
              pinnedRadioId: _pinnedRadioId,
              pinnedAntennaId: _pinnedAntennaId,
              hoverRadioId: _hoverRadioId,
              hoverAntennaId: _hoverAntennaId,
              heatmapDirection: _heatmapDirection,
              onHeatmapDirectionChanged: (direction) =>
                  setState(() => _heatmapDirection = direction),
              onEquipmentChanged: (equipment) => setState(() {
                _pinnedRadioId = equipment.pinnedRadioId;
                _pinnedAntennaId = equipment.pinnedAntennaId;
                _hoverRadioId = equipment.hoverRadioId;
                _hoverAntennaId = equipment.hoverAntennaId;
              }),
              onChanged: (next) {
                final greylineChanged = next.showGreyline != _showGreyline;
                setState(() {
                  _showQsos = next.showQsos;
                  _showDecodes = next.showDecodes;
                  _showLines = next.showLines;
                  _showMe = next.showMe;
                  _showPskSpots = next.showPskSpots;
                  _showGreyline = next.showGreyline;
                  _showRunningQso = next.showRunningQso;
                  _ageFilter = next.ageFilter;
                  _ageCustomMinutes = next.ageCustomMinutes;
                  _minSnr = next.minSnr;
                });
                if (greylineChanged) {
                  final settings = ref.read(settingsProvider);
                  unawaited(
                    ref.read(settingsProvider.notifier).update(
                          settings.copyWith(
                            mapGreylineEnabled: next.showGreyline,
                          ),
                        ),
                  );
                }
              },
              onClose: () => setState(() {
                _filtersOpen = false;
                _pinnedRadioId = null;
                _pinnedAntennaId = null;
                _hoverRadioId = null;
                _hoverAntennaId = null;
              }),
            ),
          ),
        ),
      ],
    );
  }

  /// Position three flowing dots per PSK spot along the great-circle path,
  /// direction indicates data flow ("sent" = *my* signal moving TO the
  /// receiver; "received" = the other station's signal moving TO me).
  List<Marker> _flowingPskDots(LatLng me, List<PskSpot> spots, Color color) {
    final markers = <Marker>[];
    // 0.0..1.0 phase that advances ~0.03/second.
    final t = (DateTime.now().millisecondsSinceEpoch % 3000) / 3000.0;
    for (final s in spots) {
      final other = gridToLatLng(s.otherGrid);
      if (other == null) continue;
      final forward = s.direction == PskDirection.sent; // me → other
      for (int i = 0; i < 3; i++) {
        double frac = ((i / 3) + t) % 1.0;
        if (!forward) frac = 1.0 - frac; // reverse direction
        // Interpolate in Web Mercator space so dots track the polyline that
        // flutter_map draws as a straight line between the two projected
        // endpoints. Longitude is linear in Mercator; latitude is not.
        final y0 = math.log(math.tan(math.pi / 4 + me.latitude * math.pi / 360));
        final y1 =
            math.log(math.tan(math.pi / 4 + other.latitude * math.pi / 360));
        final y = y0 + (y1 - y0) * frac;
        final lat = (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;
        final lon = me.longitude + (other.longitude - me.longitude) * frac;
        markers.add(
          Marker(
            point: LatLng(lat, lon),
            width: 6,
            height: 6,
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.6), blurRadius: 4),
                ],
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  /// Animated dots showing the direction of an in-progress QSO — outbound
  /// (me → DX) while transmitting, inbound (DX → me) while receiving. Uses
  /// the same Mercator-space interpolation as `_flowingPskDots` so the dots
  /// track the visual straight line.
  List<Marker> _flowingRunningDots(
    LatLng me,
    LatLng other,
    Color color, {
    required bool transmitting,
  }) {
    final markers = <Marker>[];
    // Faster than PSK dots (0.03/s) so the QSO reads as "live activity".
    final t = (DateTime.now().millisecondsSinceEpoch % 1500) / 1500.0;
    final y0 = math.log(math.tan(math.pi / 4 + me.latitude * math.pi / 360));
    final y1 = math.log(math.tan(math.pi / 4 + other.latitude * math.pi / 360));
    for (int i = 0; i < 4; i++) {
      double frac = ((i / 4) + t) % 1.0;
      if (!transmitting) frac = 1.0 - frac;
      final y = y0 + (y1 - y0) * frac;
      final lat = (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;
      final lon = me.longitude + (other.longitude - me.longitude) * frac;
      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 8,
          height: 8,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.7), blurRadius: 6),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  /// Build the heatmap layers for equipment coverage:
  /// - one soft filled polygon (convex hull) enclosing every point we know
  ///   about with the currently-selected radio/antenna filter, so the
  ///   coverage "shape" reads at a glance and isn't forced to be a circle;
  /// - a CircleLayer of per-QSO blobs coloured by RST received (red = weak,
  ///   yellow = medium, cyan/green = strong), with alpha low enough that
  ///   overlapping stations naturally get brighter — that's the heat.
  List<Widget> _coverageLayers(List<Qso> qsos, LatLng? me) {
    final points = <LatLng>[];
    final circles = <CircleMarker>[];
    for (final q in qsos) {
      final ll = gridToLatLng(q.gridsquare);
      if (ll == null) continue;
      points.add(ll);
      circles.add(
        CircleMarker(
          point: ll,
          // 60 km base radius — bigger than a single grid square so nearby
          // QSOs overlap into a heat gradient, but small enough that the map
          // still shows structure.
          radius: 60000,
          useRadiusInMeter: true,
          color: _rstHeatColor(q.rstRcvd).withOpacity(0.22),
          borderColor: _rstHeatColor(q.rstRcvd).withOpacity(0.45),
          borderStrokeWidth: 0.6,
        ),
      );
    }
    if (points.isEmpty) return const [];

    final hull = _convexHull(points);
    // Ensure the hull encloses the home QTH too so the shape is anchored
    // to the user's location even if they've never worked their own city.
    if (me != null && !_pointInHull(me, hull)) hull.add(me);

    return [
      if (hull.length >= 3)
        PolygonLayer(
          polygons: [
            Polygon(
              points: _convexHull(hull), // re-hull after possibly adding `me`
              color: const Color(0xFF00E5FF).withOpacity(0.05),
              borderColor: const Color(0xFF00E5FF).withOpacity(0.55),
              borderStrokeWidth: 1.2,
            ),
          ],
        ),
      CircleLayer(circles: circles),
    ];
  }

  /// Map an ADIF "RST received" string (e.g. "-12", "+03") to a colour on
  /// a red→yellow→green→cyan gradient.  Weak = red, strong = cyan.
  Color _rstHeatColor(String? rst) {
    final n = rst == null
        ? null
        : int.tryParse(rst.trim().replaceAll(RegExp(r'[^-0-9]'), ''));
    if (n == null)
      return const Color(0xFF888888); // neutral grey when no report
    final clamped = n.clamp(-30, 10).toDouble();
    final t = (clamped + 30) / 40.0; // 0..1
    // Piecewise interpolation red → orange → yellow → green → cyan.
    Color lerp(Color a, Color b, double x) => Color.lerp(a, b, x.clamp(0, 1))!;
    if (t < 0.33)
      return lerp(const Color(0xFFFF3B4E), const Color(0xFFFFB000), t / 0.33);
    if (t < 0.66)
      return lerp(
        const Color(0xFFFFB000),
        const Color(0xFF00FF88),
        (t - 0.33) / 0.33,
      );
    return lerp(
      const Color(0xFF00FF88),
      const Color(0xFF00E5FF),
      (t - 0.66) / 0.34,
    );
  }

  /// Andrew's monotone-chain convex hull. O(n log n). Returns points ordered
  /// counter-clockwise (last point ≠ first).
  List<LatLng> _convexHull(List<LatLng> input) {
    if (input.length <= 2) return List.of(input);
    final pts = List<LatLng>.from(input)
      ..sort(
        (a, b) => a.longitude != b.longitude
            ? a.longitude.compareTo(b.longitude)
            : a.latitude.compareTo(b.latitude),
      );
    double cross(LatLng o, LatLng a, LatLng b) =>
        (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
    final lower = <LatLng>[];
    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <LatLng>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  /// Very cheap point-in-polygon (ray casting). Good enough to decide if
  /// we need to expand the hull to include the home QTH.
  bool _pointInHull(LatLng p, List<LatLng> poly) {
    if (poly.length < 3) return false;
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude <
              (xj - xi) * (p.latitude - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  String _shortHm(DateTime dt) {
    final d = dt.toUtc();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(d.hour)}:${p2(d.minute)}Z';
  }

  Widget _buildTileLayer(MapStyle style) {
    // Buffer knobs shared by both tile layers. flutter_map's defaults
    // (keepBuffer=2, panBuffer=1) leave visible gaps during a fast pinch or
    // scroll-wheel zoom because it evicts the previous level's tiles before
    // the new level finishes fetching. Bumping the buffers keeps a wider ring
    // of tiles resident so the transition stays covered. `notVisibleRespectMargin`
    // drops broken tiles once they're safely off-screen instead of
    // re-requesting them every frame.
    const keepBuffer = 6;
    const panBuffer = 3;
    const errorStrategy = EvictErrorTileStrategy.notVisibleRespectMargin;

    // CBScope Retro = Carto Dark Matter (dark gray tiles) tinted green via a
    // per-tile color filter that keeps roads/labels legible while giving the
    // whole map the retro terminal glow. Regular = OpenStreetMap standard.
    if (style == MapStyle.cbscopeRetro) {
      return TileLayer(
        urlTemplate:
            'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'app.cbscope',
        tileProvider: NetworkTileProvider(),
        keepBuffer: keepBuffer,
        panBuffer: panBuffer,
        evictErrorTileStrategy: errorStrategy,
        maxNativeZoom: 19,
        tileBuilder: (context, tileWidget, tile) {
          // Blend the dark tile with cyan so the base map takes on the
          // Tron #00E5FF hue while retaining road/label structure.
          return ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              // R' — kill red so nothing looks warm.
              0.02, 0.02, 0.02, 0, 0,
              // G' — moderate boost, contributes to cyan.
              0.12, 0.90, 0.35, 0, 14,
              // B' — brightest channel, pushes the whole map into cyan.
              0.15, 0.55, 1.10, 0, 22,
              0, 0, 0, 1, 0,
            ]),
            child: tileWidget,
          );
        },
      );
    }
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'app.cbscope',
      tileProvider: NetworkTileProvider(),
      keepBuffer: keepBuffer,
      panBuffer: panBuffer,
      evictErrorTileStrategy: errorStrategy,
      maxNativeZoom: 19,
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? color : c.subtle,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: active ? c.text : c.subtle),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active ? c.text : c.subtle,
                  ),
            ),
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
        width: 32,
        height: 32,
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
  final bool showQsos,
      showDecodes,
      showLines,
      showMe,
      showPskSpots,
      showGreyline,
      showRunningQso;
  final QsoAgeFilter ageFilter;
  final int ageCustomMinutes;
  final double minSnr;
  const _FilterState({
    required this.showQsos,
    required this.showDecodes,
    required this.showLines,
    required this.showMe,
    required this.showPskSpots,
    required this.showGreyline,
    required this.showRunningQso,
    required this.ageFilter,
    required this.ageCustomMinutes,
    required this.minSnr,
  });
}

class _EquipmentPreviewState {
  final int? pinnedRadioId;
  final int? pinnedAntennaId;
  final int? hoverRadioId;
  final int? hoverAntennaId;

  const _EquipmentPreviewState({
    required this.pinnedRadioId,
    required this.pinnedAntennaId,
    required this.hoverRadioId,
    required this.hoverAntennaId,
  });
}

class _FilterPanel extends ConsumerWidget {
  final bool showQsos,
      showDecodes,
      showLines,
      showMe,
      showPskSpots,
      showGreyline,
      showRunningQso;
  final QsoAgeFilter ageFilter;
  final int ageCustomMinutes;
  final double minSnr;
  final int? pinnedRadioId;
  final int? pinnedAntennaId;
  final int? hoverRadioId;
  final int? hoverAntennaId;
  final HeatmapSignalDirection heatmapDirection;
  final ValueChanged<HeatmapSignalDirection> onHeatmapDirectionChanged;
  final ValueChanged<_EquipmentPreviewState> onEquipmentChanged;
  final ValueChanged<_FilterState> onChanged;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.showQsos,
    required this.showDecodes,
    required this.showLines,
    required this.showMe,
    required this.showPskSpots,
    required this.showGreyline,
    required this.showRunningQso,
    required this.ageFilter,
    required this.ageCustomMinutes,
    required this.minSnr,
    required this.pinnedRadioId,
    required this.pinnedAntennaId,
    required this.hoverRadioId,
    required this.hoverAntennaId,
    required this.heatmapDirection,
    required this.onHeatmapDirectionChanged,
    required this.onEquipmentChanged,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
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
                  _switchRow(
                    context,
                    'Logged QSOs',
                    showQsos,
                    (v) => _emit(showQsos: v),
                  ),
                  _switchRow(
                    context,
                    'Live decodes',
                    showDecodes,
                    (v) => _emit(showDecodes: v),
                  ),
                  _switchRow(
                    context,
                    'Running QSO (WSJT-CB DX)',
                    showRunningQso,
                    (v) => _emit(showRunningQso: v),
                  ),
                  _switchRow(
                    context,
                    'PSK Reporter spots',
                    showPskSpots,
                    (v) => _emit(showPskSpots: v),
                  ),
                  _switchRow(
                    context,
                    'Great-circle lines',
                    showLines,
                    (v) => _emit(showLines: v),
                  ),
                  _switchRow(
                    context,
                    'My location',
                    showMe,
                    (v) => _emit(showMe: v),
                  ),
                  _switchRow(
                    context,
                    'Greyline (day / night)',
                    showGreyline,
                    (v) => _emit(showGreyline: v),
                  ),
                  const SizedBox(height: 16),
                  _section(context, 'PSK Reporter (my callsign)'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in PskSpotDirection.values)
                        _chipToggle(
                          context,
                          _pskDirLabel(d),
                          settings.pskSpotDirection == d,
                          () {
                            ref
                                .read(settingsProvider.notifier)
                                .update(settings.copyWith(pskSpotDirection: d));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _section(context, 'PSK — timespan'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in PskSpotWindow.values)
                        _chipToggle(
                          context,
                          w.label,
                          settings.pskSpotWindow == w,
                          () {
                            ref
                                .read(settingsProvider.notifier)
                                .update(settings.copyWith(pskSpotWindow: w));
                          },
                        ),
                    ],
                  ),
                  if (settings.pskSpotWindow == PskSpotWindow.d7) ...[
                    const SizedBox(height: 6),
                    Text(
                      '7 d combines the local rolling cache with a bounded recent API sync.',
                      style: t.bodySmall?.copyWith(color: c.subtle),
                    ),
                  ],
                  if (settings.pskSpotWindow == PskSpotWindow.custom) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: settings.pskSpotCustomMinutes
                                .toDouble()
                                .clamp(1, 60),
                            min: 1,
                            max: 60,
                            divisions: 59,
                            label: '${settings.pskSpotCustomMinutes} min',
                            onChanged: (v) {
                              ref.read(settingsProvider.notifier).update(
                                    settings.copyWith(
                                      pskSpotCustomMinutes: v.round(),
                                    ),
                                  );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${settings.pskSpotCustomMinutes} min',
                            style: t.bodySmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (settings.myCall == null || settings.myCall!.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Set your callsign in Settings to enable PSK Reporter spots.',
                      style: t.bodySmall?.copyWith(color: c.warning),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _section(context, 'QSOs — age'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in QsoAgeFilter.values)
                        _chipToggle(
                          context,
                          f.label,
                          ageFilter == f,
                          () => _emit(ageFilter: f),
                        ),
                    ],
                  ),
                  if (ageFilter == QsoAgeFilter.custom) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: ageCustomMinutes.toDouble().clamp(1, 60),
                            min: 1,
                            max: 60,
                            divisions: 59,
                            label: '$ageCustomMinutes min',
                            onChanged: (v) =>
                                _emit(ageCustomMinutes: v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 58,
                          child: Text(
                            '$ageCustomMinutes min',
                            style: t.bodySmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _EquipmentHeatmapControls(
                    pinnedRadioId: pinnedRadioId,
                    pinnedAntennaId: pinnedAntennaId,
                    hoverRadioId: hoverRadioId,
                    hoverAntennaId: hoverAntennaId,
                    direction: heatmapDirection,
                    onDirectionChanged: onHeatmapDirectionChanged,
                    onChanged: onEquipmentChanged,
                  ),
                  const SizedBox(height: 16),
                  _section(context, 'Live decodes — min SNR'),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: minSnr,
                          min: -30,
                          max: 10,
                          divisions: 40,
                          label: '${minSnr.round()} dB',
                          onChanged: (v) => _emit(minSnr: v),
                        ),
                      ),
                      SizedBox(
                        width: 46,
                        child: Text(
                          '${minSnr.round()} dB',
                          style: t.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                      ),
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

  void _emit({
    bool? showQsos,
    bool? showDecodes,
    bool? showLines,
    bool? showMe,
    bool? showPskSpots,
    bool? showGreyline,
    bool? showRunningQso,
    QsoAgeFilter? ageFilter,
    int? ageCustomMinutes,
    double? minSnr,
  }) {
    onChanged(
      _FilterState(
        showQsos: showQsos ?? this.showQsos,
        showDecodes: showDecodes ?? this.showDecodes,
        showLines: showLines ?? this.showLines,
        showMe: showMe ?? this.showMe,
        showPskSpots: showPskSpots ?? this.showPskSpots,
        showGreyline: showGreyline ?? this.showGreyline,
        showRunningQso: showRunningQso ?? this.showRunningQso,
        ageFilter: ageFilter ?? this.ageFilter,
        ageCustomMinutes: ageCustomMinutes ?? this.ageCustomMinutes,
        minSnr: minSnr ?? this.minSnr,
      ),
    );
  }

  String _pskDirLabel(PskSpotDirection d) => switch (d) {
        PskSpotDirection.off => 'Off',
        PskSpotDirection.sent => 'Heard me',
        PskSpotDirection.received => 'I heard',
        PskSpotDirection.both => 'Both',
      };

  Widget _section(BuildContext context, String label) =>
      Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);

  Widget _switchRow(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _chipToggle(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
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
        child: Text(
          label,
          style: t.bodySmall?.copyWith(
            color: selected ? c.accent : c.text,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
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
  const _QsoMarker({
    required this.qso,
    this.distanceKm,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _QsoTooltipCard(qso: qso, distanceKm: distanceKm, unit: unit),
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(6),
      preferBelow: false,
      triggerMode: TooltipTriggerMode.tap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onDoubleTap: () => showStationProfile(context, qso.call),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(0.88),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.35), blurRadius: 4),
                ],
              ),
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
  const _QsoTooltipCard({
    required this.qso,
    this.distanceKm,
    required this.unit,
  });

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
              Text(
                df.format(qso.timeOn.toUtc()),
                style: t.bodySmall?.copyWith(fontFamily: 'Menlo'),
              ),
              const SizedBox(height: 8),
              _kv(context, 'Grid', qso.gridsquare ?? '—'),
              _kv(
                context,
                'RST S/R',
                '${qso.rstSent ?? '-'} / ${qso.rstRcvd ?? '-'}',
              ),
              if (qso.name != null && qso.name!.isNotEmpty)
                _kv(context, 'Name', qso.name!),
              if (qso.country != null && qso.country!.isNotEmpty)
                _kv(context, 'Country', qso.country!),
              if (qso.comment != null && qso.comment!.isNotEmpty)
                _kv(context, 'Comment', qso.comment!),
              if (qso.myGrid != null && qso.myGrid!.isNotEmpty)
                _kv(context, 'My QTH', qso.myGrid!),
              _WeatherRow(rawFields: qso.rawFields),
              if (distanceKm != null) ...[
                const Divider(height: 12),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 12, color: c.subtle),
                    const SizedBox(width: 6),
                    Text(
                      '${unit.from(distanceKm!).toStringAsFixed(0)} ${unit.label}',
                      style: t.bodySmall,
                    ),
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
          SizedBox(
            width: 68,
            child: Text(k, style: t.labelSmall?.copyWith(color: c.subtle)),
          ),
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

/// Day/night terminator overlay. Uses [computeGreyline] to build a chain
/// of points across the map; the "night" hemisphere is shown as a soft
/// dark polygon and the terminator itself as a thin dashed line so it
/// remains visible against the retro dark tiles.
class _GreylineLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = computeGreyline(DateTime.now().toUtc());
    // Night polygon: terminator + a wrap around the pole away from the sun.
    final northernSummer = result.solarDeclDeg > 0;
    final poleLat = northernSummer ? -85.0 : 85.0;
    final poly = <LatLng>[
      ...result.terminator,
      LatLng(poleLat, 180),
      LatLng(poleLat, -180),
    ];
    return Stack(
      children: [
        PolygonLayer(
          polygons: [
            Polygon(
              points: poly,
              color: Colors.black.withOpacity(0.30),
              borderColor: Colors.transparent,
              borderStrokeWidth: 0,
            ),
          ],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: result.terminator,
              color: c.warning.withOpacity(0.75),
              strokeWidth: 1.4,
              pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small "WSJT-CB connected/waiting" pill anchored upper-left of the map,
/// mirroring the Live screen's status dot so users always see the link
/// state at a glance.
class _WsjtStatusPill extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WsjtStatusPill> createState() => _WsjtStatusPillState();
}

class _WsjtStatusPillState extends ConsumerState<_WsjtStatusPill> {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final udp = ref.watch(udpListenerProvider);
    final last = udp.lastPacketAt;
    final connected =
        last != null && DateTime.now().difference(last).inSeconds < 20;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: c.card.withOpacity(0.92),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            color: connected ? c.success : c.subtle,
          ),
          const SizedBox(width: 8),
          Text('WSJT-CB', style: t.labelSmall),
          const SizedBox(width: 6),
          Text(
            connected ? 'CONNECTED' : 'WAITING',
            style: t.labelSmall?.copyWith(
              color: connected ? c.success : c.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-of-map timeline scrubber for replay mode. The slider represents
/// [spanHours] worth of history ending at "now" — sliding left rewinds the
/// visible universe of QSOs / decodes / spots.
class _ReplayBar extends StatelessWidget {
  final DateTime at;
  final int spanHours;
  final bool autoplay;
  final ValueChanged<DateTime> onSeek;
  final ValueChanged<int> onSpanChanged;
  final VoidCallback onPlayToggle;
  final VoidCallback onClose;

  const _ReplayBar({
    required this.at,
    required this.spanHours,
    required this.autoplay,
    required this.onSeek,
    required this.onSpanChanged,
    required this.onPlayToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final now = DateTime.now().toUtc();
    final start = now.subtract(Duration(hours: spanHours));
    final total = now.difference(start).inMilliseconds.toDouble();
    final pos = at
        .toUtc()
        .difference(start)
        .inMilliseconds
        .toDouble()
        .clamp(0.0, total);

    String label(DateTime d) {
      final u = d.toUtc();
      String p2(int n) => n.toString().padLeft(2, '0');
      return '${u.year}-${p2(u.month)}-${p2(u.day)}  ${p2(u.hour)}:${p2(u.minute)}Z';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card.withOpacity(0.94),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 14, color: c.subtle),
                const SizedBox(width: 6),
                Text('REPLAY', style: t.labelSmall),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onPlayToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (autoplay ? c.accent : c.surface),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          autoplay ? Icons.pause : Icons.play_arrow,
                          size: 12,
                          color: autoplay ? Colors.black : c.text,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          autoplay ? 'PAUSE' : 'PLAY',
                          style: t.labelSmall?.copyWith(
                            color: autoplay ? Colors.black : c.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Span-of-history selector (few common presets).
                for (final h in const [6, 24, 72])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => onSpanChanged(h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: spanHours == h
                              ? c.accent.withOpacity(0.15)
                              : c.surface,
                          border: Border.all(
                            color: spanHours == h ? c.accent : c.border,
                          ),
                        ),
                        child: Text(
                          '${h}h',
                          style: t.labelSmall?.copyWith(
                            color: spanHours == h ? c.accent : c.subtle,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  label(at),
                  style: t.bodySmall?.copyWith(fontFamily: 'Menlo'),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: c.subtle),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: pos,
                min: 0,
                max: total <= 0 ? 1 : total,
                onChanged: (v) =>
                    onSeek(start.add(Duration(milliseconds: v.round()))),
              ),
            ),
          ],
        ),
      ),
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
    try {
      m = jsonDecode(rawFields!) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final sfi = m['app_qsobook_sfi'];
    final k = m['app_qsobook_k_index'];
    final a = m['app_qsobook_a_index'];
    final ss = m['app_qsobook_sunspots'];
    final cond = m['app_qsobook_band_condition'];
    if (sfi == null && k == null && a == null && ss == null && cond == null) {
      return const SizedBox.shrink();
    }
    final parts = <String>[
      if (sfi != null) 'SFI $sfi',
      if (k != null) 'K $k',
      if (a != null) 'A $a',
      if (ss != null) 'SS $ss',
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
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: t.labelSmall?.copyWith(
                color: c.subtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map-local equipment comparison controls.
///
/// Hovering previews a radio/antenna immediately. Clicking pins it, allowing
/// the other equipment category to be hovered for quick intersections.
class _EquipmentHeatmapControls extends ConsumerWidget {
  final int? pinnedRadioId;
  final int? pinnedAntennaId;
  final int? hoverRadioId;
  final int? hoverAntennaId;
  final HeatmapSignalDirection direction;
  final ValueChanged<HeatmapSignalDirection> onDirectionChanged;
  final ValueChanged<_EquipmentPreviewState> onChanged;

  const _EquipmentHeatmapControls({
    required this.pinnedRadioId,
    required this.pinnedAntennaId,
    required this.hoverRadioId,
    required this.hoverAntennaId,
    required this.direction,
    required this.onDirectionChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
    final rigs = ref.watch(rigsProvider).valueOrNull ?? const [];

    void emit({
      int? pinnedRadio,
      int? pinnedAntenna,
      int? hoverRadio,
      int? hoverAntenna,
      bool clearPinnedRadio = false,
      bool clearPinnedAntenna = false,
      bool clearHoverRadio = false,
      bool clearHoverAntenna = false,
    }) {
      onChanged(
        _EquipmentPreviewState(
          pinnedRadioId:
              clearPinnedRadio ? null : (pinnedRadio ?? pinnedRadioId),
          pinnedAntennaId:
              clearPinnedAntenna ? null : (pinnedAntenna ?? pinnedAntennaId),
          hoverRadioId: clearHoverRadio ? null : (hoverRadio ?? hoverRadioId),
          hoverAntennaId:
              clearHoverAntenna ? null : (hoverAntenna ?? hoverAntennaId),
        ),
      );
    }

    Widget chip({
      required String label,
      required bool pinned,
      required bool previewed,
      required VoidCallback onTap,
      required VoidCallback onEnter,
      required VoidCallback onExit,
    }) {
      final active = pinned || previewed;
      return MouseRegion(
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? c.accent.withOpacity(pinned ? 0.20 : 0.10)
                  : c.surface,
              border: Border.all(
                color: active ? c.accent : c.border,
                width: pinned ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinned) ...[
                  Icon(Icons.push_pin, size: 11, color: c.accent),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: t.bodySmall?.copyWith(
                    color: active ? c.accent : c.text,
                    fontWeight: pinned ? FontWeight.w800 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EQUIPMENT HEATMAP', style: t.labelSmall),
        const SizedBox(height: 4),
        Text(
          'Hover to preview. Click to pin; then hover the other group to compare.',
          style: t.bodySmall?.copyWith(color: c.subtle),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final value in HeatmapSignalDirection.values)
              ChoiceChip(
                label: Text(value.label),
                selected: direction == value,
                onSelected: (_) => onDirectionChanged(value),
                selectedColor: c.accent.withValues(alpha: 0.2),
                side: BorderSide(
                  color: direction == value ? c.accent : c.border,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          direction.explanation,
          style: t.labelSmall?.copyWith(color: c.subtle),
        ),
        if (rigs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('QSOs — RADIO', style: t.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in rigs)
                chip(
                  label: r.name,
                  pinned: pinnedRadioId == r.id,
                  previewed: hoverRadioId == r.id,
                  onTap: () => emit(
                    pinnedRadio: r.id,
                    clearPinnedRadio: pinnedRadioId == r.id,
                    clearHoverRadio: true,
                  ),
                  onEnter: () => emit(hoverRadio: r.id),
                  onExit: () => emit(clearHoverRadio: true),
                ),
            ],
          ),
        ],
        if (antennas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('QSOs — ANTENNA', style: t.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in antennas)
                chip(
                  label: a.name,
                  pinned: pinnedAntennaId == a.id,
                  previewed: hoverAntennaId == a.id,
                  onTap: () => emit(
                    pinnedAntenna: a.id,
                    clearPinnedAntenna: pinnedAntennaId == a.id,
                    clearHoverAntenna: true,
                  ),
                  onEnter: () => emit(hoverAntenna: a.id),
                  onExit: () => emit(clearHoverAntenna: true),
                ),
            ],
          ),
        ],
        if (pinnedRadioId != null || pinnedAntennaId != null) ...[
          const SizedBox(height: 8),
          Text(
            'Pinned selections reset when Filters closes.',
            style: t.labelSmall?.copyWith(color: c.accent),
          ),
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
String _formatAge(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m ago';
  return '${d.inDays}d ${d.inHours % 24}h ago';
}

class _PskSpotMarker extends StatelessWidget {
  final PskSpot spot;
  final Color color;
  final double? distanceKm;
  final DistanceUnit unit;
  const _PskSpotMarker({
    required this.spot,
    required this.color,
    this.distanceKm,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final freqMhz = spot.freqHz / 1e6;
    final age = DateTime.now().toUtc().difference(spot.at.toUtc());
    final ageStr = _formatAge(age);
    final tip = StringBuffer()
      ..write('[PSK REPORTER]\n')
      ..write(
        spot.direction == PskDirection.sent ? 'HEARD ME:  ' : 'I HEARD:  ',
      )
      ..write(spot.otherCall)
      ..write('  ·  ')
      ..write(spot.otherGrid)
      ..write('\n')
      ..write('${freqMhz.toStringAsFixed(3)} MHz  ·  ')
      ..write(spot.snr >= 0 ? '+${spot.snr}' : '${spot.snr}')
      ..write(' dB  ·  ')
      ..write(spot.mode)
      ..write('\n')
      ..write(ageStr);
    if (distanceKm != null) {
      tip
        ..write('  ·  ')
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
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact legend for the equipment heatmap. Renders the same red→amber→
/// green→cyan gradient the raster uses, with a few tick labels so the user
/// can read a colour back into an approximate FT8 dB report.
class _HeatmapLegend extends StatelessWidget {
  final HeatmapSignalDirection direction;
  const _HeatmapLegend({required this.direction});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    // Sample the gradient across the same [-30, +10] dB range the heatmap
    // uses, so the bar's colours match the raster exactly.
    const stops = 32;
    final colors = <Color>[
      for (var i = 0; i < stops; i++)
        heatmapReportColor(-30 + (40 * i / (stops - 1))),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      color: c.card.withOpacity(0.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gradient, size: 12, color: c.subtle),
              const SizedBox(width: 6),
              Text(
                direction == HeatmapSignalDirection.send
                    ? 'HEATMAP · signal RECEIVED by DX (dB)'
                    : 'HEATMAP · signal SENT to us by DX (dB)',
                style: t.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: 220,
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              border: Border.all(color: c.border, width: 0.6),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in const ['−30', '−17', '−4', '+10'])
                  Text(label,
                      style: t.labelSmall
                          ?.copyWith(fontFamily: 'Menlo', color: c.subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// QTH marker for the operator. Idle: a small filled dot. Calling CQ: a
/// pulsing halo + "CQ" badge, so a glance at the map shows you're on air.
class _MeMarker extends StatelessWidget {
  final Color color;
  final String? call;
  final String? grid;
  final bool callingCq;
  const _MeMarker({
    required this.color,
    required this.call,
    required this.grid,
    required this.callingCq,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tooltip =
        'You  ·  ${call ?? ''}  ·  ${grid ?? ''}${callingCq ? '\nCalling CQ' : ''}';
    // 0..1 pulse driven by wallclock; parent's 200 ms tick rebuilds the map.
    final phase = (DateTime.now().millisecondsSinceEpoch % 1400) / 1400.0;
    final halo = 22.0 + 22.0 * phase;
    final haloAlpha = (0.55 * (1 - phase)).clamp(0.0, 1.0);
    final dot = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
        ],
      ),
    );
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: !callingCq
          ? SizedBox(width: 24, height: 24, child: dot)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    'CQ',
                    style: t.labelSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 46,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: halo,
                        height: halo,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withOpacity(haloAlpha),
                            width: 1.6,
                          ),
                        ),
                      ),
                      SizedBox(width: 18, height: 18, child: dot),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Marker for an in-progress QSO reported via WSJT-CB's Status packet.
/// Shows the DX callsign + grid with a pulsing halo; the halo phase relies
/// on the map's 200 ms fade tick so no extra AnimationController is needed.
class _RunningQsoMarker extends StatelessWidget {
  final String call;
  final String grid;
  final bool transmitting;
  final Color color;
  final bool engaged;
  const _RunningQsoMarker({
    required this.call,
    required this.grid,
    required this.transmitting,
    required this.color,
    required this.engaged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // 0..1 pulse driven by wallclock — parent's 200 ms tick rebuilds the map.
    final phase =
        (DateTime.now().millisecondsSinceEpoch % 1200) / 1200.0;
    final halo = 6.0 + 10.0 * phase;
    final baseHaloAlpha = engaged ? 0.55 : 0.28;
    final haloAlpha = (baseHaloAlpha * (1 - phase)).clamp(0.0, 1.0);
    // Softer badge + dot when we're still just calling and haven't been
    // answered yet — draws the eye less than a confirmed engaged QSO.
    final badgeAlpha = engaged ? 1.0 : 0.55;
    final dotAlpha = engaged ? 1.0 : 0.7;
    return Tooltip(
      message: '$call · $grid\n'
          '${engaged ? (transmitting ? 'Transmitting to' : 'Waiting for reply from') : 'Calling'} $call',
      waitDuration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(badgeAlpha),
              border: Border.all(
                color: Colors.white.withOpacity(engaged ? 1.0 : 0.7),
                width: 1,
              ),
            ),
            child: Text(
              engaged ? call : '→ $call',
              style: t.labelSmall?.copyWith(
                color: Colors.black,
                fontWeight: engaged ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: halo,
                  height: halo,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(haloAlpha),
                      width: 1.5,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withOpacity(dotAlpha),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(engaged ? 1.0 : 0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(engaged ? 0.7 : 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withOpacity(alpha),
        shape: BoxShape.circle,
        border: gridWasHinted
            ? null
            : Border.all(
                color: Colors.white.withOpacity(0.9 * alpha),
                width: 1.4,
              ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6 * alpha),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
    return Tooltip(
      message: tooltip.toString(),
      waitDuration: const Duration(milliseconds: 250),
      child: isNewCq
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.success.withOpacity(0.90 * alpha),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9 * alpha),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'NEW CQ · $call',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
                const SizedBox(height: 3),
                dot,
              ],
            )
          : Center(child: dot),
    );
  }
}
