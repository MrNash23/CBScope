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
  const WsjtxHeartbeat({required super.id, required this.maxSchema, required this.version, required this.revision});
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
    if (parts.length >= 3) {
      // "CQ DX call grid" or "CQ POTA call grid"
      final second = parts[1];
      if (second.length <= 4 && !RegExp(r'[0-9]').hasMatch(second)) {
        return parts.length >= 3 ? parts[2] : null;
      }
      return parts[1];
    }
    return parts.length >= 2 ? parts[1] : null;
  }

  /// Parse the reported grid (last token of decode text if 4-char) if present.
  String? cqGrid() {
    final parts = message.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final last = parts.last;
    if (RegExp(r'^[A-R]{2}[0-9]{2}([a-x]{2})?$', caseSensitive: false).hasMatch(last)) {
      return last.toUpperCase();
    }
    return null;
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
