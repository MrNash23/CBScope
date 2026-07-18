import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/propagation_card.dart';
import '../../data/db/qso_repository.dart';
import '../../providers/providers.dart';
import 'distance_polar_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis      = ref.watch(kpisProvider);
    final perDay    = ref.watch(qsoPerDayProvider);
    final freqHist  = ref.watch(freqHistogramProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Stats', subtitle: '11 m CB FT8 activity, aggregated across your logbook.'),
          kpis.when(
            data: (k) => Row(
              children: [
                Expanded(child: KpiTile(label: 'QSOs',       value: '${k.total}',           icon: Icons.forum_outlined)),
                const SizedBox(width: 12),
                Expanded(child: KpiTile(label: 'Unique Calls', value: '${k.uniqueCalls}',   icon: Icons.people_alt_outlined)),
                const SizedBox(width: 12),
                Expanded(child: KpiTile(label: 'Grids',      value: '${k.uniqueGrids}',     icon: Icons.grid_4x4)),
                const SizedBox(width: 12),
                Expanded(child: KpiTile(label: 'Countries',  value: '${k.uniqueCountries}', icon: Icons.public)),
              ],
            ),
            loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator.adaptive())),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 16),
          const _HighlightsCard(),
          const SizedBox(height: 16),
          const PropagationCard(),
          const SizedBox(height: 16),
          AppCard(
            child: SizedBox(
              height: 260,
              child: perDay.when(
                data: (m) => _DayBarChart(m: m),
                loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Text('$e'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: SizedBox(
              height: 260,
              child: freqHist.when(
                data: (m) => _FreqHistogram(m: m),
                loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Text('$e'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: SizedBox(
              height: 420,
              child: const DistancePolarChart(),
            ),
          ),
          const SizedBox(height: 16),
          const _EquipmentComparisonTable(),
        ],
      ),
    );
  }
}

/// Equipment performance comparison — each radio + antenna row shows QSO
/// count, unique 4-char grids worked, unique countries, average distance
/// and best DX (with the callsign that scored it).
class _EquipmentComparisonTable extends ConsumerWidget {
  const _EquipmentComparisonTable();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final unit = ref.watch(settingsProvider).distanceUnit;
    final async = ref.watch(equipmentStatsProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: async.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator.adaptive())),
        error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EQUIPMENT PERFORMANCE', style: t.labelSmall),
                  const SizedBox(height: 8),
                  Text('Tag your QSOs in Review with a radio and antenna to fill this table.',
                      style: t.bodySmall),
                ]),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border))),
                child: Row(children: [
                  Icon(Icons.equalizer, size: 12, color: c.subtle),
                  const SizedBox(width: 6),
                  Text('EQUIPMENT PERFORMANCE', style: t.labelSmall),
                ]),
              ),
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  _h(context, 'Equipment', 190),
                  _h(context, 'Kind', 60),
                  _h(context, 'QSOs', 55, alignRight: true),
                  _h(context, 'Grids', 55, alignRight: true),
                  _h(context, 'Countries', 75, alignRight: true),
                  _h(context, 'Avg dist', 80, alignRight: true),
                  _h(context, 'Best DX', 130, alignRight: true),
                  _h(context, 'Avg RST', 65, alignRight: true),
                ]),
              ),
              Container(height: 1, color: c.border),
              for (int i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: c.border.withOpacity(0.5))),
                  ),
                  child: Row(children: [
                    _v(context, rows[i].name, 190, bold: true),
                    _v(context, rows[i].kind, 60),
                    _v(context, '${rows[i].qsoCount}', 55, alignRight: true),
                    _v(context, '${rows[i].uniqueGrids}', 55, alignRight: true),
                    _v(context, '${rows[i].uniqueCountries}', 75, alignRight: true),
                    _v(context, rows[i].avgDistanceKm == null
                        ? '—'
                        : '${unit.from(rows[i].avgDistanceKm!).toStringAsFixed(0)} ${unit.label}',
                        80, alignRight: true),
                    _v(context, rows[i].bestDxKm == null
                        ? '—'
                        : '${unit.from(rows[i].bestDxKm!).toStringAsFixed(0)} ${unit.label}'
                            '${rows[i].bestDxCall != null ? '  ${rows[i].bestDxCall}' : ''}',
                        130, alignRight: true),
                    _v(context, rows[i].avgRstRcvd == null
                        ? '—'
                        : (rows[i].avgRstRcvd! >= 0 ? '+' : '')
                            + rows[i].avgRstRcvd!.toStringAsFixed(0) + ' dB',
                        65, alignRight: true),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _h(BuildContext context, String s, double w, {bool alignRight = false}) => SizedBox(
        width: w,
        child: Text(s.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: alignRight ? TextAlign.right : TextAlign.left),
      );
  Widget _v(BuildContext context, String s, double w, {bool bold = false, bool alignRight = false}) => SizedBox(
        width: w,
        child: Text(s,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : null,
              fontFamily: alignRight ? 'Menlo' : null,
            ),
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

class _DayBarChart extends StatelessWidget {
  final Map<String, int> m;
  const _DayBarChart({required this.m});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    if (m.isEmpty) {
      return Center(child: Text('No QSOs in the last 60 days', style: t.bodySmall));
    }
    final entries = m.entries.toList();
    final maxRaw = entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxRaw == 0 ? 1 : maxRaw * 1.15).toDouble();
    final barWidth = entries.length > 30 ? 6.0 : entries.length > 14 ? 12.0 : 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QSO / day', style: t.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceBetween,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              horizontalInterval: (maxY / 4).clamp(1.0, 1e6).toDouble(),
              getDrawingHorizontalLine: (v) => FlLine(color: c.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles:   const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                interval: (maxY / 4).clamp(1.0, 1e6).toDouble(),
                getTitlesWidget: (v, meta) => SideTitleWidget(axisSide: meta.axisSide,
                  child: Text(v.toInt().toString(), style: t.labelSmall)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 24,
                interval: (entries.length / 7).clamp(1.0, 1e6).toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  DateTime? d;
                  try { d = DateTime.parse(entries[i].key); } catch (_) {}
                  return SideTitleWidget(axisSide: meta.axisSide,
                    child: Text(d == null ? entries[i].key : DateFormat('MM-dd').format(d), style: t.labelSmall));
                })),
            ),
            barGroups: [
              for (int i = 0; i < entries.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: c.accent,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ]),
            ],
          )),
        ),
      ],
    );
  }
}

