import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  // Route every framework / async error through print so it lands in stderr.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('PLATFORM ERROR: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails d) => Material(
        color: const Color(0xFFFFECEC),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text('${d.exceptionAsString()}\n\n${d.stack}',
                style: const TextStyle(color: Color(0xFFAA0000), fontSize: 12, fontFamily: 'Menlo')),
          ),
        ),
      );

  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1200, 780),
      minimumSize: Size(960, 620),
      title: 'CBScope',
      titleBarStyle: TitleBarStyle.hidden,
      // Match the app's dark surface so the OS-managed window is already
      // solid before Flutter's first paint — otherwise the launching-app
      // gap flashes whatever is behind (desktop, DMG background, etc.).
      backgroundColor: Color(0xFF04070A),
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: QsoBookApp()));
}
