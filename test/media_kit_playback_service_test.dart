import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/services/media_kit_playback_service.dart';

void main() {
  test(
    'shuffle toggle keeps current queue item when playback order changes',
    () {
      expect(playbackIndexForQueueIndex([0, 1, 2, 3], 2), 2);
      expect(playbackIndexForQueueIndex([2, 0, 3, 1], 2), 0);
      expect(playbackIndexForQueueIndex([0, 1, 2, 3], 3), 3);
    },
  );

  test('missing current queue item falls back to first playback item', () {
    expect(playbackIndexForQueueIndex([0, 1, 2], 9), 0);
  });

  test('next and previous move from the current item in shuffled order', () {
    const order = [2, 0, 3, 1];

    expect(playbackIndexAfterMove(order, 2, 1), 1);
    expect(playbackIndexAfterMove(order, 0, 1), 2);
    expect(playbackIndexAfterMove(order, 2, -1), 3);
  });

  test('next after disabling shuffle continues in normal queue order', () {
    const normalOrder = [0, 1, 2, 3];

    expect(playbackIndexForQueueIndex(normalOrder, 2), 2);
    expect(playbackIndexAfterMove(normalOrder, 2, 1), 3);
    expect(playbackIndexAfterMove(normalOrder, 2, -1), 1);
  });

  test('playback movement wraps without jumping to the top early', () {
    const normalOrder = [0, 1, 2, 3];

    expect(playbackIndexAfterMove(normalOrder, 3, 1), 0);
    expect(playbackIndexAfterMove(normalOrder, 0, -1), 3);
  });
}
