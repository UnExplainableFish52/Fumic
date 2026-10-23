import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/media_item.dart';
import 'package:fumic/src/models/media_kind.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/services/playback_service.dart';
import 'package:fumic/src/theme/fumic_theme.dart';
import 'package:fumic/src/widgets/player_bar.dart';
import 'package:fumic/src/widgets/shared.dart';
import 'package:fumic/src/widgets/visualizer_view.dart';

const _item = MediaItem(
  path: 'test.mp3',
  title: 'A_long_song_title_that_should_never_move_the_play_button',
  artist: 'Artist',
  kind: MediaKind.audio,
  duration: Duration(minutes: 3),
  colors: [Colors.teal, Colors.blue],
);
void _noop() {}
void _value(double _) {}

void main() {
  for (final fullPlayer in [false, true]) {
    testWidgets(
      '${fullPlayer ? 'full player' : 'library player'} keeps transport centered at desktop sizes',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final progress = ValueNotifier(
          const PlaybackSnapshot(currentItem: _item),
        );
        addTearDown(progress.dispose);
        for (final size in const [
          Size(1920, 1080),
          Size(1366, 768),
          Size(1024, 768),
          Size(800, 600),
          Size(640, 600),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MaterialApp(
              theme: FumicTheme.dark(),
              home: Scaffold(
                body: fullPlayer
                    ? VisualizerView(
                        item: _item,
                        playback: progress.value,
                        playbackProgress: progress,
                        videoController: null,
                        settings: const VisualizerSettings(enabled: false),
                        onBackToLibrary: _noop,
                        onPlayPause: _noop,
                        onNext: _noop,
                        onPrevious: _noop,
                        onLoop: _noop,
                        onShuffle: _noop,
                        onMute: _noop,
                        onSpeedChanged: _value,
                        onSeekFraction: _value,
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: PlayerBar(
                          item: _item,
                          playback: progress.value,
                          onPlayPause: _noop,
                          onNext: _noop,
                          onPrevious: _noop,
                          onLoop: _noop,
                          onShuffle: _noop,
                          onMute: _noop,
                          onSpeedChanged: _value,
                          onSeekFraction: _value,
                          onFullPlayer: _noop,
                        ),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final transport = tester.getRect(find.byType(PlaybackTransport));
          expect(
            tester.getRect(find.byType(ProgressTrack)).bottom,
            lessThan(transport.top),
            reason: 'Seek bar stays above playback controls at $size',
          );
          expect(
            tester.getCenter(find.byType(PlayButton)).dx,
            closeTo(size.width / 2, 0.5),
            reason: 'Play button at $size',
          );
          expect(
            tester.getCenter(find.byType(ProgressTrack)).dx,
            closeTo(size.width / 2, 0.5),
            reason: 'Seek bar at $size',
          );
          expect(
            transport.overlaps(
              tester.getRect(find.byType(PlaybackSpeedControl)),
            ),
            isFalse,
          );
          expect(
            transport.overlaps(tester.getRect(find.byType(PlaybackMuteButton))),
            isFalse,
          );
          final previous = tester.getCenter(find.byTooltip('Previous'));
          final next = tester.getCenter(find.byTooltip('Next'));
          expect((previous.dx + next.dx) / 2, closeTo(size.width / 2, 0.5));
          expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
          expect(find.byTooltip('Mute').hitTestable(), findsOneWidget);
          expect(find.byType(Slider), findsNothing);
          expect(tester.takeException(), isNull, reason: 'Layout at $size');
        }
      },
    );
  }

  testWidgets('mute button reflects state and invokes its callback', (
    tester,
  ) async {
    var taps = 0;
    Future<void> show(double volume) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackMuteButton(volume: volume, onTap: () => taps++),
        ),
      ),
    );
    await show(0.73);
    expect(find.text('73'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Mute'));
    expect(taps, 1);
    await show(0);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).isSelected,
      isTrue,
    );
    await tester.tap(find.byTooltip('Unmute'));
    expect(taps, 2);
    await show(1);
    expect(find.text('100'), findsOneWidget);
  });
}
