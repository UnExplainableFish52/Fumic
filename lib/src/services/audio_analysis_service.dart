import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/media_item.dart';

class VisualizerAudioSignal {
  const VisualizerAudioSignal({
    required this.bassEnergy,
    required this.midEnergy,
    required this.highEnergy,
    required this.overallAmplitude,
    required this.smoothedAmplitude,
    required this.beatPulse,
  });

  const VisualizerAudioSignal.silence()
    : bassEnergy = 0,
      midEnergy = 0,
      highEnergy = 0,
      overallAmplitude = 0,
      smoothedAmplitude = 0,
      beatPulse = 0;

  final double bassEnergy;
  final double midEnergy;
  final double highEnergy;
  final double overallAmplitude;
  final double smoothedAmplitude;
  final double beatPulse;

  VisualizerAudioSignal copyWith({
    double? bassEnergy,
    double? midEnergy,
    double? highEnergy,
    double? overallAmplitude,
    double? smoothedAmplitude,
    double? beatPulse,
  }) {
    return VisualizerAudioSignal(
      bassEnergy: bassEnergy ?? this.bassEnergy,
      midEnergy: midEnergy ?? this.midEnergy,
      highEnergy: highEnergy ?? this.highEnergy,
      overallAmplitude: overallAmplitude ?? this.overallAmplitude,
      smoothedAmplitude: smoothedAmplitude ?? this.smoothedAmplitude,
      beatPulse: beatPulse ?? this.beatPulse,
    );
  }

  static VisualizerAudioSignal lerp(
    VisualizerAudioSignal a,
    VisualizerAudioSignal b,
    double t,
  ) {
    return VisualizerAudioSignal(
      bassEnergy: _lerp(a.bassEnergy, b.bassEnergy, t),
      midEnergy: _lerp(a.midEnergy, b.midEnergy, t),
      highEnergy: _lerp(a.highEnergy, b.highEnergy, t),
      overallAmplitude: _lerp(a.overallAmplitude, b.overallAmplitude, t),
      smoothedAmplitude: _lerp(a.smoothedAmplitude, b.smoothedAmplitude, t),
      beatPulse: _lerp(a.beatPulse, b.beatPulse, t),
    );
  }
}

class AudioAnalysisTimeline {
  const AudioAnalysisTimeline({
    required this.frames,
    required this.duration,
    required this.available,
  });

  const AudioAnalysisTimeline.unavailable()
    : frames = const [],
      duration = Duration.zero,
      available = false;

  final List<VisualizerAudioSignal> frames;
  final Duration duration;
  final bool available;

  VisualizerAudioSignal sample(Duration position) {
    if (!available || frames.isEmpty) {
      return const VisualizerAudioSignal.silence();
    }
    if (frames.length == 1 || duration <= Duration.zero) {
      return frames.first;
    }

    final clamped = position.inMilliseconds.clamp(0, duration.inMilliseconds);
    final progress = clamped / duration.inMilliseconds;
    final scaled = progress * (frames.length - 1);
    final lower = scaled.floor().clamp(0, frames.length - 1);
    final upper = math.min(lower + 1, frames.length - 1);
    final signal = VisualizerAudioSignal.lerp(
      frames[lower],
      frames[upper],
      scaled - lower,
    );
    final previous = frames[math.max(0, lower - 1)];
    final beat = ((signal.overallAmplitude - previous.smoothedAmplitude) * 2.4)
        .clamp(0.0, 1.0)
        .toDouble();
    return signal.copyWith(beatPulse: beat);
  }
}

class AudioAnalysisService {
  AudioAnalysisService._();

  static final AudioAnalysisService instance = AudioAnalysisService._();

  final Map<String, Future<AudioAnalysisTimeline>> _cache = {};

  Future<AudioAnalysisTimeline> analyze(MediaItem item) {
    final duration = item.duration ?? Duration.zero;
    final key = '${item.path}|${duration.inMilliseconds}';
    return _cache.putIfAbsent(key, () => _analyze(item));
  }

  Future<AudioAnalysisTimeline> _analyze(MediaItem item) async {
    final file = File(item.path);
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size < 64) {
        return const AudioAnalysisTimeline.unavailable();
      }

