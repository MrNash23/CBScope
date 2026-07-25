import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/sidebar.dart';
import 'data/voice/voice_pipeline.dart';
import 'features/live/live_screen.dart';
import 'features/logbook/logbook_screen.dart';
import 'features/map/map_screen.dart';
import 'features/review/review_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'providers/providers.dart';

class QsoBookApp extends ConsumerWidget {
  const QsoBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return prefs.when(
      data: (_) {
        final theme = ref.watch(settingsProvider).theme;
        final accent = ref.watch(settingsProvider).themeAccent;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CBScope',
          themeMode: switch (theme) {
            ThemeModePref.system => ThemeMode.system,
            ThemeModePref.light  => ThemeMode.light,
            ThemeModePref.dark   => ThemeMode.dark,
          },
          theme: AppTheme.light(accent: accent),
          darkTheme: AppTheme.dark(accent: accent),
          home: const _SplashGate(child: _Shell()),
        );
      },
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashScreen(),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Failed to load prefs: $e'))),
      ),
    );
  }
}

/// Full-screen branded splash. Solid dark background matches the
/// pre-Flutter window colour so there's no seam at handover.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF04070A);
    const accent = Color(0xFF00E5FF);
    return const ColoredBox(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CBScope',
              style: TextStyle(
                color: accent,
                fontSize: 40,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
                fontFamily: 'Menlo',
              ),
            ),
            SizedBox(height: 10),
            Text(
              '11 m CB · WSJT companion',
              style: TextStyle(
                color: Color(0xFF6EA0B8),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the splash on top for at least [minDuration] after prefs load,
/// covering the initial provider warm-up and first layout pass so the
/// user never sees the raw skeleton flash by.
class _SplashGate extends StatefulWidget {
  final Widget child;
  final Duration minDuration;
  const _SplashGate({
    required this.child,
    this.minDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.minDuration, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Child is built (and warms up its providers) behind the splash so
        // by the time we fade the splash away, the shell is already laid
        // out — no second flash.
        widget.child,
        AnimatedOpacity(
          opacity: _showSplash ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_showSplash,
            child: const _SplashScreen(),
          ),
        ),
      ],
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _index = 0;

  // (Badge for Review is injected at build time from needsReviewCountProvider.)

  @override
  Widget build(BuildContext context) {
    // Kick off UDP + ADIF ingestion side-effects, plus keep PSK Reporter
    // polling alive even when the map isn't visible so switching to it is
    // instant instead of a 15 s cold start. Voice pipeline mounts every
    // announcement listener so events reach the TTS backend from any tab.
    ref.watch(qsoLoggedIngestProvider);
    ref.watch(adifTailProvider);
    ref.watch(udpListenerProvider);
    ref.watch(pskSpotsProvider);
    ref.watch(voicePipelineProvider);

    Widget body;
    switch (_index) {
      case 0: body = const LiveScreen(); break;
      case 1: body = const ReviewScreen(); break;
      case 2: body = const LogbookScreen(); break;
      case 3: body = const StatsScreen(); break;
      case 4: body = const MapScreen(); break;
      case 5: body = const SettingsScreen(); break;
      default: body = const LiveScreen();
    }

    final reviewCount = ref.watch(needsReviewCountProvider).valueOrNull ?? 0;
    final items = [
      const SidebarItem('Live', Icons.podcasts),
      SidebarItem('Review', Icons.rate_review_outlined, badge: reviewCount),
      const SidebarItem('Logbook', Icons.menu_book_outlined),
      const SidebarItem('Stats', Icons.query_stats),
      const SidebarItem('Map', Icons.public),
      const SidebarItem('Settings', Icons.tune),
    ];

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _index,
            onSelect: (i) => setState(() => _index = i),
            items: items,
            footer: Text(
              'v0.1.0',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