class _FreqHistogram extends StatelessWidget {
  /// keys are bin centers in kHz.
  final Map<int, int> m;
  const _FreqHistogram({required this.m});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    if (m.isEmpty) {
      return Center(child: Text('No frequency data yet', style: t.bodySmall));
    }
    final entries = m.entries.toList();
    final maxRaw = entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxRaw == 0 ? 1 : maxRaw * 1.15).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Frequency usage', style: t.titleSmall),
            const SizedBox(width: 8),
            Text('(5 kHz bins)', style: t.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceBetween,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              horizontalInterval: (maxY / 4).clamp(1.0, 1e6).toDouble(),
              getDrawingHorizontalLine: (v) => FlLine(color: c.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles:   const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                interval: (maxY / 4).clamp(1.0, 1e6).toDouble(),
                getTitlesWidget: (v, meta) => SideTitleWidget(axisSide: meta.axisSide,
                  child: Text(v.toInt().toString(), style: t.labelSmall)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 28,
                interval: (entries.length / 6).clamp(1.0, 1e6).toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  final khz = entries[i].key;
                  return SideTitleWidget(axisSide: meta.axisSide,
                    child: Text((khz / 1000).toStringAsFixed(3), style: t.labelSmall));
                })),
            ),
            barGroups: [
              for (int i = 0; i < entries.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: c.warning,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ]),
            ],
          )),
        ),
      ],
    );
  }
}

/// Highlights strip: longest QSO, best signal, weakest signal. Rendered as
/// three compact tiles with the winner's callsign + supporting metric.
class _HighlightsCard extends ConsumerWidget {
  const _HighlightsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(statsExtrasProvider);
    final unit = ref.watch(settingsProvider).distanceUnit;
    return extras.when(
      loading: () => const AppCard(child: SizedBox(height: 60,
        child: Center(child: CircularProgressIndicator.adaptive()))),
      error: (e, _) => AppCard(child: Text('$e')),
      data: (x) => Row(children: [
        Expanded(child: _tile(context, 'LONGEST',
          x.longestKm == null ? '—' : '${unit.from(x.longestKm!).toStringAsFixed(0)} ${unit.label}',
          x.longestQso?.call, Icons.straighten)),
        const SizedBox(width: 12),
        Expanded(child: _tile(context, 'BEST SIGNAL',
          x.bestSnr == null ? '—' : (x.bestSnr! >= 0 ? '+${x.bestSnr}' : '${x.bestSnr}') + ' dB',
          x.bestSnrQso?.call, Icons.trending_up)),
        const SizedBox(width: 12),
        Expanded(child: _tile(context, 'WEAKEST SIGNAL',
          x.worstSnr == null ? '—' : (x.worstSnr! >= 0 ? '+${x.worstSnr}' : '${x.worstSnr}') + ' dB',
          x.worstSnrQso?.call, Icons.trending_down)),
      ]),
    );
  }

  Widget _tile(BuildContext context, String label, String value, String? sub, IconData icon) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: c.subtle),
            const SizedBox(width: 6),
            Text(label, style: t.labelSmall),
          ]),
          const SizedBox(height: 6),
          Text(value, style: t.headlineSmall),
          if (sub != null) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub, style: t.bodySmall?.copyWith(color: c.subtle)),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ModeRow extends StatelessWidget {
  final Map<String, int> counts;
  const _ModeRow({required this.counts});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    if (counts.isEmpty) return Center(child: Text('No mode data yet', style: t.bodySmall));
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modes', style: t.titleSmall),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(e.key, style: t.bodyMedium)),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(height: 8, decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: c.border),
                              )),
                              FractionallySizedBox(
                                widthFactor: (e.value / total).clamp(0.02, 1.0),
                                child: Container(height: 8, decoration: BoxDecoration(
                                  color: c.accent,
                                  borderRadius: BorderRadius.circular(4),
                                )),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 60,
                          child: Text('${e.value}  ·  ${((e.value/total)*100).toStringAsFixed(0)}%',
                            style: t.labelSmall, textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
