import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/sidebar.dart';
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
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CBScope',
          themeMode: switch (theme) {
            ThemeModePref.system => ThemeMode.system,
            ThemeModePref.light  => ThemeMode.light,
            ThemeModePref.dark   => ThemeMode.dark,
          },
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const _Shell(),
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator.adaptive())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Failed to load prefs: $e'))),
      ),
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
    // instant instead of a 15 s cold start.
    ref.watch(qsoLoggedIngestProvider);
    ref.watch(adifTailProvider);
    ref.watch(udpListenerProvider);
    ref.watch(pskSpotsProvider);

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
