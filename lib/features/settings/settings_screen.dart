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
import '../../data/voice/voice_pipeline.dart';
import '../../providers/providers.dart';

/// Reusable collapsible card for the settings page. Header shows the
/// title + optional icon + chevron; body appears/disappears on tap. Keeps
/// the visual language of the old inline sections but lets heavy panels
/// (Voice, Equipment) stay tucked away until needed.
class _CollapsibleGroup extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final bool initiallyOpen;
  final Color? titleColor;

  const _CollapsibleGroup({
    required this.title,
    this.icon,
    required this.child,
    this.initiallyOpen = false,
    this.titleColor,
  });

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon,
                        size: 14, color: widget.titleColor ?? c.subtle),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: t.labelSmall?.copyWith(color: widget.titleColor),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(Icons.expand_more, size: 18, color: c.subtle),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Nuke-from-orbit reset. Wipes the Drift DB, the SharedPreferences plist,
/// and any cached files under Application Support so the app comes up in
/// exactly the same state as a fresh install. Requires a confirmation
/// dialog because it is irreversible.
class _DangerZoneSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
/// Voice announcements panel. Master switch collapses/reveals the per-event
/// grid + rate limit + quiet hours. Events are grouped exactly like the
/// design catalogue (Discovery / My QSO / Milestones / Propagation / System).
class _VoiceSection extends ConsumerWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final settings = ref.watch(settingsProvider);

    void toggleEvent(VoiceEvent e, bool on) {
      final next = {...settings.voiceEvents};
      if (on) {
        next.add(e);
      } else {
        next.remove(e);
      }
      ref.read(settingsProvider.notifier).update(
            settings.copyWith(voiceEvents: next),
          );
    }

    // Group the events for section rendering. Order of insertion determines
    // display order; the enum itself is grouped in declaration order.
    final grouped = <String, List<VoiceEvent>>{};
    for (final e in VoiceEvent.values) {
      grouped.putIfAbsent(e.groupLabel, () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                settings.voiceEnabled
                    ? 'Voice announcements are on. Configure below.'
                    : 'Turn on to have selected events read out loud.',
                style: t.bodySmall?.copyWith(color: c.subtle),
              ),
            ),
            Switch.adaptive(
              value: settings.voiceEnabled,
              onChanged: (v) {
                // First-ever enable: seed with the low-noise default set
                // so the user doesn't have to hunt through every toggle.
                final events = (v && settings.voiceEvents.isEmpty)
                    ? AppSettings.defaultOnEvents
                    : settings.voiceEvents;
                ref.read(settingsProvider.notifier).update(
                      settings.copyWith(
                        voiceEnabled: v,
                        voiceEvents: events,
                      ),
                    );
              },
            ),
          ],
        ),
        if (settings.voiceEnabled) ...[
          const SizedBox(height: 10),
          _TestVoiceButton(),
          const SizedBox(height: 10),
          _VoiceVolumeSlider(),
          const SizedBox(height: 14),
          for (final entry in grouped.entries) ...[
            Text(entry.key.toUpperCase(), style: t.labelSmall),
            const SizedBox(height: 4),
            for (final e in entry.value)
              _eventRow(context, e, settings, toggleEvent),
            const SizedBox(height: 10),
          ],
          _thresholdRow(
            context,
            label: 'Long-distance threshold',
            value: settings.voiceNotableDxKm,
            suffix: 'km',
            min: 1000,
            max: 15000,
            divisions: 28,
            onChanged: (v) => ref.read(settingsProvider.notifier).update(
                  settings.copyWith(voiceNotableDxKm: v),
                ),
          ),
          _thresholdRow(
            context,
            label: 'Strong-signal threshold',
            value: settings.voiceStrongSignalDb,
            suffix: 'dB',
            min: -10,
            max: 10,
            divisions: 20,
            onChanged: (v) => ref.read(settingsProvider.notifier).update(
                  settings.copyWith(voiceStrongSignalDb: v),
                ),
          ),
          _thresholdRow(
            context,
            label: 'Solar-flux threshold',
            value: settings.voiceSolarFluxSfi,
            suffix: 'SFI',
            min: 70,
            max: 300,
            divisions: 46,
            onChanged: (v) => ref.read(settingsProvider.notifier).update(
                  settings.copyWith(voiceSolarFluxSfi: v),
                ),
          ),
          const SizedBox(height: 8),
          _thresholdRow(
            context,
            label: 'Max announcements / min',
            value: settings.voiceRateLimitPerMinute,
            suffix: '/min',
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) => ref.read(settingsProvider.notifier).update(
                  settings.copyWith(voiceRateLimitPerMinute: v),
                ),
          ),
          const SizedBox(height: 8),
          _quietHoursRow(context, ref, settings),
        ],
      ],
    );
  }

  Widget _eventRow(BuildContext context, VoiceEvent e, AppSettings settings,
      void Function(VoiceEvent, bool) toggle) {
    final t = Theme.of(context).textTheme;
    final on = settings.voiceEvents.contains(e);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(e.label, style: t.bodyMedium)),
          Switch.adaptive(
            value: on,
            onChanged: (v) => toggle(e, v),
          ),
        ],
      ),
    );
  }

  Widget _thresholdRow(
    BuildContext context, {
    required String label,
    required int value,
    required String suffix,
    required int min,
    required int max,
    required int divisions,
    required ValueChanged<int> onChanged,
  }) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text(label, style: t.bodyMedium)),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: divisions,
              label: '$value $suffix',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('$value $suffix',
                style: t.bodySmall, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _quietHoursRow(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final enabled = settings.voiceQuietStartMin != null &&
        settings.voiceQuietEndMin != null;
    String fmt(int mins) =>
        '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text('Quiet hours (UTC)', style: t.bodyMedium),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).update(
                    v
                        ? settings.copyWith(
                            voiceQuietStartMin: 22 * 60,
                            voiceQuietEndMin: 7 * 60,
                          )
                        : settings.copyWith(clearVoiceQuiet: true),
                  );
            },
          ),
          const SizedBox(width: 8),
          if (enabled) ...[
            Text('${fmt(settings.voiceQuietStartMin!)} → '
                '${fmt(settings.voiceQuietEndMin!)}',
                style: t.bodySmall?.copyWith(fontFamily: 'Menlo')),
            const SizedBox(width: 6),
            Text('(tap switch to disable)',
                style: t.labelSmall?.copyWith(color: c.subtle)),
          ] else
            Text('off', style: t.bodySmall?.copyWith(color: c.subtle)),
        ],
      ),
    );
  }
}

