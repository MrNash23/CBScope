import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:watcher/watcher.dart';

import 'adif_parser.dart';

class AdifTailEvent {
  final List<AdifRecord> records;
  final int newOffset;
  const AdifTailEvent(this.records, this.newOffset);
}

/// Watches an ADIF file and emits newly appended records as they arrive.
///
/// Tracks a byte offset internally so restarts can resume mid-file. On file
/// truncation, resets and re-emits from the start.
class AdifTailWatcher {
  final String path;
  int _offset;
  String _leftover = '';
  StreamSubscription? _sub;
  final _controller = StreamController<AdifTailEvent>.broadcast();

  AdifTailWatcher(this.path, {int startOffset = 0}) : _offset = startOffset;

  Stream<AdifTailEvent> get events => _controller.stream;
  int get offset => _offset;

  Future<void> start() async {
    await stop();
    // Read anything already past the offset before subscribing to changes.
    await _readNew();
    final watcher = FileWatcher(path);
    _sub = watcher.events.listen((e) async {
      if (e.type == ChangeType.MODIFY) {
        await _readNew();
      } else if (e.type == ChangeType.REMOVE) {
        _offset = 0;
        _leftover = '';
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _readNew() async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final len = await file.length();
      if (len < _offset) {
        _offset = 0;
        _leftover = '';
      }
      if (len == _offset) return;
      final raf = await file.open();
      try {
        await raf.setPosition(_offset);
        final bytes = await raf.read(len - _offset);
        final text = _leftover + utf8.decode(bytes, allowMalformed: true);
        final parsed = AdifParser.parseStreaming(text);
        _leftover = text.substring(parsed.consumed);
        _offset = len - utf8.encode(_leftover).length;
        _controller.add(AdifTailEvent(parsed.records, _offset));
      } finally {
        await raf.close();
      }
    } catch (e) {
      // Missing file / permission denied / decode error — surface once, then move on.
      // ignore: avoid_print
      print('adif tail: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
