import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/db/database.dart';
import '../../providers/providers.dart';

/// New auto-imported QSOs land here first. User picks radio + antenna,
/// jots notes, gives a rating, and hits "Mark reviewed" to move it out of
/// the queue and into the main logbook flow.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(needsReviewProvider);
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Review',
            subtitle: 'New QSOs imported from WSJT-CB — approve after enriching with your radio, antenna, notes.',
          ),
          Expanded(
            child: pending.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all, color: c.success, size: 42),
                          const SizedBox(height: 10),
                          Text('Nothing to review', style: t.titleMedium),
                          const SizedBox(height: 4),
                          Text('New auto-imports will show up here.', style: t.bodySmall),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ReviewCard(qso: rows[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Text('$e', style: t.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  final Qso qso;
  const _ReviewCard({required this.qso});
  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  late int? _antennaId = widget.qso.antennaId;
  late int? _rigId     = widget.qso.radioId;
  late int  _rating    = widget.qso.rating;
  late final _notesCtrl = TextEditingController(text: widget.qso.personalNotes ?? '');

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool markReviewed}) async {
    final repo = ref.read(qsoRepoProvider);
    await repo.updateEnrichment(
      widget.qso.id,
      antennaId: _antennaId,
      radioId: _rigId,
      personalNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      rating: _rating,
      markReviewed: markReviewed,
      clearAntenna: _antennaId == null,
      clearRadio:   _rigId == null,
    );
    if (!mounted) return;
    if (markReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Marked ${widget.qso.call} reviewed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.qso;
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final df = DateFormat('yyyy-MM-dd HH:mm \'UTC\'');
    final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
    final rigs     = ref.watch(rigsProvider).valueOrNull ?? const [];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(q.call, style: t.headlineSmall?.copyWith(color: c.accent)),
              const SizedBox(width: 10),
              _chip(context, q.mode.toUpperCase()),
              const SizedBox(width: 4),
              if (q.freqMhz != null) _chip(context, '${q.freqMhz!.toStringAsFixed(3)} MHz'),
              const Spacer(),
              Text(df.format(q.timeOn.toUtc()),
                  style: t.bodySmall?.copyWith(color: c.subtle)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12, runSpacing: 4,
            children: [
              if (q.gridsquare != null) _kv(context, 'Grid', q.gridsquare!),
              _kv(context, 'RST S/R', '${q.rstSent ?? '-'} / ${q.rstRcvd ?? '-'}'),
              if (q.name != null && q.name!.isNotEmpty) _kv(context, 'Name', q.name!),
              if (q.country != null && q.country!.isNotEmpty) _kv(context, 'Country', q.country!),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _dropdown<int?>(
                  label: 'Radio',
                  value: _rigId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    for (final r in rigs)
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _rigId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown<int?>(
                  label: 'Antenna',
                  value: _antennaId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— none —')),
                    for (final a in antennas)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _antennaId = v),
                ),
              ),
              const SizedBox(width: 10),
              _StarRating(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Personal notes about this QSO…',
              prefixIcon: Icon(Icons.notes, size: 14),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _save(markReviewed: false),
                icon: const Icon(Icons.save_outlined, size: 14),
                label: const Text('Save draft'),
                style: TextButton.styleFrom(
                  foregroundColor: c.text,
                  backgroundColor: c.card,
                  side: BorderSide(color: c.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const Spacer(),
              if (antennas.isEmpty || rigs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('Add radios/antennas in Settings first.',
                      style: t.bodySmall?.copyWith(color: c.warning)),
                ),
              FilledButton.icon(
                onPressed: () => _save(markReviewed: true),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Mark reviewed'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: c.card, border: Border.all(color: c.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              isDense: true,
              dropdownColor: c.card,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$k: ', style: t.bodySmall?.copyWith(color: c.subtle)),
      Text(v, style: t.bodySmall),
    ]);
  }

  Widget _chip(BuildContext context, String s) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border)),
      child: Text(s, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StarRating({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RATING', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => onChanged(i == value ? 0 : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                child: Icon(
                  i <= value ? Icons.star : Icons.star_border,
                  size: 18,
                  color: i <= value ? c.warning : c.subtle,
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
