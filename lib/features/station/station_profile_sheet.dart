import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/cb_dxcc.dart';
import '../../core/util/maidenhead.dart';
import '../../core/widgets/app_card.dart';
import '../../data/db/database.dart';
import '../../providers/providers.dart';

/// Full-height right-side sheet with everything we know about a callsign:
/// QSO history, RST distribution, distance, radio/antenna usage, notes.
/// Callable from Live, Map, Logbook (or anywhere via [showStationProfile]).
Future<void> showStationProfile(BuildContext context, String call) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 520,
        height: double.infinity,
        child: StationProfileSheet(call: call),
      ),
    ),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
  );
}

class StationProfileSheet extends ConsumerWidget {
  final String call;
  const StationProfileSheet({super.key, required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(qsoRepoProvider);
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final myLatLng = gridToLatLng(settings.myGrid);
    final resolver = ref.watch(callsignResolverProvider);
    final resolvedGrid = resolver.gridFor(call);

    return Material(
      color: c.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.border))),
        child: FutureBuilder<List<Qso>>(
          future: repo.qsosByCall(call),
          builder: (context, snap) {
            final qsos = snap.data ?? const <Qso>[];
            final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
            final rigs     = ref.watch(rigsProvider).valueOrNull ?? const [];
            final antennaName = {for (final a in antennas) a.id: a.name};
            final rigName     = {for (final r in rigs) r.id: r.name};

            String? grid;
            String? country;
            for (final q in qsos) {
              if (grid == null && q.gridsquare != null && q.gridsquare!.length >= 4) grid = q.gridsquare;
              if (country == null && q.country != null && q.country!.isNotEmpty)     country = q.country;
              if (grid != null && country != null) break;
            }
            grid    ??= resolvedGrid;
            country ??= countryFromCbCallsign(call);

            final targetLL = gridToLatLng(grid);
            final distKm = (targetLL != null && myLatLng != null)
                ? const Distance().as(LengthUnit.Kilometer, myLatLng, targetLL)
                : null;

            // Aggregate metrics
            final bands = <String, int>{};
            final modes = <String, int>{};
            final rigUsage = <String, int>{};
            final antUsage = <String, int>{};
            final rstBuckets = <int, int>{}; // 5 dB buckets
            String? firstNote;
            for (final q in qsos) {
              bands[q.band] = (bands[q.band] ?? 0) + 1;
              modes[q.mode] = (modes[q.mode] ?? 0) + 1;
              if (q.radioId != null) {
                final n = rigName[q.radioId!] ?? '(deleted)';
                rigUsage[n] = (rigUsage[n] ?? 0) + 1;
              }
              if (q.antennaId != null) {
                final n = antennaName[q.antennaId!] ?? '(deleted)';
                antUsage[n] = (antUsage[n] ?? 0) + 1;
              }
              final r = q.rstRcvd?.trim();
              if (r != null && r.isNotEmpty) {
                final n = int.tryParse(r.replaceAll(RegExp(r'[^-0-9]'), ''));
                if (n != null) {
                  final bucket = (n / 5).floor() * 5;
                  rstBuckets[bucket] = (rstBuckets[bucket] ?? 0) + 1;
                }
              }
              firstNote ??= (q.personalNotes?.trim().isNotEmpty ?? false) ? q.personalNotes : null;
            }

            final unit = settings.distanceUnit;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(call, style: t.headlineLarge?.copyWith(color: c.accent)),
                              const SizedBox(width: 10),
                              Text('· ${qsos.length} QSO${qsos.length == 1 ? '' : 's'}',
                                  style: t.bodySmall),
                            ]),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 2, children: [
                              if (grid != null)    _tag(context, Icons.grid_4x4, grid),
                              if (country != null) _tag(context, Icons.public, country),
                              if (distKm != null)  _tag(context, Icons.straighten,
                                  '${unit.from(distKm).toStringAsFixed(0)} ${unit.label}'),
                            ]),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, size: 16, color: c.text),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Equipment usage
                        if (rigUsage.isNotEmpty || antUsage.isNotEmpty) ...[
                          Text('EQUIPMENT USED', style: t.labelSmall),
                          const SizedBox(height: 6),
                          _usageRow(context, 'Radios', rigUsage),
                          const SizedBox(height: 4),
                          _usageRow(context, 'Antennas', antUsage),
                          const SizedBox(height: 16),
                        ],

                        // RST distribution
                        if (rstBuckets.isNotEmpty) ...[
                          Text('SIGNAL REPORTS (RECEIVED)', style: t.labelSmall),
                          const SizedBox(height: 6),
                          _rstHistogram(context, rstBuckets),
                          const SizedBox(height: 16),
                        ],

                        // Band / mode summary
                        if (bands.isNotEmpty || modes.isNotEmpty) ...[
                          Text('BANDS & MODES', style: t.labelSmall),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final e in bands.entries) _pillCount(context, e.key, e.value),
                            for (final e in modes.entries) _pillCount(context, e.key, e.value, alt: true),
                          ]),
                          const SizedBox(height: 16),
                        ],

                        // Notes
                        if (firstNote != null) ...[
                          Text('NOTES', style: t.labelSmall),
                          const SizedBox(height: 6),
                          AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Text(firstNote, style: t.bodyMedium),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // QSO history table
                        Text('QSO HISTORY', style: t.labelSmall),
                        const SizedBox(height: 6),
                        if (qsos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('No logged QSOs with this station yet.',
                                style: t.bodySmall),
                          )
                        else
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (int i = 0; i < qsos.length; i++)
                                  _historyRow(context, qsos[i],
                                      antennaName: antennaName[qsos[i].antennaId ?? -1],
                                      rigName: rigName[qsos[i].radioId ?? -1],
                                      last: i == qsos.length - 1),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, IconData icon, String label) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c.subtle),
      const SizedBox(width: 4),
      Text(label, style: t.bodySmall),
    ]);
  }

  Widget _usageRow(BuildContext context, String label, Map<String, int> counts) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    if (counts.isEmpty) {
      return Row(children: [
        SizedBox(width: 90, child: Text(label, style: t.bodySmall?.copyWith(color: c.subtle))),
        Text('—', style: t.bodySmall?.copyWith(color: c.subtle)),
      ]);
    }
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: t.bodySmall?.copyWith(color: c.subtle))),
      Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final e in counts.entries) _pillCount(context, e.key, e.value),
      ])),
    ]);
  }

  Widget _pillCount(BuildContext context, String label, int count, {bool alt = false}) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (alt ? c.warning : c.accent).withOpacity(0.12),
        border: Border.all(color: (alt ? c.warning : c.accent).withOpacity(0.5)),
      ),
      child: Text('$label · $count',
          style: t.labelSmall?.copyWith(color: alt ? c.warning : c.accent, fontWeight: FontWeight.w700)),
    );
  }

  Widget _rstHistogram(BuildContext context, Map<int, int> buckets) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final entries = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxN = entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 46, child: Text('${e.key >= 0 ? '+' : ''}${e.key} dB',
                  style: t.labelSmall?.copyWith(fontFamily: 'Menlo'))),
              Expanded(child: Stack(children: [
                Container(height: 6, decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border),
                )),
                FractionallySizedBox(
                  widthFactor: (e.value / (maxN == 0 ? 1 : maxN)).clamp(0.05, 1.0),
                  child: Container(height: 6, color: c.accent),
                ),
              ])),
              const SizedBox(width: 8),
              SizedBox(width: 26,
                child: Text('${e.value}', style: t.labelSmall, textAlign: TextAlign.right)),
            ]),
          ),
      ]),
    );
  }

  Widget _historyRow(BuildContext context, Qso q,
      {String? antennaName, String? rigName, required bool last}) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(df.format(q.timeOn.toUtc()),
              style: t.bodyMedium?.copyWith(fontFamily: 'Menlo'))),
          SizedBox(width: 56, child: Text(q.band, style: t.bodyMedium)),
          SizedBox(width: 56, child: Text(q.mode, style: t.bodyMedium)),
          SizedBox(width: 82, child: Text('${q.rstSent ?? '-'} / ${q.rstRcvd ?? '-'}',
              style: t.bodyMedium?.copyWith(fontFamily: 'Menlo'))),
          Expanded(child: Text(
            [
              if (rigName    != null) rigName,
              if (antennaName != null) antennaName,
              if ((q.personalNotes ?? '').isNotEmpty) '"${q.personalNotes}"',
            ].join(' · '),
            style: t.bodySmall,
            maxLines: 2, overflow: TextOverflow.ellipsis,
          )),
        ],
      ),
    );
  }
}
