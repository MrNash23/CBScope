import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/propagation_card.dart';
import '../../providers/providers.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Force rebuild once per second for the "since heartbeat" clock.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(wsjtxStatusProvider);
    final decodes = ref.watch(liveDecodesProvider);
    final udp = ref.watch(udpListenerProvider);
    final last = udp.lastPacketAt;
    final connected = last != null && DateTime.now().difference(last).inSeconds < 20;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Live',
            subtitle: 'Streaming from WSJT-CB on UDP ${ref.read(settingsProvider).udpPort}',
            actions: [StatusDot(connected: connected, label: connected ? 'Connected' : 'Waiting')],
          ),
          _statusCard(status),
          const SizedBox(height: 12),
          const PropagationCard(),
          const SizedBox(height: 12),
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: _decodeList(decodes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(status) {
    // Wraps so the columns stack on narrow layouts instead of overflowing.
    return AppCard(
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          _stat('Band / Mode', status == null ? '—' : '${_formatFreq(status.dialFrequency)}  ·  ${status.mode}'),
          _stat('DX Call', status?.dxCall ?? '—'),
          _stat('DX Grid', status?.dxGrid ?? '—'),
          _stat('Report', status?.report ?? '—'),
          _stat('Δf Rx/Tx', status == null ? '—' : '${status.rxDf ?? '-'}/${status.txDf ?? '-'} Hz'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: t.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: t.titleMedium, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _decodeList(List<LiveDecode> decodes) {
    final c = context.colors;
    if (decodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_input_antenna, color: c.subtle, size: 34),
              const SizedBox(height: 10),
              Text('Waiting for decodes…', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Make sure WSJT-CB UDP Server is on ${ref.read(settingsProvider).bindAddress}:${ref.read(settingsProvider).udpPort}.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            _h('UTC', 80),
            _h('SNR', 55),
            _h('DT', 55),
            _h('Δf', 60),
            _h('Mode', 60),
            const Expanded(child: SizedBox()),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: decodes.length,
            itemBuilder: (context, i) {
              final d = decodes[i].decode;
              final utcSecs = (d.timeMs / 1000).floor();
              final h = (utcSecs ~/ 3600) % 24;
              final m = (utcSecs ~/ 60) % 60;
              final s = utcSecs % 60;
              final time = '${_p2(h)}:${_p2(m)}:${_p2(s)}';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border.withOpacity(0.5))),
                ),
                child: Row(
                  children: [
                    _v(time, 80, mono: true),
                    _v(_signed(d.snr), 55, mono: true, color: _snrColor(context, d.snr)),
                    _v(d.deltaTime.toStringAsFixed(1), 55, mono: true),
                    _v(d.deltaFreq.toString(), 60, mono: true),
                    _v(d.mode, 60),
                    Expanded(child: Text(d.message, style: const TextStyle(fontFamily: 'Menlo'))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _snrColor(BuildContext context, int snr) {
    final c = context.colors;
    if (snr >= 0) return c.success;
    if (snr >= -15) return c.text;
    return c.subtle;
  }

  String _signed(int n) => n >= 0 ? '+$n' : '$n';
  String _p2(int n) => n.toString().padLeft(2, '0');
  String _formatFreq(int hz) {
    final mhz = hz / 1e6;
    return '${mhz.toStringAsFixed(3)} MHz';
  }

  Widget _h(String s, double w) => SizedBox(
        width: w,
        child: Text(s.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
      );

  Widget _v(String s, double w, {bool mono = false, Color? color}) => SizedBox(
        width: w,
        child: Text(
          s,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? 'Menlo' : null,
                color: color,
              ),
        ),
      );
}
