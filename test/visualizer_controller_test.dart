import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/features/visualizer/visualizer_controller.dart';
import 'package:fumic/features/visualizer/visualizer_settings.dart';

void main() {
  testWidgets('visualizer stops ticking when paused, muted, or inactive', (
    tester,
  ) async {
    final controller = TrapVisualizerController(
      vsync: tester,
      settings: const VisualizerSettings(),
      seed: 1,
      playing: true,
      volume: 0.5,
    );
    addTearDown(controller.dispose);
    var updates = 0;
    controller.addListener(() => updates++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(updates, greaterThan(0));

    Future<void> expectStopped() async {
      final frozen = updates;
      await tester.pump(const Duration(seconds: 1));
      expect(updates, frozen);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }

    controller.update(playing: false);
    await expectStopped();
    controller.update(playing: true, active: false);
    await expectStopped();
    controller.update(active: true, volume: 0);
    await expectStopped();
    controller.update(volume: 0.5);
    final before = updates;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(updates, greaterThan(before));
    controller.update(settings: const VisualizerSettings(enabled: false));
    await expectStopped();
  });
}
