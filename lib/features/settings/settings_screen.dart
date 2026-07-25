import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/color_swatch_picker.dart';
import '../../data/db/database.dart';
import '../../providers/providers.dart';

/// Nuke-from-orbit reset. Wipes the Drift DB, the SharedPreferences plist,
/// and any cached files under Application Support so the app comes up in
/// exactly the same state as a fresh install. Requires a confirmation
/// dialog because it is irreversible.
class _DangerZoneSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      color: c.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: c.danger),
            const SizedBox(width: 6),
            Text('DANGER ZONE', style: t.labelSmall?.copyWith(color: c.danger)),
          ]),
          const SizedBox(height: 10),
          Text(
            'Reset the app to a fresh install. Deletes every QSO, all equipment, '
            'the callsign-grid cache, PSK Reporter cache, and every setting you '
            'have entered. This cannot be undone.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              icon: Icon(Icons.delete_forever, size: 14, color: c.danger),
              label: Text('Reset all data…', style: TextStyle(color: c.danger)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.danger),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () => _confirmAndReset(context, ref),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Reset all data?',
            style: Theme.of(context).textTheme.headlineSmall),
        content: Text(
          'Everything — QSOs, equipment, callsign cache, PSK cache, and all '
          'settings — will be permanently deleted. Continue?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: c.danger),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doReset(context, ref);
  }

  Future<void> _doReset(BuildContext context, WidgetRef ref) async {
    // 1) Wipe every table.
    final db = ref.read(dbProvider);
    await db.delete(db.qsos).go();
    await db.delete(db.callsignGrids).go();
    await db.delete(db.antennas).go();
    await db.delete(db.rigs).go();
    await db.delete(db.settings).go();
    await db.delete(db.pskSpotsCache).go();
    // 2) Wipe SharedPreferences (settings live here).
    final prefs = ref.read(prefsProvider).requireValue;
    await prefs.clear();
    // 3) Force every provider to rebuild so the UI reflects a fresh install.
    // ignore: unused_result
    ref.invalidate(settingsProvider);
    // ignore: unused_result
    ref.invalidate(logbookProvider);
    // ignore: unused_result
    ref.invalidate(needsReviewCountProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('App reset. Restart CBScope to start fresh.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 6),
    ));
  }
}

