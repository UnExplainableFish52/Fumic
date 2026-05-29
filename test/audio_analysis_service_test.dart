import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/media_item.dart';
import 'package:fumic/src/models/media_kind.dart';
import 'package:fumic/src/services/audio_analysis_service.dart';

void main() {
  test('extracts a normalized WAV energy timeline', () async {
    final directory = await Directory.systemTemp.createTemp('fumic_analysis_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}sine.wav');
    await file.writeAsBytes(_wavSine());

    final timeline = await AudioAnalysisService.instance.analyze(
      MediaItem(
        path: file.path,
        title: 'sine',
        artist: 'test',
        kind: MediaKind.audio,
        duration: const Duration(seconds: 1),
        colors: const [Colors.cyan, Colors.blue],
      ),
    );

    final signal = timeline.sample(const Duration(milliseconds: 500));

    expect(timeline.available, isTrue);
    expect(timeline.frames.length, greaterThan(100));
    expect(signal.overallAmplitude, greaterThan(0));
    expect(signal.bassEnergy, inInclusiveRange(0, 1));
    expect(signal.midEnergy, inInclusiveRange(0, 1));
    expect(signal.highEnergy, inInclusiveRange(0, 1));
  });
}

List<int> _wavSine() {
  const sampleRate = 8000;
  const samples = sampleRate;
  final data = <int>[];
  for (var index = 0; index < samples; index++) {
    final t = index / sampleRate;
    final envelope = index < samples ~/ 2 ? 0.34 : 0.86;
    final sample = (math.sin(t * math.pi * 2 * 220) * envelope * 32767).round();
    data.addAll(_int16Le(sample));
  }

  return [
    ...'RIFF'.codeUnits,
    ..._uint32Le(36 + data.length),
    ...'WAVE'.codeUnits,
    ...'fmt '.codeUnits,
    ..._uint32Le(16),
    ..._uint16Le(1),
    ..._uint16Le(1),
    ..._uint32Le(sampleRate),
    ..._uint32Le(sampleRate * 2),
    ..._uint16Le(2),
    ..._uint16Le(16),
    ...'data'.codeUnits,
    ..._uint32Le(data.length),
    ...data,
  ];
}

List<int> _uint16Le(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _int16Le(int value) {
  final normalized = value < 0 ? value + 0x10000 : value;
  return _uint16Le(normalized);
}

List<int> _uint32Le(int value) {
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}
