import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/propagation_card.dart';
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
        ],
      ),
    );
  }
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