/// User-triggerable pipeline probe. Fires a test announcement through the
/// real [VoiceAnnouncer] (bypassing rate-limit + quiet-hours) so the user
/// can confirm everything is wired up. Snackbar reports back whether the
/// currently-active backend produces audio or only writes to the console.
class _TestVoiceButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.play_arrow, size: 15),
          label: const Text('Test voice'),
          style: TextButton.styleFrom(
            foregroundColor: c.text,
            backgroundColor: c.card,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () {
            final settings = ref.read(settingsProvider);
            final announcer = ref.read(voiceAnnouncerProvider);
            final messenger = ScaffoldMessenger.of(context);
            if (!settings.voiceEnabled) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Voice is off — turn on the master switch first.'),
                behavior: SnackBarBehavior.floating,
              ));
              return;
            }
            announcer.sayTest(
              'Test announcement. C-B-Scope voice pipeline standing by.',
            );
            messenger.showSnackBar(const SnackBar(
              content: Text('Voice test triggered.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ));
          },
        ),
      ],
    );
  }
}

/// Volume slider with drag-to-preview behaviour: value updates on every
/// tick so the backend applies it live (audible if an utterance is already
/// playing); on release we auto-fire a short test phrase so the user can
/// iterate — drag, listen, drag again.
class _VoiceVolumeSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final v = settings.voiceVolume;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            v < 0.02
                ? Icons.volume_off
                : v < 0.4
                    ? Icons.volume_down
                    : Icons.volume_up,
            size: 16,
            color: c.subtle,
          ),
          const SizedBox(width: 6),
          SizedBox(width: 60, child: Text('Volume', style: t.bodyMedium)),
          Expanded(
            child: Slider(
              value: v.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(v * 100).round()}%',
              onChanged: (nv) {
                ref
                    .read(settingsProvider.notifier)
                    .update(settings.copyWith(voiceVolume: nv));
              },
              onChangeEnd: (nv) {
                // Play a short probe at the new volume once the user
                // lets go, so they always hear the effect immediately.
                ref.read(voiceAnnouncerProvider).sayTest('Volume check.');
              },
            ),
          ),
          SizedBox(
            width: 42,
            child: Text('${(v * 100).round()}%',
                style: t.bodySmall, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

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
    return Text.rich(
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
    );
  }
}

