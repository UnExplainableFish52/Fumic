import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/playback_speed.dart';

void main() {
  test('playback speed options include release presets', () {
    expect(
      playbackSpeedOptions,
      containsAll(<double>[0.9, 1.1, 1.4, 1.6, 2.5, 3.0]),
    );
    expect(minPlaybackSpeed, 0.5);
    expect(maxPlaybackSpeed, 3.0);
  });
}
