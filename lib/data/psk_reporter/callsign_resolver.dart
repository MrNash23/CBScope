import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/qso_repository.dart';
import 'psk_reporter_client.dart';

/// Resolves callsign → grid for CB (or any) callsigns.
///
/// Strategy:
///   1. Check the local cache (populated from every logged QSO and every
///      decode that carried its own grid).
///   2. If cache miss (or entry older than [staleAfter]) and PSK Reporter
///      lookups are enabled, queue an async fetch. Successful fetches update
///      the cache and notify listeners so map markers can appear.
class CallsignResolver extends ChangeNotifier {
  final QsoRepository repo;
  final PskReporterClient psk;
  final bool Function() pskEnabled;

  static const Duration staleAfter = Duration(days: 30);

  /// In-memory hot cache of confirmed grids by callsign.
  final Map<String, String> _hot = {};

  /// Calls we've already tried to fetch (successfully or not) — avoids
  /// re-querying every 5 s while the user watches the map.
  final Map<String, DateTime> _attempted = {};

  /// Serialized fetch queue so we don't hammer PSK Reporter.
  final Queue<String> _pending = Queue<String>();
  bool _pumping = false;

  CallsignResolver({
    required this.repo,
    required this.psk,
    required this.pskEnabled,
  });

  /// Synchronous best-effort lookup. Returns immediately with whatever we
  /// know now; if unknown, kicks off an async PSK Reporter fetch that will
  /// notify listeners when it completes.
  String? gridFor(String call, {String? seenGridHint}) {
    final key = call.toUpperCase();

    // If the decode itself carried a grid, learn it opportunistically.
    if (seenGridHint != null && seenGridHint.length >= 4) {
      final g = seenGridHint.toUpperCase();
      if (_hot[key] != g) {
        _hot[key] = g;
        // fire-and-forget persist
        repo.upsertCallsignGrid(key, g, 'decode');
      }
      return g;
    }

    final hot = _hot[key];
    if (hot != null) return hot;

    // Load from DB into the hot cache on first access, then optionally queue.
    unawaited(_ensureFromDb(key));
    if (pskEnabled() && _shouldTryPsk(key)) {
      _pending.add(key);
      unawaited(_pump());
    }
    return null;
  }

  bool _shouldTryPsk(String call) {
    final last = _attempted[call];
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(hours: 6);
  }

  Future<void> _ensureFromDb(String call) async {
    if (_hot.containsKey(call)) return;
    final row = await repo.lookupCallsignGrid(call);
    if (row != null && row.grid.length >= 4) {
      final fresh = DateTime.now().difference(row.updatedAt) < staleAfter;
      _hot[call] = row.grid;
      if (fresh) notifyListeners();
    }
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        final call = _pending.removeFirst();
        if (_hot.containsKey(call)) continue;
        _attempted[call] = DateTime.now();
        try {
          final rep = await psk.lookup(call);
          if (rep != null) {
            _hot[call] = rep.grid;
            await repo.upsertCallsignGrid(call, rep.grid, 'pskreporter');
            notifyListeners();
          }
        } on PskReporterRateLimited {
          // Requeue and wait out the window.
          _pending.addFirst(call);
          await Future<void>.delayed(const Duration(seconds: 65));
        } catch (e) {
          debugPrint('psk lookup $call failed: $e');
        }
      }
    } finally {
      _pumping = false;
    }
  }

  /// Bulk-warm the hot cache from the DB. Call once at startup.
  Future<void> warmFromDb(List<CallsignGrid> rows) async {
    for (final r in rows) {
      _hot[r.call.toUpperCase()] = r.grid.toUpperCase();
    }
    notifyListeners();
  }
}
