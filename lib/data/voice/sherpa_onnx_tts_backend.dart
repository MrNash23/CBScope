import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'tts_service.dart';

/// TTS backend that shells out to a bundled `sherpa-onnx-offline-tts`
/// binary to render Piper VITS voice models into a WAV, then plays the
/// WAV through [audioplayers]. Enables identical Alan voice on macOS,
/// Linux, and Windows without any user setup.
///
/// Expects the runtime to be laid out under `<app-resources>/tts/`:
///
///   tts/
///     bin/sherpa-onnx-offline-tts     (executable per platform)
///     lib/                            (shared libs; DYLD/LD/PATH-injected)
///     voice/
///       en_GB-alan-medium.onnx
///       en_GB-alan-medium.onnx.json
///       tokens.txt
///       espeak-ng-data/
///
/// If the runtime is missing (e.g. a dev running `flutter run` without
/// first invoking `scripts/bundle_tts.sh`), each `speak` call becomes a
/// no-op with a single debug log so the pipeline stays working.
class SherpaOnnxTtsBackend implements TtsBackend {
  final _AudioPlayerSlot _slot = _AudioPlayerSlot();
  bool _warned = false;
  int _seq = 0;

  /// Locate the bundled `tts/` folder relative to the app executable.
  /// Returns null if it can't be found — caller degrades gracefully.
  String? _ttsRoot() {
    final exe = Platform.resolvedExecutable;
    final candidates = <String>[
      // macOS: /Applications/CBScope.app/Contents/MacOS/CBScope
      //   → ../Resources/tts
      p.normalize(p.join(p.dirname(exe), '..', 'Resources', 'tts')),
      // Linux/Windows: cbscope[.exe] with a peer tts/ folder
      p.join(p.dirname(exe), 'tts'),
      // Dev fallback: run from repo root, /tts/ at repo top
      p.join(Directory.current.path, 'third_party', 'sherpa-onnx',
          'macos', 'sherpa-onnx-v1.13.4-osx-universal2-shared', '_bundled'),
    ];
    for (final c in candidates) {
      if (Directory(p.join(c, 'voice')).existsSync()) return c;
    }
    return null;
  }

  @override
  Future<void> speak(String text) async {
    final root = _ttsRoot();
    if (root == null) {
      if (!_warned) {
        _warned = true;
        debugPrint(
            '[TTS] runtime not found — run scripts/bundle_tts.sh first');
      }
      return;
    }
    final binExt = Platform.isWindows ? '.exe' : '';
    final bin = p.join(root, 'bin', 'sherpa-onnx-offline-tts$binExt');
    final voice = p.join(root, 'voice', 'en_GB-alan-medium.onnx');
    final tokens = p.join(root, 'voice', 'tokens.txt');
    final espeak = p.join(root, 'voice', 'espeak-ng-data');
    if (!File(bin).existsSync() || !File(voice).existsSync()) {
      if (!_warned) {
        _warned = true;
        debugPrint('[TTS] runtime incomplete at $root');
      }
      return;
    }

    final tmp = await Directory.systemTemp.createTemp('cbscope-tts-');
    final wav = p.join(tmp.path, 'utter-${_seq++}.wav');
    try {
      final env = <String, String>{
        // Injects the bundled dylibs so the binary can dlopen them
        // without a user-installed onnxruntime.
        'DYLD_LIBRARY_PATH': p.join(root, 'lib'),
        'LD_LIBRARY_PATH': p.join(root, 'lib'),
      };
      final result = await Process.run(
        bin,
        [
          '--vits-model=$voice',
          '--vits-tokens=$tokens',
          '--vits-data-dir=$espeak',
          '--output-filename=$wav',
          text,
        ],
        environment: env,
        includeParentEnvironment: true,
      );
      if (result.exitCode != 0 || !File(wav).existsSync()) {
        debugPrint('[TTS] synth failed (${result.exitCode}): ${result.stderr}');
        return;
      }
      await _slot.playFile(wav);
    } finally {
      // Give the player a moment to open the file, then wipe the temp dir.
      // The audio buffer is already loaded so late deletion is safe.
      unawaited(Future<void>.delayed(const Duration(seconds: 30))
          .then((_) => tmp.delete(recursive: true).catchError((_) {
                return tmp;
              })));
    }
  }

  @override
  Future<void> stop() => _slot.stop();

  @override
  void dispose() {
    _slot.dispose();
  }
}

/// Single-slot audio player: awaits the previous file to finish before
/// starting the next, so utterances never overlap even if the pipeline's
/// serialisation guard has a race.
class _AudioPlayerSlot {
  final AudioPlayer _p = AudioPlayer();
  Completer<void>? _done;

  _AudioPlayerSlot() {
    _p.onPlayerComplete.listen((_) {
      _done?.complete();
      _done = null;
    });
  }

  Future<void> playFile(String path) async {
    await _p.stop();
    _done = Completer<void>();
    await _p.play(DeviceFileSource(path));
    // Cap at 60 s so a stuck player never wedges the announcement queue.
    await _done!.future.timeout(const Duration(seconds: 60), onTimeout: () {});
  }

  Future<void> stop() => _p.stop();

  void dispose() {
    _done?.complete();
    _p.dispose();
  }
}