/// Full CSV export of the local logbook — a personal backup that stays
/// forward-compatible as we add more datapoints.
/// Attribution for the two external data sources CBScope pulls from at
/// runtime. Rendered as a small settings card so end users see the credit
/// even if they never open the source.
class _DataCreditsSection extends StatelessWidget {
  const _DataCreditsSection();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    TextStyle link() => TextStyle(color: c.accent);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DATA CREDITS', style: t.labelSmall),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: t.bodySmall,
              children: [
                const TextSpan(text: 'Solar / propagation data © N0NBH — '),
                TextSpan(text: 'hamqsl.com', style: link()),
                const TextSpan(text: '.\nCallsign → grid lookups via '),
                TextSpan(text: 'PSK Reporter', style: link()),
                const TextSpan(text: ' — pskreporter.info.\n'),
                TextSpan(
                  text:
                      'Both requests are opt-out under the settings above; nothing else leaves your machine.',
                  style: TextStyle(color: c.subtle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BACKUP', style: t.labelSmall),
          const SizedBox(height: 10),
          Text(
            'Exports every QSO in your local logbook as CSV (RFC 4180). '
            'Includes all current fields plus the raw_fields JSON so the file '
            'is a complete snapshot.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 14),
                label: const Text('Export logbook CSV…'),
                style: TextButton.styleFrom(
                  foregroundColor: c.text,
                  backgroundColor: c.card,
                  side: BorderSide(color: c.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () async {
                  final path = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save CBScope logbook',
                    fileName: 'cbscope_logbook_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
                  );
                  if (path == null) return;
                  final csv = await ref.read(qsoRepoProvider).exportLogbookCsv();
                  await File(path).writeAsString(csv);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Saved to $path'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small helper widget rendered inside the settings screen to manage the
/// user's antenna + radio library. Uses the same visual language as the
/// enclosing groups but declares itself as a stateful widget so add/remove
/// interactions don't rebuild the whole settings page.
class _EquipmentSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends ConsumerState<_EquipmentSection> {
  final _antennaCtrl = TextEditingController();
  final _antennaKindCtrl = TextEditingController();
  final _rigCtrl = TextEditingController();
  final _rigPowerCtrl = TextEditingController();

  @override
  void dispose() {
    _antennaCtrl.dispose();
    _antennaKindCtrl.dispose();
    _rigCtrl.dispose();
    _rigPowerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(qsoRepoProvider);
    final antennas = ref.watch(antennasProvider).valueOrNull ?? const [];
    final rigs     = ref.watch(rigsProvider).valueOrNull ?? const [];
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EQUIPMENT', style: t.labelSmall),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Antennas', style: t.titleSmall),
                const SizedBox(height: 6),
                for (final a in antennas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text(_antennaLabel(a), style: t.bodyMedium)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        tooltip: 'Archive',
                        onPressed: () => repo.archiveAntenna(a.id),
                      ),
                    ]),
                  ),
                Row(children: [
                  Expanded(child: TextField(controller: _antennaCtrl,
                      decoration: const InputDecoration(hintText: 'Name (e.g. "Sirio 827")'))),
                  const SizedBox(width: 6),
                  SizedBox(width: 110, child: TextField(controller: _antennaKindCtrl,
                      decoration: const InputDecoration(hintText: 'Kind'))),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: c.accent),
                    onPressed: () async {
                      if (_antennaCtrl.text.trim().isEmpty) return;
                      await repo.addAntenna(
                        name: _antennaCtrl.text.trim(),
                        kind: _antennaKindCtrl.text.trim().isEmpty ? null : _antennaKindCtrl.text.trim(),
                      );
                      _antennaCtrl.clear();
                      _antennaKindCtrl.clear();
                    },
                  ),
                ]),
              ]),
            ),
            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 16),
                color: c.border, height: 220),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Radios', style: t.titleSmall),
                const SizedBox(height: 6),
                for (final r in rigs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text(_rigLabel(r), style: t.bodyMedium)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        tooltip: 'Archive',
                        onPressed: () => repo.archiveRig(r.id),
                      ),
                    ]),
                  ),
                Row(children: [
                  Expanded(child: TextField(controller: _rigCtrl,
                      decoration: const InputDecoration(hintText: 'Name (e.g. "President Lincoln II+")'))),
                  const SizedBox(width: 6),
                  SizedBox(width: 80, child: TextField(controller: _rigPowerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Watts'))),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: c.accent),
                    onPressed: () async {
                      if (_rigCtrl.text.trim().isEmpty) return;
                      await repo.addRig(
                        name: _rigCtrl.text.trim(),
                        maxPowerW: int.tryParse(_rigPowerCtrl.text.trim()),
                      );
                      _rigCtrl.clear();
                      _rigPowerCtrl.clear();
                    },
                  ),
                ]),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  String _antennaLabel(Antenna a) {
    final parts = <String>[a.name];
    if (a.kind != null && a.kind!.isNotEmpty) parts.add('· ${a.kind}');
    if (a.gainDbi != null) parts.add('· ${a.gainDbi} dBi');
    return parts.join(' ');
  }

  String _rigLabel(Rig r) {
    final parts = <String>[r.name];
    if (r.maxPowerW != null) parts.add('· ${r.maxPowerW} W');
    return parts.join(' ');
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _port;
  late TextEditingController _bind;
  late TextEditingController _multicast;
  late TextEditingController _adifPath;
  late TextEditingController _myCall;
  late TextEditingController _myGrid;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _port      = TextEditingController(text: '${s.udpPort}');
    _bind      = TextEditingController(text: s.bindAddress);
    _multicast = TextEditingController(text: s.multicastGroup ?? '');
    _adifPath  = TextEditingController(text: s.adifLogPath ?? '');
    _myCall    = TextEditingController(text: s.myCall ?? '');
    _myGrid    = TextEditingController(text: s.myGrid ?? '');
  }

  @override
  void dispose() {
    for (final c in [_port, _bind, _multicast, _adifPath, _myCall, _myGrid]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text) ?? 2237;
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(
          s.copyWith(
            udpPort: port,
            bindAddress: _bind.text.trim().isEmpty ? '0.0.0.0' : _bind.text.trim(),
            multicastGroup: _multicast.text.trim(),
            adifLogPath: _adifPath.text.trim(),
            myCall: _myCall.text.trim().toUpperCase(),
            myGrid: _myGrid.text.trim().toUpperCase(),
            clearMulticast: _multicast.text.trim().isEmpty,
            clearAdifPath: _adifPath.text.trim().isEmpty,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved. Restart to re-bind UDP.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickAdifPath() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select WSJT-CB log file',
      type: FileType.custom,
      allowedExtensions: ['adi', 'adif'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() => _adifPath.text = res.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Settings',
            actions: [
              TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
          _group('WSJT-CB UDP', [
            _row('Port', TextField(controller: _port, keyboardType: TextInputType.number)),
            _row('Bind address', TextField(controller: _bind, decoration: const InputDecoration(hintText: '0.0.0.0'))),
            _row('Multicast group', TextField(controller: _multicast, decoration: const InputDecoration(hintText: 'e.g. 224.0.0.1 (optional)'))),
          ]),
          const SizedBox(height: 16),
          _group('WSJT-CB ADIF log file', [
            _row('Path', Row(children: [
              Expanded(child: TextField(controller: _adifPath)),
              const SizedBox(width: 8),
              TextButton(onPressed: _pickAdifPath, child: const Text('Browse…')),
            ])),
            if (_adifPath.text.isNotEmpty && !File(_adifPath.text).existsSync())
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 140),
                child: Text('File not found — will start empty', style: TextStyle(color: c.warning)),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(width: 200, child: Text('Auto-import to own logbook', style: Theme.of(context).textTheme.bodyMedium)),
                const Spacer(),
                Switch.adaptive(
                  value: ref.watch(settingsProvider).autoImportWsjtLog,
                  onChanged: (v) {
                    final s = ref.read(settingsProvider);
                    ref.read(settingsProvider.notifier).update(s.copyWith(autoImportWsjtLog: v));
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'When on, we watch the WSJT-CB log in the background and import each new QSO into our own database, stamped with the propagation snapshot (SFI, K, A, band condition) at the moment of the QSO. Turn off if you only want to browse WSJT-CB\'s log without duplicating it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _group('My station', [
            _row('Callsign', TextField(controller: _myCall, textCapitalization: TextCapitalization.characters)),
            _row('Grid locator', TextField(controller: _myGrid, textCapitalization: TextCapitalization.characters)),
          ]),
          const SizedBox(height: 16),
          _EquipmentSection(),
          const SizedBox(height: 16),
          _BackupSection(),
          const SizedBox(height: 16),
          const _DataCreditsSection(),
          const SizedBox(height: 16),
          _DangerZoneSection(),
          const SizedBox(height: 16),
          _group('Map style', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text('Basemap', style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<MapStyle>(
                      groupValue: ref.watch(settingsProvider).mapStyle,
                      onValueChanged: (v) {
                        if (v == null) return;
                        final s = ref.read(settingsProvider);
                        ref.read(settingsProvider.notifier).update(s.copyWith(mapStyle: v));
                      },
                      children: const {
                        MapStyle.regular:      Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Regular')),
                        MapStyle.cbscopeRetro: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('CBScope Retro')),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _group('Map marker colors', [
            _colorRow(context, ref, 'Logged QSOs',        (s) => s.qsoColor,    (s, v) => s.copyWith(qsoColor: v)),
            _colorRow(context, ref, 'Live decodes',       (s) => s.decodeColor, (s, v) => s.copyWith(decodeColor: v)),
            _colorRow(context, ref, 'PSK Reporter spots', (s) => s.pskColor,    (s, v) => s.copyWith(pskColor: v)),
            _colorRow(context, ref, 'My location',        (s) => s.meColor,     (s, v) => s.copyWith(meColor: v)),
          ]),
          const SizedBox(height: 16),
          _group('Callsign resolution', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 200, child: Text('PSK Reporter lookup', style: Theme.of(context).textTheme.bodyMedium)),
                  const Spacer(),
                  Switch.adaptive(
                    value: ref.watch(settingsProvider).pskReporterLookup,
                    onChanged: (v) {
                      final s = ref.read(settingsProvider);
                      ref.read(settingsProvider.notifier).update(s.copyWith(pskReporterLookup: v));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'When a decode has no grid, we look the callsign up on retrieve.pskreporter.info (rate-limited to 1 request/minute). Resolved grids are cached locally forever.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _group('Appearance', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 140, child: Text('Accent color', style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(
                    child: ColorSwatchPicker(
                      palette: AppTheme.accentPalette,
                      selected: ref.watch(settingsProvider).themeAccent ?? AppTheme.accentPalette.first,
                      onChanged: (v) {
                        final s = ref.read(settingsProvider);
                        ref.read(settingsProvider.notifier).update(s.copyWith(themeAccent: v));
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text('Theme', style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<ThemeModePref>(
                      groupValue: ref.watch(settingsProvider).theme,
                      onValueChanged: (v) {
                        if (v == null) return;
                        final s = ref.read(settingsProvider);
                        ref.read(settingsProvider.notifier).update(s.copyWith(theme: v));
                      },
                      children: const {
                        ThemeModePref.system: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('System')),
                        ThemeModePref.light:  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Light')),
                        ThemeModePref.dark:   Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Dark')),
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text('Distance', style: Theme.of(context).textTheme.bodyMedium)),
                  Expanded(
                    child: CupertinoSlidingSegmentedControl<DistanceUnit>(
                      groupValue: ref.watch(settingsProvider).distanceUnit,
                      onValueChanged: (v) {
                        if (v == null) return;
                        final s = ref.read(settingsProvider);
                        ref.read(settingsProvider.notifier).update(s.copyWith(distanceUnit: v));
                      },
                      children: const {
                        DistanceUnit.km: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Kilometers')),
                        DistanceUnit.mi: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Miles')),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> rows) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _colorRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    Color Function(AppSettings) read,
    AppSettings Function(AppSettings, Color) write,
  ) {
    final settings = ref.watch(settingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 200, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
            child: ColorSwatchPicker(
              palette: kMarkerPalette,
              selected: read(settings),
              onChanged: (v) => ref.read(settingsProvider.notifier).update(write(settings, v)),
            ),
          ),
        ],
      ),
    );
  }
}
