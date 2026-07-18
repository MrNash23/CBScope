import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/propagation/solar_client.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Compact solar / propagation summary sourced from hamqsl.com.
///
/// For 11m CB the numbers to watch are Solar Flux (higher = better MUF for
/// the 10-12m range) and K-index (higher = worse). We surface those plus
/// the day/night band condition for 12-10m.
class PropagationCard extends ConsumerWidget {
  final bool compact;
  const PropagationCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(solarDataProvider).valueOrNull;
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    if (data == null) {
      return AppCard(
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.subtle)),
            const SizedBox(width: 10),
            Text('Loading propagation…', style: t.bodySmall),
          ],
        ),
      );
    }

    final dayCond   = data.twelveTenCondition('day')   ?? '—';
    final nightCond = data.twelveTenCondition('night') ?? '—';

    Widget statCell(String label, String value, {Color? valueColor}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: t.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: (compact ? t.titleMedium : t.headlineSmall)?.copyWith(color: valueColor)),
          ],
        );

    Color sfiColor(double? sfi) => sfi == null
        ? c.subtle
        : sfi > 150 ? c.success : sfi > 100 ? c.warning : c.danger;
    Color kColor(double? k) => k == null
        ? c.subtle
        : k <= 2 ? c.success : k <= 4 ? c.warning : c.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8, runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wb_sunny_outlined, size: 14, color: c.subtle),
                const SizedBox(width: 6),
                Text('PROPAGATION', style: t.labelSmall),
              ]),
              if (data.updated != null)
                Text(data.updated!.trim(), style: t.labelSmall?.copyWith(color: c.subtle)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: statCell('SFI', data.sfi?.toStringAsFixed(0) ?? '—', valueColor: sfiColor(data.sfi))),
              Container(width: 1, height: 30, color: c.border),
              const SizedBox(width: 10),
              Expanded(child: statCell('K',   data.kIndex?.toStringAsFixed(1) ?? '—', valueColor: kColor(data.kIndex))),
              Container(width: 1, height: 30, color: c.border),
              const SizedBox(width: 10),
              Expanded(child: statCell('A',   data.aIndex?.toStringAsFixed(0) ?? '—')),
              Container(width: 1, height: 30, color: c.border),
              const SizedBox(width: 10),
              Expanded(child: statCell('Sunspots', data.sunspots?.toString() ?? '—')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.border),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(compact ? '12-10m' : '11 m (12-10 m band)', style: t.bodySmall),
                _condPill(context, 'Day',   dayCond),
                _condPill(context, 'Night', nightCond),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _condPill(BuildContext context, String label, String cond) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    Color color;
    switch (cond.toLowerCase()) {
      case 'good':  color = c.success; break;
      case 'fair':  color = c.warning; break;
      case 'poor':
      case 'band closed': color = c.danger; break;
      default:      color = c.subtle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label:$cond',
          style: t.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
