import 'dart:convert';
import 'dart:typed_data';

import 'messages.dart';

/// Decoder for WSJT-X UDP packets using Qt's QDataStream framing (big-endian).
class WsjtxReader {
  final ByteData _data;
  int _pos = 0;

  WsjtxReader(Uint8List bytes) : _data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  int get remaining => _data.lengthInBytes - _pos;

  static const int magic = 0xadbccbda;

  static WsjtxMessage? parse(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final r = WsjtxReader(bytes);
    final m = r.readUint32();
    if (m != magic) return null;
    final schema = r.readUint32();
    if (schema < 2 || schema > 3) return null;
    final type = r.readUint32();
    final id = r.readUtf8() ?? '';

    switch (type) {
      case 0:
        return WsjtxHeartbeat(
          id: id,
          maxSchema: r.readUint32(),
          version: r.readUtf8() ?? '',
          revision: r.readUtf8() ?? '',
        );
      case 1:
        final dial = r.readUint64();
        final mode = r.readUtf8() ?? '';
        final dxCall = r.readUtf8();
        final report = r.readUtf8();
        final txMode = r.readUtf8();
        final txEnabled = r.readBool();
        final transmitting = r.readBool();
        final decoding = r.readBool();
        final rxDf = r.readUint32();
        final txDf = r.readUint32();
        final deCall = r.readUtf8();
        final deGrid = r.readUtf8();
        final dxGrid = r.readUtf8();
        final watchdog = r.readBool();
        final subMode = r.readUtf8();
        final fast = r.readBool();
        // Schema-3 trailer (all optional): specialOpMode (u8), freqTolerance
        // (u32), t/rPeriod (u32), configName (utf8), txMessage (utf8). Read
        // each only if the packet is long enough — WSJT-CB packets vary.
        if (r.canRead(1)) r.readUint8();          // specialOpMode
        if (r.canRead(4)) r.readUint32();         // freqTolerance
        if (r.canRead(4)) r.readUint32();         // trPeriod
        if (r.canRead(4)) r.readUtf8();           // configName
        final txMessage = r.canRead(4) ? r.readUtf8() : null;
        return WsjtxStatus(
          id: id,
          dialFrequency: dial,
          mode: mode,
          dxCall: dxCall,
          report: report,
          txMode: txMode,
          txEnabled: txEnabled,
          transmitting: transmitting,
          decoding: decoding,
          rxDf: rxDf,
          txDf: txDf,
          deCall: deCall,
          deGrid: deGrid,
          dxGrid: dxGrid,
          txWatchdog: watchdog,
          subMode: subMode,
          fastMode: fast,
          txMessage: txMessage,
        );
      case 2:
        return WsjtxDecode(
          id: id,
          isNew: r.readBool(),
          timeMs: r.readUint32(),
          snr: r.readInt32(),
          deltaTime: r.readFloat64(),
          deltaFreq: r.readUint32(),
          mode: r.readUtf8() ?? '',
          message: r.readUtf8() ?? '',
          lowConfidence: r.canRead(1) ? r.readBool() : false,
          offAir: r.canRead(1) ? r.readBool() : false,
        );
      case 3:
        return WsjtxClear(id: id);
      case 5:
        final timeOff = r.readQDateTime();
        final dxCall = r.readUtf8() ?? '';
        final dxGrid = r.readUtf8() ?? '';
        final txFreq = r.readUint64();
        final mode = r.readUtf8() ?? '';
        final rSent = r.readUtf8() ?? '';
        final rRecv = r.readUtf8() ?? '';
        final power = r.readUtf8() ?? '';
        final comments = r.readUtf8() ?? '';
        final name = r.readUtf8() ?? '';
        final timeOn = r.readQDateTime();
        final opCall = r.readUtf8() ?? '';
        final myCall = r.readUtf8() ?? '';
        final myGrid = r.readUtf8() ?? '';
        final exSent = r.readUtf8() ?? '';
        final exRecv = r.readUtf8() ?? '';
        final prop = r.canRead(4) ? r.readUtf8() : null;
        return WsjtxQsoLogged(
          id: id,
          timeOff: timeOff,
          dxCall: dxCall,
          dxGrid: dxGrid,
          txFrequency: txFreq,
          mode: mode,
          reportSent: rSent,
          reportReceived: rRecv,
          txPower: power,
          comments: comments,
          name: name,
          timeOn: timeOn,
          opCall: opCall,
          myCall: myCall,
          myGrid: myGrid,
          exchangeSent: exSent,
          exchangeReceived: exRecv,
          adifPropagationMode: prop,
        );
      case 6:
        return WsjtxClose(id: id);
      default:
        return WsjtxUnknown(id: id, type: type);
    }
  }

  bool canRead(int n) => remaining >= n;

  int readUint8() {
    final v = _data.getUint8(_pos);
    _pos += 1;
    return v;
  }

  int readUint32() {
    final v = _data.getUint32(_pos, Endian.big);
    _pos += 4;
    return v;
  }

  int readInt32() {
    final v = _data.getInt32(_pos, Endian.big);
    _pos += 4;
    return v;
  }

  int readUint64() {
    final v = _data.getUint64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  double readFloat64() {
    final v = _data.getFloat64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  bool readBool() {
    final v = _data.getUint8(_pos) != 0;
    _pos += 1;
    return v;
  }

  /// Qt QByteArray / QString(utf8): int32 length, then bytes. -1 = null.
  String? readUtf8() {
    if (!canRead(4)) return null;
    final len = _data.getInt32(_pos, Endian.big);
    _pos += 4;
    if (len < 0) return null;
    if (len == 0) return '';
    if (!canRead(len)) return null;
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _pos, len);
    _pos += len;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// QDateTime serialization (Qt 5): qint64 julianDay, uint32 msSinceMidnight,
  /// uint8 spec (0=Local, 1=UTC, 2=OffsetFromUTC, 3=TimeZone); when 2 also uint32 offset.
  DateTime readQDateTime() {
    final jd = _data.getInt64(_pos, Endian.big);
    _pos += 8;
    final msMidnight = _data.getUint32(_pos, Endian.big);
    _pos += 4;
    final spec = _data.getUint8(_pos);
    _pos += 1;
    int offsetSecs = 0;
    if (spec == 2 && canRead(4)) {
      offsetSecs = _data.getInt32(_pos, Endian.big);
      _pos += 4;
    }
    // Convert Julian day to Gregorian date.
    // (Fliegel & van Flandern algorithm)
    int l = jd + 68569;
    final n = ((4 * l) ~/ 146097);
    l -= ((146097 * n + 3) ~/ 4);
    final i = ((4000 * (l + 1)) ~/ 1461001);
    l -= ((1461 * i) ~/ 4) - 31;
    final j = ((80 * l) ~/ 2447);
    final day = l - ((2447 * j) ~/ 80);
    l = (j ~/ 11);
    final month = j + 2 - 12 * l;
    final year = 100 * (n - 49) + i + l;

    final dt = DateTime.utc(year, month, day).add(Duration(milliseconds: msMidnight));
    return spec == 1 ? dt : dt.subtract(Duration(seconds: offsetSecs));
  }
}