      final duration = item.duration ?? const Duration(minutes: 3);
      final frameCount = _frameCountFor(duration);
      final raf = await file.open();
      try {
        final headerLength = math.min(stat.size, 262144);
        final header = await raf.read(headerLength);
        final wav = _WavInfo.tryParse(header);
        final rawFrames = wav == null
            ? await _sampleCompressedBytes(raf, stat.size, frameCount)
            : await _sampleWavPcm(raf, wav, frameCount);
        if (rawFrames.isEmpty) {
          return const AudioAnalysisTimeline.unavailable();
        }
        return AudioAnalysisTimeline(
          frames: _normalize(rawFrames),
          duration: duration,
          available: true,
        );
      } finally {
        await raf.close();
      }
    } on Object {
      return const AudioAnalysisTimeline.unavailable();
    }
  }

  int _frameCountFor(Duration duration) {
    if (duration <= Duration.zero) {
      return 220;
    }
    return (duration.inSeconds * 2).clamp(180, 520).toInt();
  }

  Future<List<_RawEnergy>> _sampleCompressedBytes(
    RandomAccessFile raf,
    int length,
    int frameCount,
  ) async {
    const headerSkip = 8192;
    const chunkSize = 4096;
    final usableStart = math.min(headerSkip, math.max(0, length - 1));
    final usableLength = math.max(1, length - usableStart);
    final frames = <_RawEnergy>[];

    for (var frame = 0; frame < frameCount; frame++) {
      final progress = frameCount <= 1 ? 0.0 : frame / (frameCount - 1);
      final position = usableStart + (usableLength * progress).floor();
      await raf.setPosition(math.min(position, math.max(0, length - 1)));
      final bytes = await raf.read(math.min(chunkSize, length - position));
      if (bytes.length < 32) {
        continue;
      }
      frames.add(_energyFromBytes(bytes));
    }
    return frames;
  }

  Future<List<_RawEnergy>> _sampleWavPcm(
    RandomAccessFile raf,
    _WavInfo wav,
    int frameCount,
  ) async {
    final frames = <_RawEnergy>[];
    final bytesPerFrame = wav.bytesPerSample * wav.channels;
    if (bytesPerFrame <= 0 || wav.dataLength <= bytesPerFrame) {
      return frames;
    }

    final readLength = math.min(wav.dataLength, bytesPerFrame * 1536);
    final usableLength = math.max(1, wav.dataLength - readLength);
    for (var frame = 0; frame < frameCount; frame++) {
      final progress = frameCount <= 1 ? 0.0 : frame / (frameCount - 1);
      final position = wav.dataOffset + (usableLength * progress).floor();
      await raf.setPosition(position);
      final bytes = await raf.read(readLength);
      if (bytes.length < bytesPerFrame) {
        continue;
      }
      frames.add(_energyFromPcm(bytes, wav));
    }
    return frames;
  }

  _RawEnergy _energyFromBytes(Uint8List bytes) {
    var lowPass = 128.0;
    var previous = bytes.first.toDouble();
    var previousDelta = 0.0;
    var bass = 0.0;
    var mid = 0.0;
    var high = 0.0;
    var overall = 0.0;

    for (final byte in bytes) {
      final value = byte.toDouble();
      final centered = (value - 127.5).abs() / 127.5;
      lowPass += (value - lowPass) * 0.035;
      final delta = (value - previous).abs() / 255.0;

      bass += (lowPass - 127.5).abs() / 127.5;
      mid += delta;
      high += (delta - previousDelta).abs();
      overall += centered;

      previous = value;
      previousDelta = delta;
    }

    final count = bytes.length.toDouble();
    return _RawEnergy(
      bass: bass / count,
      mid: mid / count,
      high: high / count,
      overall: overall / count,
    );
  }

  _RawEnergy _energyFromPcm(Uint8List bytes, _WavInfo wav) {
    final data = ByteData.sublistView(bytes);
    final bytesPerFrame = wav.bytesPerSample * wav.channels;
    var lowPass = 0.0;
    var previous = 0.0;
    var previousDelta = 0.0;
    var bass = 0.0;
    var mid = 0.0;
    var high = 0.0;
    var overall = 0.0;
    var count = 0;

    for (var offset = 0; offset + bytesPerFrame <= bytes.length;) {
      var mixed = 0.0;
      for (var channel = 0; channel < wav.channels; channel++) {
        mixed += _readPcmSample(
          data,
          offset + channel * wav.bytesPerSample,
          wav.bitsPerSample,
        );
      }
      final sample = mixed / wav.channels;
      lowPass += (sample - lowPass) * 0.055;
      final delta = (sample - previous).abs();

      bass += lowPass.abs();
      mid += delta;
      high += (delta - previousDelta).abs();
      overall += sample.abs();

      previous = sample;
      previousDelta = delta;
      count++;
      offset += bytesPerFrame;
    }

    if (count == 0) {
      return const _RawEnergy.zero();
    }
    return _RawEnergy(
      bass: bass / count,
      mid: mid / count,
      high: high / count,
      overall: overall / count,
    );
  }

  double _readPcmSample(ByteData data, int offset, int bitsPerSample) {
    switch (bitsPerSample) {
      case 8:
        return (data.getUint8(offset) - 128) / 128.0;
      case 16:
        return data.getInt16(offset, Endian.little) / 32768.0;
      case 24:
        var value =
            data.getUint8(offset) |
            (data.getUint8(offset + 1) << 8) |
            (data.getUint8(offset + 2) << 16);
        if ((value & 0x800000) != 0) {
          value -= 0x1000000;
        }
        return value / 8388608.0;
      case 32:
        return data.getInt32(offset, Endian.little) / 2147483648.0;
      default:
        return 0;
    }
  }

  List<VisualizerAudioSignal> _normalize(List<_RawEnergy> frames) {
    final maxBass = frames.fold(0.0, (max, frame) => math.max(max, frame.bass));
    final maxMid = frames.fold(0.0, (max, frame) => math.max(max, frame.mid));
    final maxHigh = frames.fold(0.0, (max, frame) => math.max(max, frame.high));
    final maxOverall = frames.fold(
      0.0,
      (max, frame) => math.max(max, frame.overall),
    );

    var smoothBass = 0.0;
    var smoothMid = 0.0;
    var smoothHigh = 0.0;
    var smoothOverall = 0.0;

    return [
      for (final frame in frames)
        (() {
          final bass = _normalizeValue(frame.bass, maxBass);
          final mid = _normalizeValue(frame.mid, maxMid);
          final high = _normalizeValue(frame.high, maxHigh);
          final overall = _normalizeValue(frame.overall, maxOverall);
          smoothBass = _lerp(smoothBass, bass, 0.34);
          smoothMid = _lerp(smoothMid, mid, 0.30);
          smoothHigh = _lerp(smoothHigh, high, 0.26);
          smoothOverall = _lerp(smoothOverall, overall, 0.32);
          return VisualizerAudioSignal(
            bassEnergy: smoothBass.clamp(0.0, 1.0).toDouble(),
            midEnergy: smoothMid.clamp(0.0, 1.0).toDouble(),
            highEnergy: smoothHigh.clamp(0.0, 1.0).toDouble(),
            overallAmplitude: overall.clamp(0.0, 1.0).toDouble(),
            smoothedAmplitude: smoothOverall.clamp(0.0, 1.0).toDouble(),
            beatPulse: 0,
          );
        })(),
    ];
  }

  double _normalizeValue(double value, double max) {
    if (max <= 0) {
      return 0;
    }
    return (value / max).clamp(0.0, 1.0).toDouble();
  }
}