class _BackupSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]);
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
          // ---------- Setup / connection ----------
          _group('My station', [
            _row('Callsign', TextField(controller: _myCall, textCapitalization: TextCapitalization.characters)),
            _row('Grid locator', TextField(controller: _myGrid, textCapitalization: TextCapitalization.characters)),
          ], initiallyOpen: true, icon: Icons.person_outline),
          const SizedBox(height: 12),
          _group('WSJT-CB UDP', [
            _row('Port', TextField(controller: _port, keyboardType: TextInputType.number)),
            _row('Bind address', TextField(controller: _bind, decoration: const InputDecoration(hintText: '0.0.0.0'))),
            _row('Multicast group', TextField(controller: _multicast, decoration: const InputDecoration(hintText: 'e.g. 224.0.0.1 (optional)'))),
          ], initiallyOpen: true, icon: Icons.cable),
          const SizedBox(height: 12),
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
          ], initiallyOpen: true, icon: Icons.description_outlined),
          const SizedBox(height: 12),
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
          ], icon: Icons.search),
          const SizedBox(height: 12),

          // ---------- Inventory ----------
          _CollapsibleGroup(
            title: 'Equipment',
            icon: Icons.settings_input_antenna,
            child: _EquipmentSection(),
          ),
          const SizedBox(height: 12),

          // ---------- Alerts ----------
          _CollapsibleGroup(
            title: 'Voice announcements',
            icon: Icons.record_voice_over_outlined,
            child: const _VoiceSection(),
          ),
          const SizedBox(height: 12),

          // ---------- Appearance ----------
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
          ], icon: Icons.palette_outlined),
          const SizedBox(height: 12),

          // ---------- Map look-and-feel ----------
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
          ], icon: Icons.map_outlined),
          const SizedBox(height: 12),
          _group('Map marker colors', [
            _colorRow(context, ref, 'Logged QSOs',        (s) => s.qsoColor,    (s, v) => s.copyWith(qsoColor: v)),
            _colorRow(context, ref, 'Live decodes',       (s) => s.decodeColor, (s, v) => s.copyWith(decodeColor: v)),
            _colorRow(context, ref, 'PSK Reporter spots', (s) => s.pskColor,    (s, v) => s.copyWith(pskColor: v)),
            _colorRow(context, ref, 'My location',        (s) => s.meColor,     (s, v) => s.copyWith(meColor: v)),
          ], icon: Icons.pin_drop_outlined),
          const SizedBox(height: 12),

          // ---------- Data & maintenance ----------
          _CollapsibleGroup(
            title: 'Backup',
            icon: Icons.file_download_outlined,
            child: _BackupSection(),
          ),
          const SizedBox(height: 12),
          const _CollapsibleGroup(
            title: 'Data credits',
            icon: Icons.info_outline,
            child: _DataCreditsSection(),
          ),
          const SizedBox(height: 12),
          _CollapsibleGroup(
            title: 'Danger zone',
            icon: Icons.warning_amber_rounded,
            titleColor: c.danger,
            child: _DangerZoneSection(),
          ),
        ],
      ),
    );
  }

  Widget _group(
    String title,
    List<Widget> rows, {
    bool initiallyOpen = false,
    IconData? icon,
  }) {
    return _CollapsibleGroup(
      title: title,
      icon: icon,
      initiallyOpen: initiallyOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
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
