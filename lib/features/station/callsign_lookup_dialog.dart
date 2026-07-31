import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import 'station_profile_sheet.dart';

/// Small centred dialog with an autocomplete callsign input. On submit
/// (Enter, or picking a suggestion) it closes and slides the full
/// [StationProfileSheet] in from the right — the sheet itself already
/// handles "worked before" vs "never heard" vs "in cache from PSK
/// Reporter" so this dialog only owns the input UX.
Future<void> showCallsignLookup(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, __, ___) => Center(child: _CallsignLookupCard()),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

class _CallsignLookupCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CallsignLookupCard> createState() =>
      _CallsignLookupCardState();
}

class _CallsignLookupCardState extends ConsumerState<_CallsignLookupCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final call = raw.trim().toUpperCase();
    if (call.isEmpty) return;
    Navigator.of(context).pop();
    showStationProfile(context, call);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    // Suggestions: every callsign we've already worked, so autocompletion
    // stays purely local (no PSK Reporter lookup while typing).
    final worked =
        ref.watch(workedCallsignsProvider).valueOrNull ?? const <String>{};

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 460,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.search, size: 16, color: c.subtle),
              const SizedBox(width: 6),
              Text('LOOK UP CALLSIGN', style: t.labelSmall),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: c.subtle),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (input) {
                final q = input.text.trim().toUpperCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return worked
                    .where((call) => call.startsWith(q))
                    .take(8);
              },
              fieldViewBuilder: (context, controller, focus, onFieldSubmit) {
                // Sync our external controller so onSubmitted works even
                // when the user hasn't picked a suggestion.
                if (controller.text != _controller.text) {
                  _controller.text = controller.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(16),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9/]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Callsign (e.g. 26AT211)',
                    prefixIcon: Icon(Icons.public, size: 16),
                  ),
                  onSubmitted: _submit,
                );
              },
              onSelected: _submit,
            ),
            const SizedBox(height: 8),
            Text(
              'Shows QSO history, last known grid, country and distance. '
              'Works for stations you\'ve never worked too — grid comes from '
              'the local cache and PSK Reporter.',
              style: t.bodySmall?.copyWith(color: c.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