class _WavInfo {
  const _WavInfo({
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  final int channels;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;

  int get bytesPerSample => bitsPerSample ~/ 8;

  static _WavInfo? tryParse(Uint8List header) {
    if (header.length < 44 ||
        _ascii(header, 0, 4) != 'RIFF' ||
        _ascii(header, 8, 4) != 'WAVE') {
      return null;
    }

    final data = ByteData.sublistView(header);
    var position = 12;
    int? audioFormat;
    int? channels;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;

    while (position + 8 <= header.length) {
      final chunk = _ascii(header, position, 4);
      final chunkLength = data.getUint32(position + 4, Endian.little);
      final contentOffset = position + 8;
      if (contentOffset + chunkLength > header.length) {
        break;
      }
      if (chunk == 'fmt ' && chunkLength >= 16) {
        audioFormat = data.getUint16(contentOffset, Endian.little);
        channels = data.getUint16(contentOffset + 2, Endian.little);
        bitsPerSample = data.getUint16(contentOffset + 14, Endian.little);
      } else if (chunk == 'data') {
        dataOffset = contentOffset;
        dataLength = chunkLength;
      }
      position = contentOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
    }

    if (audioFormat != 1 ||
        channels == null ||
        channels <= 0 ||
        bitsPerSample == null ||
        !const {8, 16, 24, 32}.contains(bitsPerSample) ||
        dataOffset == null ||
        dataLength == null ||
        dataLength <= 0) {
      return null;
    }

    return _WavInfo(
      channels: channels,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }

  static String _ascii(Uint8List bytes, int offset, int length) {
    if (offset + length > bytes.length) {
      return '';
    }
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}

class _RawEnergy {
  const _RawEnergy({
    required this.bass,
    required this.mid,
    required this.high,
    required this.overall,
  });

  const _RawEnergy.zero() : bass = 0, mid = 0, high = 0, overall = 0;

  final double bass;
  final double mid;
  final double high;
  final double overall;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
