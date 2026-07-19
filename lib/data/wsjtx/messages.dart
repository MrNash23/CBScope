// WSJT-X UDP message DTOs.
// Ref: https://sourceforge.net/p/wsjt/wsjtx/ci/master/tree/Network/NetworkMessage.hpp

sealed class WsjtxMessage {
  final String id;
  const WsjtxMessage({required this.id});
}

class WsjtxHeartbeat extends WsjtxMessage {
  final int maxSchema;
  final String version;
  final String revision;
  const WsjtxHeartbeat(
      {required super.id,
      required this.maxSchema,
      required this.version,
      required this.revision});
}

class WsjtxStatus extends WsjtxMessage {
  final int dialFrequency; // Hz
  final String mode;
  final String? dxCall;
  final String? report;
  final String? txMode;
  final bool txEnabled;
  final bool transmitting;
  final bool decoding;
  final int? rxDf;
  final int? txDf;
  final String? deCall;
  final String? deGrid;
  final String? dxGrid;
  final bool txWatchdog;
  final String? subMode;
  final bool fastMode;

  const WsjtxStatus({
    required super.id,
    required this.dialFrequency,
    required this.mode,
    required this.dxCall,
    required this.report,
    required this.txMode,
    required this.txEnabled,
    required this.transmitting,
    required this.decoding,
    required this.rxDf,
    required this.txDf,
    required this.deCall,
    required this.deGrid,
    required this.dxGrid,
    required this.txWatchdog,
    required this.subMode,
    required this.fastMode,
  });
}

class WsjtxDecode extends WsjtxMessage {
  final bool isNew;
  final int timeMs; // ms since UTC midnight
  final int snr;
  final double deltaTime;
  final int deltaFreq;
  final String mode;
  final String message;
  final bool lowConfidence;
  final bool offAir;

  const WsjtxDecode({
    required super.id,
    required this.isNew,
    required this.timeMs,
    required this.snr,
    required this.deltaTime,
    required this.deltaFreq,
    required this.mode,
    required this.message,
    required this.lowConfidence,
    required this.offAir,
  });

  /// Parse the callsign that appears after `CQ [DX ]` in the decode message.
  /// Returns null for non-CQ decodes.
  String? cqCall() {
    final parts = message.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first != 'CQ') return null;
    return stationCall();
  }

  /// Callsign of the station that transmitted this decode.
  ///
  /// Standard directed FT8 messages are `TO_CALL FROM_CALL payload`, so the
  /// transmitting station is the second token. For CQ messages we accept
  /// arbitrary 11m CB callsigns and derive the call relative to the optional
  /// grid instead of applying amateur-radio callsign validation.
  String? stationCall() {
    final parts = message.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return null;

    if (parts.first.toUpperCase() == 'CQ') {
      if (parts.length < 2) return null;
      final gridIndex = parts.lastIndexWhere(_isGridToken);
      if (gridIndex >= 2) return _cleanCallToken(parts[gridIndex - 1]);

      const cqModifiers = {
        'DX',
        'TEST',
        'POTA',
        'SOTA',
        'WW',
        'EU',
        'NA',
        'SA',
        'AS',
        'AF',
        'OC',
      };
      final second = parts[1].toUpperCase();
      if (parts.length >= 3 && cqModifiers.contains(second)) {
        return _cleanCallToken(parts[2]);
      }
      return _cleanCallToken(parts[1]);
    }

    if (parts.length < 2) return null;
    return _cleanCallToken(parts[1]);
  }

  /// Parse the reported grid (last token of decode text if 4-char) if present.
  String? cqGrid() {
    return gridHint();
  }

  /// Locator carried by any CQ or directed FT8 message.
  String? gridHint() {
    final parts = message.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    for (final token in parts.reversed) {
      if (_isGridToken(token)) return token.toUpperCase();
    }
    return null;
  }

  static bool _isGridToken(String token) => RegExp(
        r'^[A-R]{2}[0-9]{2}([A-X]{2})?$',
        caseSensitive: false,
      ).hasMatch(token);

  static String? _cleanCallToken(String token) {
    final call = token.replaceAll(RegExp(r'^[<]|[>]$'), '').toUpperCase();
    if (call.isEmpty ||
        _isGridToken(call) ||
        RegExp(r'^(R?[+-]?[0-9]{1,2}|R|RRR|RR73|73)$').hasMatch(call)) {
      return null;
    }
    return call;
  }
}

class WsjtxClear extends WsjtxMessage {
  const WsjtxClear({required super.id});
}

class WsjtxQsoLogged extends WsjtxMessage {
  final DateTime timeOff;
  final String dxCall;
  final String dxGrid;
  final int txFrequency;
  final String mode;
  final String reportSent;
  final String reportReceived;
  final String txPower;
  final String comments;
  final String name;
  final DateTime timeOn;
  final String opCall;
  final String myCall;
  final String myGrid;
  final String exchangeSent;
  final String exchangeReceived;
  final String? adifPropagationMode;

  const WsjtxQsoLogged({
    required super.id,
    required this.timeOff,
    required this.dxCall,
    required this.dxGrid,
    required this.txFrequency,
    required this.mode,
    required this.reportSent,
    required this.reportReceived,
    required this.txPower,
    required this.comments,
    required this.name,
    required this.timeOn,
    required this.opCall,
    required this.myCall,
    required this.myGrid,
    required this.exchangeSent,
    required this.exchangeReceived,
    required this.adifPropagationMode,
  });
}

class WsjtxClose extends WsjtxMessage {
  const WsjtxClose({required super.id});
}

class WsjtxUnknown extends WsjtxMessage {
  final int type;
  const WsjtxUnknown({required super.id, required this.type});
}
