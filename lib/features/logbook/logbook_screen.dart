import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart' show DropTarget;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/adif/adif_parser.dart';
import '../../data/db/database.dart';
import '../../data/db/qso_repository.dart';
import '../../providers/providers.dart';
import '../station/station_profile_sheet.dart';

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  bool _dragging = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _importFiles(List<String> paths) async {
    final importer = ref.read(adifImportProvider);
    int total = 0;
    for (final p in paths) {
      total += await importer(p);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported $total new QSO(s)'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickAndImport() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['adi', 'adif', 'adx'],
    );
    if (res != null) {
      await _importFiles(res.files.where((f) => f.path != null).map((f) => f.path!).toList());
    }
  }

  Future<void> _exportAdif() async {
    final qsos = await ref.read(qsoRepoProvider).all();
    final path = await FilePicker.platform.saveFile(
      fileName: 'cbscope_export.adi',
      dialogTitle: 'Export ADIF',
    );
    if (path == null) return;
    final text = buildAdifExport(qsos.map((q) => {
          'call': q.call,
          'qso_date': DateFormat('yyyyMMdd').format(q.timeOn.toUtc()),
          'time_on': DateFormat('HHmmss').format(q.timeOn.toUtc()),
          if (q.timeOff != null) 'time_off': DateFormat('HHmmss').format(q.timeOff!.toUtc()),
          'band': q.band,
          'mode': q.mode,
          if (q.freqMhz != null) 'freq': q.freqMhz!.toStringAsFixed(6),
          if (q.rstSent != null) 'rst_sent': q.rstSent!,
          if (q.rstRcvd != null) 'rst_rcvd': q.rstRcvd!,
          if (q.gridsquare != null) 'gridsquare': q.gridsquare!,
          if (q.myCall != null) 'station_callsign': q.myCall!,
          if (q.myGrid != null) 'my_gridsquare': q.myGrid!,
          if (q.name != null) 'name': q.name!,
          if (q.country != null) 'country': q.country!,
          if (q.comment != null) 'comment': q.comment!,
        }));
    await File(path).writeAsString(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported ${qsos.length} QSO(s)'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(logbookProvider);
    final c = context.colors;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        await _importFiles(detail.files.map((f) => f.path).toList());
      },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Logbook',
                  subtitle: 'Drag an ADI file anywhere on this pane to import.',
                  actions: [
                    _iconTextButton(Icons.file_download_outlined, 'Import', _pickAndImport),
                    const SizedBox(width: 8),
                    _iconTextButton(Icons.file_upload_outlined, 'Export', _exportAdif),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search by callsign…',
                          prefixIcon: Icon(Icons.search, size: 16),
                        ),
                        onChanged: (v) {
                          final f = ref.read(logbookFilterProvider);
                          ref.read(logbookFilterProvider.notifier).state = (
                            search: v.isEmpty ? null : v,
                            band: f.band, mode: f.mode,
                            antennaId: f.antennaId, radioId: f.radioId,
                            minRating: f.minRating, reviewState: f.reviewState,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _LogbookFilterChips(),
                const SizedBox(height: 12),
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: async.when(
                      data: (rows) => rows.isEmpty
                          ? _emptyState(context)
                          : _table(rows),
                      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                      error: (e, _) => Center(child: Text('$e')),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: c.accent.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, color: c.accent),
                        const SizedBox(width: 10),
                        Text('Drop to import ADIF',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: c.subtle),
            const SizedBox(height: 12),
            Text('No QSOs yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Import an ADI file or connect WSJT-X.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _table(List<Qso> rows) {
    final c = context.colors;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            children: [
              _h('When', 150),
              _h('Call', 110),
              _h('Band', 70),
              _h('Mode', 70),
              _h('RST S/R', 100),
              _h('Grid', 90),
              _h('Freq', 90),
              _h('Comment', 260),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final q = rows[i];
              return InkWell(
                onTap: () => showStationProfile(context, q.call),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border.withOpacity(0.6))),
                ),
                child: Row(
                  children: [
                    _v(df.format(q.timeOn.toUtc()), 150, mono: true),
                    _v(q.call, 110, bold: true),
                    _v(q.band, 70),
                    _v(q.mode, 70),
                    _v('${q.rstSent ?? '-'} / ${q.rstRcvd ?? '-'}', 100, mono: true),
                    _v(q.gridsquare ?? '-', 90, mono: true),
                    _v(q.freqMhz?.toStringAsFixed(3) ?? '-', 90, mono: true),
                    _v(q.comment ?? '', 260),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _h(String s, double w) => SizedBox(
        width: w,
        child: Text(s.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
      );

  Widget _v(String s, double w, {bool bold = false, bool mono = false}) => SizedBox(
        width: w,
        child: Text(
          s,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w600 : null,
                fontFamily: mono ? 'Menlo' : null,
              ),
        ),
      );

  Widget _iconTextButton(IconData icon, String label, VoidCallback onTap) {
    final c = context.colors;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: c.text),
      label: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      style: TextButton.styleFrom(
        backgroundColor: c.card,
        foregroundColor: c.text,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }
}

/// Compact horizontal filter strip shown above the logbook table. Chips
/// mutate the shared [logbookFilterProvider] so any change is also
/// reflected on the Map screen (which reads the same slice).
class _LogbookFilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(logbookFilterProvider);
    final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
    final rigs     = ref.watch(rigsProvider).valueOrNull ?? const [];
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    void update({
      int? antennaId, int? radioId, int? minRating, ReviewState? reviewState,
      bool clearAntenna = false, bool clearRadio = false, bool clearMinRating = false, bool clearReview = false,
    }) {
      ref.read(logbookFilterProvider.notifier).state = (
        search: f.search, band: f.band, mode: f.mode,
        antennaId: clearAntenna ? null : (antennaId ?? f.antennaId),
        radioId:   clearRadio   ? null : (radioId   ?? f.radioId),
        minRating: clearMinRating ? null : (minRating ?? f.minRating),
        reviewState: clearReview ? null : (reviewState ?? f.reviewState),
      );
    }

    Widget chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? c.accent.withOpacity(0.14) : c.card,
              border: Border.all(color: selected ? c.accent : c.border),
            ),
            child: Text(label, style: t.bodySmall?.copyWith(
              color: selected ? c.accent : c.text,
              fontWeight: selected ? FontWeight.w700 : null,
            )),
          ),
        );

    final rState = f.reviewState ?? ReviewState.any;
    return Wrap(
      spacing: 6, runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Review:', style: t.labelSmall),
        chip('All',        rState == ReviewState.any,        () => update(clearReview: true)),
        chip('Reviewed',   rState == ReviewState.reviewed,   () => update(reviewState: ReviewState.reviewed)),
        chip('Unreviewed', rState == ReviewState.unreviewed, () => update(reviewState: ReviewState.unreviewed)),
        const SizedBox(width: 8),
        Text('Rating ≥', style: t.labelSmall),
        chip('Any', f.minRating == null || f.minRating == 0, () => update(clearMinRating: true)),
        for (int r = 1; r <= 5; r++)
          chip('★' * r, f.minRating == r, () => update(minRating: r)),
        if (rigs.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text('Radio:', style: t.labelSmall),
          chip('Any', f.radioId == null, () => update(clearRadio: true)),
          for (final r in rigs)
            chip(r.name, f.radioId == r.id, () => update(radioId: r.id)),
        ],
        if (antennas.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text('Antenna:', style: t.labelSmall),
          chip('Any', f.antennaId == null, () => update(clearAntenna: true)),
          for (final a in antennas)
            chip(a.name, f.antennaId == a.id, () => update(antennaId: a.id)),
        ],
      ],
    );
  }
}
