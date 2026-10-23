import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fumic/src/app/fumic_app.dart';
import 'package:fumic/src/theme/fumic_theme.dart';
import 'package:fumic/src/app/fumic_controller.dart';
import 'package:fumic/src/models/fumic_page.dart';
import 'package:fumic/src/models/media_item.dart';
import 'package:fumic/src/models/media_kind.dart';
import 'package:fumic/src/models/playlist.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/services/app_settings_repository.dart';
import 'package:fumic/src/services/background_image_service.dart';
import 'package:fumic/src/services/cover_art_repository.dart';
import 'package:fumic/src/services/folder_picker_service.dart';
import 'package:fumic/src/services/library_settings_repository.dart';
import 'package:fumic/src/services/media_library_service.dart';
import 'package:fumic/src/services/media_metadata_service.dart';
import 'package:fumic/src/services/media_scanner.dart';
import 'package:fumic/src/services/playlist_repository.dart';
import 'package:fumic/src/services/playback_service.dart';
import 'package:fumic/src/widgets/home_library.dart';
import 'package:fumic/src/widgets/visualizer_view.dart';
import 'package:fumic/src/widgets/wallpaper_image.dart';
import 'package:fumic/features/visualizer/trap_visualizer_view.dart';
import 'package:fumic/features/visualizer/trap_visualizer_painter.dart';

void main() {
  testWidgets(
    'effects off and Ctrl+B give wallpaper-only music without stopping playback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final playback = _FakePlaybackService();
      final preferences = MemoryAppSettingsRepository(
        const VisualizerSettings(enabled: false, showArtwork: false),
      );
      final controller = _testController(
        playback: playback,
        appSettingsRepository: preferences,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await controller.activateSelected('');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(find.byType(TrapVisualizerView), findsNothing);
      await _sendCtrlKey(tester, LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('full-player-controls')), findsNothing);
      expect(find.text('Add to playlist'), findsNothing);
      expect(
        (await preferences.loadVisualizerSettings()).showPlayerControls,
        isFalse,
      );
      expect(find.byType(WallpaperImage), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('full-player-controls-backdrop')),
            )
            .opacity,
        0,
      );
      expect(playback.snapshot.playing, isTrue);
      final wallpaper = tester.widget<WallpaperImage>(
        find.byType(WallpaperImage),
      );
      await playback.seekRelative(const Duration(seconds: 5));
      await tester.pump();
      expect(
        tester.widget<WallpaperImage>(find.byType(WallpaperImage)),
        same(wallpaper),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _sendCtrlKey(tester, LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('full-player-controls')),
        findsOneWidget,
      );
      expect(find.byTooltip('Pause').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'center artwork off removes the logo and effects off removes all center painting',
    (tester) async {
      Future<void> show(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 500,
                child: TrapVisualizerView(
                  item: _sampleItems.first,
                  playback: const PlaybackSnapshot(),
                  settings: VisualizerSettings(
                    enabled: enabled,
                    showArtwork: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await show(true);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      final spectrum = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is TrapVisualizerPainter,
      );
      expect(spectrum, findsOneWidget);
      await show(false);
      await tester.pumpAndSettle();
      expect(spectrum, findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'F and E change the player view without shrinking the window and I minimizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const channel = MethodChannel('fumic/window');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final playback = _FakePlaybackService();
      final controller = _testController(
        playback: playback,
        appSettingsRepository: MemoryAppSettingsRepository(
          const VisualizerSettings(enabled: false),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(controller.fullPlayer, isTrue);
      expect(find.byTooltip('Close player'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(controller.fullPlayer, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(calls.last.method, 'setFullscreen');
      expect(calls.last.arguments, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(calls.last.arguments, isTrue);
      final beforeExit = calls.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.fullPlayer, isFalse);
      expect(calls.length, beforeExit);
      controller.selectTab(MediaKind.video);
      await controller.activateSelected('');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(controller.fullPlayer, isFalse);
      final opens = playback.openQueueCount;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        tester.widget<VisualizerView>(find.byType(VisualizerView)).item.kind,
        MediaKind.video,
      );
      expect(playback.openQueueCount, opens);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pump();
      expect(calls.last.method, 'minimize');
      expect(playback.snapshot.playing, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'B hides controls persistently while Home stays visible and Settings can recover them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preferences = MemoryAppSettingsRepository(
        const VisualizerSettings(enabled: false),
      );
      final controller = _testController(appSettingsRepository: preferences);
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      final controls = find.byKey(const ValueKey('full-player-controls'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(
        (await preferences.loadVisualizerSettings()).showPlayerControls,
        isFalse,
      );
      expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(controls, findsNothing);
      await tester.tapAt(const Offset(80, 80));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(controls, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(controls, findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(controls, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(controls, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      await _sendCtrlKey(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Playback'));
      await tester.pumpAndSettle();
      final setting = find.text('Show full player controls');
      await tester.ensureVisible(setting);
      await tester.pumpAndSettle();
      final row = find.ancestor(of: setting, matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(
        (await preferences.loadVisualizerSettings()).showPlayerControls,
        isTrue,
      );
      final dropdown = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never hide automatically').last);
      await tester.pumpAndSettle();
      expect(
        (await preferences.loadVisualizerSettings())
            .effectivePlayerControlsHideDelaySeconds,
        0,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(controls, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search selection stays visible on transparent cards and follows arrow keys',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _testController(
        appSettingsRepository: MemoryAppSettingsRepository(
          const VisualizerSettings(cardOpacity: 0),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Music');
      await tester.pumpAndSettle();
      Finder tileFor(String title) => find
          .ancestor(
            of: find.text(title).first,
            matching: find.byType(AnimatedContainer),
          )
          .first;
      BoxDecoration decorationFor(String title) =>
          tester.widget<AnimatedContainer>(tileFor(title)).decoration!
              as BoxDecoration;
      final first = decorationFor('Take Me Down');
      expect(first.color!.a, greaterThanOrEqualTo(0.85));
      expect((first.border! as Border).top.color, FumicTheme.brand);
      expect((first.border! as Border).top.width, 2);
      expect(
        find.descendant(
          of: find.byType(HomeLibrary),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      final originalBounds = tester.getRect(tileFor('Take Me Down'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.selectedItem('Music')?.title, 'Skyfall');
      expect(
        (decorationFor('Take Me Down').border! as Border).top.color,
        isNot(FumicTheme.brand),
      );
      expect(
        (decorationFor('Skyfall').border! as Border).top.color,
        FumicTheme.brand,
      );
      expect(decorationFor('Skyfall').color!.a, greaterThanOrEqualTo(0.85));
      expect(decorationFor('Take Me Down').color!.a, 0);
      expect(tester.getRect(tileFor('Take Me Down')), originalBounds);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        (decorationFor('Take Me Down').border! as Border).top.color,
        FumicTheme.brand,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mute restores volume across player views and shares keyboard volume controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await controller.setVolume(0.73);
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byTooltip('Mute'));
      await tester.pumpAndSettle();
      expect(playback.snapshot.volume, 0);
      controller.showFullPlayer();
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(playback.snapshot.volume, 0.73);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(playback.snapshot.volume, closeTo(0.68, 0.0001));
      await _sendCtrlKey(tester, LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(playback.snapshot.volume, 0);
      controller.closeFullPlayer();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pumpAndSettle();
      expect(playback.snapshot.volume, closeTo(0.68, 0.0001));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(playback.snapshot.volume, closeTo(0.73, 0.0001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shuffle and loop visibly change fill and border in the app and full player',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _testController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      for (final fullPlayer in [false, true]) {
        if (fullPlayer) controller.showFullPlayer();
        await tester.pumpAndSettle();
        for (final tooltip in ['Shuffle', 'Loop']) {
          final before = button(tooltip);
          final wasSelected = before.isSelected!;
          final oldFill = before.style!.backgroundColor!.resolve({});
          final oldBorder = before.style!.side!.resolve({})!;
          await tester.tap(find.byTooltip(tooltip));
          await tester.pumpAndSettle();
          final after = button(tooltip);
          expect(after.isSelected, !wasSelected);
          expect(after.style!.backgroundColor!.resolve({}), isNot(oldFill));
          expect(after.style!.side!.resolve({})!.color, isNot(oldBorder.color));
          final selected = after.isSelected! ? after : before;
          expect(selected.style!.side!.resolve({})!.color, FumicTheme.accent);
          expect(selected.style!.side!.resolve({})!.width, greaterThan(1));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'JKL seeks video by five seconds and toggles playback outside text fields',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final playback = _FakePlaybackService();
      final controller = _testController(
        playback: playback,
        initialItems: [
          _sampleItems.last.copyWith(duration: const Duration(minutes: 2)),
        ],
      );
      addTearDown(controller.dispose);
      controller.selectTab(MediaKind.video);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await controller.activateSelected('');
      await playback.seekRelative(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(controller.fullPlayer, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(playback.snapshot.position, const Duration(seconds: 25));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(playback.snapshot.position, const Duration(seconds: 30));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(playback.snapshot.playing, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(playback.snapshot.playing, isTrue);
      controller.closeFullPlayer();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      for (final key in [
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyL,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.pump();
      expect(playback.snapshot.playing, isTrue);
      expect(playback.snapshot.position, const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'wallpaper replacement and preset selection clean saved custom files',
    () async {
      final service = MemoryBackgroundImageService(nextPath: 'first.jpg');
      final settings = MemoryAppSettingsRepository();
      final controller = _testController(
        backgroundImageService: service,
        appSettingsRepository: settings,
      );
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      await controller.pickCustomBackground();
      service.nextPath = 'second.jpg';
      await controller.pickCustomBackground();
      expect(service.deletedPaths, ['first.jpg']);
      expect(
        (await settings.loadVisualizerSettings()).customBackgroundPath,
        'second.jpg',
      );
      await controller.updateVisualizerSettings(
        controller.visualizerSettings.copyWith(
          backgroundIndex: 0,
          clearCustomBackgroundPath: true,
        ),
      );
      expect(service.deletedPaths, ['first.jpg', 'second.jpg']);
      expect(
        (await settings.loadVisualizerSettings()).customBackgroundPath,
        isNull,
      );
    },
  );

  test(
    'failed wallpaper saves preserve the old selection and clean the new import',
    () async {
      final service = MemoryBackgroundImageService(nextPath: 'new.jpg');
      final settings = _FailingAppearanceRepository(
        const VisualizerSettings(customBackgroundPath: 'old.jpg'),
      );
      final controller = _testController(
        backgroundImageService: service,
        appSettingsRepository: settings,
      );
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      expect(service.cleanupPaths, ['old.jpg']);
      settings.failNext = true;
      await expectLater(controller.pickCustomBackground(), throwsStateError);
      expect(controller.visualizerSettings.customBackgroundPath, 'old.jpg');
      expect(
        (await settings.loadVisualizerSettings()).customBackgroundPath,
        'old.jpg',
      );
      expect(service.deletedPaths, ['new.jpg']);
      settings.failNext = true;
      await expectLater(controller.resetCustomBackground(), throwsStateError);
      expect(controller.visualizerSettings.customBackgroundPath, 'old.jpg');
      expect(service.deletedPaths, ['new.jpg']);
    },
  );

  test(
    'a preset selected during import wins and duplicate pickers are ignored',
    () async {
      final service = _DeferredBackgroundService();
      final controller = _testController(backgroundImageService: service);
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      final importing = controller.pickCustomBackground();
      await controller.pickCustomBackground();
      expect(service.picks, 1);
      await controller.updateVisualizerSettings(
        controller.visualizerSettings.copyWith(
          backgroundIndex: 0,
          clearCustomBackgroundPath: true,
        ),
      );
      service.pending.complete('discard.jpg');
      await importing;
      expect(controller.visualizerSettings.customBackgroundPath, isNull);
      expect(controller.visualizerSettings.backgroundIndex, 0);
      expect(service.deletedPaths, ['discard.jpg']);
    },
  );

  test(
    'disposing during import cleans the abandoned file without notifying',
    () async {
      final service = _DeferredBackgroundService();
      final controller = _testController(backgroundImageService: service);
      await controller.loadLibrary();
      final importing = controller.pickCustomBackground();
      await Future<void>.value();
      expect(service.picks, 1);
      controller.dispose();
      service.pending.complete('discard.jpg');
      await importing;
      expect(service.deletedPaths, ['discard.jpg']);
    },
  );

  testWidgets(
    'invalid wallpaper imports show a message and preserve appearance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _testController(
        backgroundImageService: _InvalidBackgroundService(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      final previous = controller.visualizerSettings;
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Appearance'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Choose image');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a wallpaper smaller than 24 MB.'),
        findsOneWidget,
      );
      expect(controller.visualizerSettings, same(previous));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'position updates bypass the library and stop notifying in background',
    () async {
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      await controller.activateSelected('');
      var screenUpdates = 0;
      var progressUpdates = 0;
      controller.addListener(() => screenUpdates++);
      controller.playbackProgress.addListener(() => progressUpdates++);
      for (var i = 0; i < 200; i++) {
        await playback.seekRelative(const Duration(milliseconds: 200));
      }
      expect(screenUpdates, 0);
      expect(progressUpdates, 200);
      controller.setForegroundActive(false);
      await playback.seekRelative(const Duration(seconds: 10));
      await playback.playNext();
      expect(screenUpdates, 0);
      expect(progressUpdates, 200);
      expect(playback.snapshot.playing, isTrue);
      controller.setForegroundActive(true);
      expect(screenUpdates, 1);
      expect(progressUpdates, 201);
      expect(controller.playbackProgress.value, same(playback.snapshot));
      expect(
        controller.selectedItem('')?.path,
        playback.snapshot.currentItem?.path,
      );
    },
  );

  testWidgets(
    'background music leaves the library idle and resumes current progress',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await controller.activateSelected('');
      await tester.pumpAndSettle();
      final library = tester.widget<HomeLibrary>(find.byType(HomeLibrary));
      await playback.seekRelative(const Duration(seconds: 12));
      await tester.pump();
      expect(
        tester.widget<HomeLibrary>(find.byType(HomeLibrary)),
        same(library),
      );
      expect(find.text('0:12'), findsOneWidget);
      for (final lifecycle in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
        await tester.pumpAndSettle();
        final frozen = controller.playbackProgress.value;
        await playback.seekRelative(const Duration(seconds: 30));
        await tester.pump(const Duration(seconds: 3));
        expect(controller.playbackProgress.value, same(frozen));
        expect(playback.snapshot.playing, isTrue);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.playbackProgress.value, same(playback.snapshot));
      expect(find.text('1:12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Fumic shell renders library and navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Fumic - Magical Media Player');
    expect(find.bySemanticsLabel('Fumic'), findsOneWidget);
    expect(find.text('Audio library'), findsOneWidget);
    expect(find.text('Search media (Ctrl + K)'), findsOneWidget);
    expect(find.text('Take Me Down'), findsWidgets);

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Video library'), findsOneWidget);
    expect(find.text('2026-01-17 13-06-00'), findsWidgets);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    expect(find.text('Fumic - Magical Media Player'), findsOneWidget);
    expect(
      find.text('Keyboard Shortcuts', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('search filters real media items', (tester) async {
    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'sky');
    await tester.pumpAndSettle();

    expect(find.text('Skyfall'), findsWidgets);
    expect(find.text('Take Me Down'), findsNothing);
  });

  testWidgets('empty search can be cleared from the library', (tester) async {
    final controller = _testController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'no matching track');
    await tester.pumpAndSettle();
    expect(find.text('No matching media'), findsOneWidget);
    expect(find.text('Your library starts here'), findsNothing);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Clear search'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No matching media'), findsNothing);
    expect(controller.visibleItems('').length, 2);
  });

  testWidgets('first launch adds a library folder from Home', (tester) async {
    final controller = _testController(
      initialFolders: const [],
      folderPicker: _FakeFolderPicker(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Your library starts here'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add folder'));
    await tester.pumpAndSettle();
    expect(controller.page, FumicPage.home);
    expect(find.text('Your library starts here'), findsNothing);
    expect(controller.items.length, 3);
    expect(controller.visibleItems('').length, 2);
  });

  testWidgets(
    'music selects on click and plays on double-click without a tile button',
    (tester) async {
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Skyfall'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play Skyfall'), findsNothing);
      await tester.tap(find.text('Skyfall').first);
      await tester.pumpAndSettle();
      expect(playback.openedItem, isNull);
      await tester.tap(find.text('Skyfall').first);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Skyfall').first);
      await tester.pumpAndSettle();
      expect(playback.openedItem?.title, 'Skyfall');
      expect(playback.snapshot.playing, isTrue);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    },
  );

  testWidgets('empty audio tab offers the available video library', (
    tester,
  ) async {
    final controller = _testController(initialItems: [_sampleItems.last]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('No audio here yet'), findsOneWidget);

    await tester.ensureVisible(find.text('Browse videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse videos'));
    await tester.pumpAndSettle();
    expect(controller.tab, MediaKind.video);
    expect(find.text('2026-01-17 13-06-00'), findsWidgets);
  });

  testWidgets('library and player fit common desktop window sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _testController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    for (final size in const [
      Size(1024, 768),
      Size(800, 600),
      Size(640, 600),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Layout at $size');
    }
  });

  testWidgets('Ctrl+H scrolls visible Home library back to top', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      initialItems: [
        for (var index = 0; index < 36; index++)
          MediaItem(
            path: 'C:\\Media\\Music\\Track $index.mp3',
            title: 'Track ${index.toString().padLeft(2, '0')}',
            artist: 'Music',
            kind: MediaKind.audio,
            duration: const Duration(minutes: 3),
            colors: const [
              Color(0xFF915923),
              Color(0xFF1F5E99),
              Color(0xFF101821),
            ],
          ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    final homeScrollView = find.byType(CustomScrollView).first;
    final scrollable = find
        .descendant(of: homeScrollView, matching: find.byType(Scrollable))
        .first;
    final scrollState = tester.state<ScrollableState>(scrollable);

    await tester.drag(homeScrollView, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(scrollState.position.pixels, greaterThan(0));

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(scrollState.position.pixels, 0);
  });

  testWidgets('search auto-selects first result and Ctrl+Enter plays it', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'sky');
    await tester.pumpAndSettle();

    expect(controller.selectedItem('sky')?.title, 'Skyfall');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(playback.openedItem?.title, 'Skyfall');
  });

  testWidgets('playing from search keeps the full library queue', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(
      playback: playback,
      initialItems: const [
        MediaItem(
          path: 'C:\\Media\\Music\\Before.mp3',
          title: 'Before',
          artist: 'Music',
          kind: MediaKind.audio,
          duration: Duration(minutes: 3),
          colors: [Color(0xFF915923), Color(0xFF1F5E99), Color(0xFF101821)],
        ),
        MediaItem(
          path: 'C:\\Media\\Music\\Skyfall.wav',
          title: 'Skyfall',
          artist: 'Music',
          kind: MediaKind.audio,
          duration: Duration(minutes: 4),
          colors: [Color(0xFF8B2E40), Color(0xFFBEC6D3), Color(0xFF2A2B35)],
        ),
        MediaItem(
          path: 'C:\\Media\\Music\\After.mp3',
          title: 'After',
          artist: 'Music',
          kind: MediaKind.audio,
          duration: Duration(minutes: 2),
          colors: [Color(0xFFB7F257), Color(0xFF07A755), Color(0xFF12302A)],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'sky');
    await tester.pumpAndSettle();

    await controller.activateSelected('sky');

    expect(playback.openedItem?.title, 'Skyfall');
    expect(playback._queue.map((item) => item.title), [
      'Before',
      'Skyfall',
      'After',
    ]);

    await controller.playNext('sky');
    expect(playback.openedItem?.title, 'After');

    await controller.playNext('sky');
    expect(playback.openedItem?.title, 'After');
  });

  testWidgets('search field arrows move selection and Enter plays it', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(playback.openedItem?.title, 'Skyfall');
  });

  testWidgets('empty search results ignore keyboard playback safely', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'no results here');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(playback.openedItem, isNull);
  });

  testWidgets('search focus blocks shifted app shortcuts', (tester) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isTrue);
    expect(playback.snapshot.loop, isFalse);
  });

  testWidgets('shuffle defaults on and playback toggles support shortcuts', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isTrue);
    final shuffleButton = find.descendant(
      of: find.byTooltip('Shuffle'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(shuffleButton).isSelected, isTrue);
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byTooltip('Next'),
              matching: find.byType(IconButton),
            ),
          )
          .isSelected,
      isNull,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isFalse);
    expect(tester.widget<IconButton>(shuffleButton).isSelected, isFalse);
    expect(playback.snapshot.loop, isFalse);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pumpAndSettle();
    expect(playback.snapshot.shuffle, isTrue);
    expect(tester.widget<IconButton>(shuffleButton).isSelected, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isTrue);
    expect(playback.snapshot.loop, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isTrue);
    expect(playback.snapshot.loop, isFalse);
  });

  testWidgets('keyboard shortcuts move selection and call playback', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(playback.openedItem?.title, 'Skyfall');
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('number keys seek by media percentage outside search', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pumpAndSettle();

    expect(playback.snapshot.position, const Duration(seconds: 93));

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pumpAndSettle();

    expect(playback.snapshot.position, const Duration(seconds: 93));
  });

  testWidgets('non-performance visualizer keeps keyboard playback controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    controller.updateVisualizerSettings(
      const VisualizerSettings(enabled: true, performanceMode: false),
    );
    controller.showFullPlayer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Take Me Down'), findsWidgets);
    expect(playback.snapshot.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(playback.snapshot.playing, isFalse);
  });

  testWidgets('folder picker adds folders and rescans library', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      folderPicker: _FakeFolderPicker(),
      initialFolders: const [],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add folder').first);
    await tester.pumpAndSettle();

    expect(find.text('C:\\Media'), findsOneWidget);
    expect(find.textContaining('2 audio files and 1 videos'), findsOneWidget);
  });

  test('library service initializes Windows defaults once', () async {
    final repository = MemoryLibrarySettingsRepository.uninitialized();
    final service = MediaLibraryService(
      settingsRepository: repository,
      folderPicker: const _NullFolderPicker(),
      scanner: const StaticMediaScanner(_sampleItems),
      defaultLibraryFolders: const _FakeDefaultLibraryFolders([
        'C:\\Users\\Tester\\Music',
        'C:\\Users\\Tester\\Videos',
      ]),
    );

    final folders = await service.loadFolders();

    expect(folders, ['C:\\Users\\Tester\\Music', 'C:\\Users\\Tester\\Videos']);

    await service.removeFolder(folders, 'C:\\Users\\Tester\\Music');
    final afterRemoval = await service.loadFolders();

    expect(afterRemoval, ['C:\\Users\\Tester\\Videos']);
  });

  test('library service preserves existing user folders', () async {
    final service = MediaLibraryService(
      settingsRepository: MemoryLibrarySettingsRepository(['D:\\Media']),
      folderPicker: const _NullFolderPicker(),
      scanner: const StaticMediaScanner(_sampleItems),
      defaultLibraryFolders: const _FakeDefaultLibraryFolders([
        'C:\\Users\\Tester\\Music',
        'C:\\Users\\Tester\\Videos',
      ]),
    );

    final folders = await service.loadFolders();

    expect(folders, ['D:\\Media']);
  });

  testWidgets('metadata service fills duration and thumbnails after scan', (
    tester,
  ) async {
    final controller = _testController(
      metadataService: _FakeMetadataService(),
      initialItems: const [
        MediaItem(
          path: 'C:\\Media\\Videos\\clip.mp4',
          title: 'clip',
          artist: 'VIDEO',
          kind: MediaKind.video,
          colors: [Color(0xFFB7F257), Color(0xFF07A755), Color(0xFF12302A)],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    controller.selectTab(MediaKind.video);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.text('0:42'), findsWidgets);
    expect(controller.items.single.thumbnailPath, 'C:\\Cache\\clip.jpg');
  });

  testWidgets('Playlists page renders default Favourites playlist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('No tracks yet'), findsOneWidget);
  });

  testWidgets('Playlists page stays bounded at desktop viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No tracks yet'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add Selected'), findsOneWidget);
  });

  testWidgets('Playlists page stays bounded at smaller desktop viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(980, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Playlists'), findsWidgets);
    expect(find.text('No tracks yet'), findsOneWidget);
  });

  testWidgets('playlist create uses inline editor without overlay exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('playlist-create-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('playlist-create-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('playlist-create-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('playlist-create-field')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist inline create supports save button and enter key', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('playlist-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-create-field')),
      'Road',
    );
    await tester.tap(find.byKey(const ValueKey('playlist-create-save')));
    await tester.pumpAndSettle();

    expect(find.text('Road'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('playlist-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-create-field')),
      'Night',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Night'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist arrow shortcuts move selection without leaving page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(id: 'playlist_road', name: 'Road', entries: []),
        const Playlist(id: 'playlist_night', name: 'Night', entries: []),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(controller.selectedPlaylistId, Playlist.favouritesId);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(controller.selectedPlaylistId, 'playlist_road');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(controller.selectedPlaylistId, 'playlist_night');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(controller.selectedPlaylistId, 'playlist_road');
  });

  testWidgets('playlist create shortcut protects text field shortcuts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    await _sendCtrlKey(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();

    final createField = find.byKey(const ValueKey('playlist-create-field'));
    expect(createField, findsOneWidget);

    await tester.enterText(createField, 'Road');
    await _sendCtrlKey(tester, LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(createField, findsOneWidget);

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(createField, findsOneWidget);

    await tester.enterText(createField, 'Road');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(find.text('Road'), findsWidgets);

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    await tester.enterText(createField, 'Cancel Me');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(createField, findsNothing);
    expect(find.text('Cancel Me'), findsNothing);
    expect(controller.page, FumicPage.playlists);
  });

  testWidgets('playlist rename and delete shortcuts ignore Favourites', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(id: 'playlist_road', name: 'Road', entries: []),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();

    expect(controller.selectedPlaylistId, Playlist.favouritesId);

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('playlist-rename-field')), findsNothing);
    expect(find.text('Confirm Delete'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.selectedPlaylistId, 'playlist_road');

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();

    final renameField = find.byKey(const ValueKey('playlist-rename-field'));
    expect(renameField, findsOneWidget);

    await tester.enterText(renameField, 'Roadtrip');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Roadtrip'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Delete'), findsOneWidget);
    expect(controller.page, FumicPage.playlists);
  });

  testWidgets('playlist Enter plays and toggles selected playlist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(
      playback: playback,
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(
          id: 'playlist_road',
          name: 'Road',
          entries: [PlaylistEntry(path: 'C:\\Media\\Music\\Take Me Down.mp3')],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await _sendCtrlKey(tester, LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(controller.activePlaylistId, 'playlist_road');
    expect(playback.openQueueCount, 1);
    expect(playback.snapshot.playing, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.page, FumicPage.playlists);
    expect(playback.openQueueCount, 1);
    expect(playback.snapshot.playing, isFalse);
  });

  testWidgets('playlist Add Selected button adds and plays selected media', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Selected'));
    await tester.pumpAndSettle();

    expect(find.text('Take Me Down'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(playback.openedItem?.title, 'Take Me Down');
    expect(tester.takeException(), isNull);
  });

  testWidgets('active playlist button toggles playback without restarting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(
      playback: playback,
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(
          id: 'playlist_road',
          name: 'Road',
          entries: [
            PlaylistEntry(path: 'C:\\Media\\Music\\Take Me Down.mp3'),
            PlaylistEntry(path: 'C:\\Media\\Music\\Skyfall.wav'),
          ],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    controller.selectPlaylist('playlist_road');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(controller.activePlaylistId, 'playlist_road');
    expect(find.text('Playing'), findsOneWidget);
    expect(find.text('Active queue'), findsOneWidget);
    expect(find.text('Now playing'), findsOneWidget);

    final openCount = playback.openQueueCount;
    await tester.tap(find.widgetWithText(FilledButton, 'Playing'));
    await tester.pumpAndSettle();

    expect(playback.openQueueCount, openCount);
    expect(playback.snapshot.playing, isFalse);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('active playlist survives app navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(
          id: 'playlist_road',
          name: 'Road',
          entries: [PlaylistEntry(path: 'C:\\Media\\Music\\Take Me Down.mp3')],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    controller.selectPlaylist('playlist_road');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(controller.activePlaylistId, 'playlist_road');
    expect(find.text('Active queue'), findsOneWidget);
  });

  testWidgets('playing from the normal library clears active playlist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(
      playback: playback,
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(
          id: 'playlist_road',
          name: 'Road',
          entries: [PlaylistEntry(path: 'C:\\Media\\Music\\Take Me Down.mp3')],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    controller.selectPlaylist('playlist_road');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(controller.activePlaylistId, 'playlist_road');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(controller.activePlaylistId, isNull);
    expect(playback.openedItem?.title, 'Take Me Down');
  });

  testWidgets('Ctrl+B adds the selected item to Favourites', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(controller.playlists.first.entries.map((entry) => entry.path), [
      'C:\\Media\\Music\\Take Me Down.mp3',
    ]);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    expect(find.text('Take Me Down'), findsWidgets);
  });

  testWidgets('Ctrl+B dialog opens and closes without framework errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Add to playlist'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Add to playlist'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add to playlist'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+B dialog supports arrow selection and enter add', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(id: 'playlist_road', name: 'Road', entries: []),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Add to playlist'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final road = controller.playlists.firstWhere(
      (playlist) => playlist.id == 'playlist_road',
    );
    expect(road.entries.map((entry) => entry.path), [
      'C:\\Media\\Music\\Take Me Down.mp3',
    ]);
    expect(find.text('Add to playlist'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+Shift+B opens the playlist dialog from the visualizer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    controller.showFullPlayer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Add to playlist'), findsOneWidget);
    expect(find.text('Take Me Down'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.playlists.first.entries.map((entry) => entry.path), [
      'C:\\Media\\Music\\Take Me Down.mp3',
    ]);
    expect(find.text('Add to playlist'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+B works while search is focused', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'sky');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(controller.playlists.first.entries.map((entry) => entry.path), [
      'C:\\Media\\Music\\Skyfall.wav',
    ]);
  });

  test('controller manages playlists and plays resolved items', () async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await controller.loadLibrary();

    await controller.addItemToPlaylist(
      controller.items.first,
      Playlist.favouritesId,
    );
    await controller.addItemToPlaylist(
      controller.items.first,
      Playlist.favouritesId,
    );

    expect(controller.playlists.first.entries, hasLength(1));

    final road = await controller.createPlaylist('Road');
    await controller.renamePlaylist(road.id, 'Road Mix');
    await controller.addItemToPlaylist(controller.items[1], road.id);
    await controller.playPlaylist(road.id);

    expect(controller.activePlaylistId, road.id);
    expect(
      controller.playlists
          .firstWhere((playlist) => playlist.id == road.id)
          .name,
      'Road Mix',
    );
    expect(playback.openedItem?.title, 'Skyfall');

    await controller.activateSelected('');
    expect(controller.activePlaylistId, isNull);

    await controller.deletePlaylist(road.id);

    expect(
      controller.playlists.any((playlist) => playlist.id == road.id),
      isFalse,
    );
    expect(controller.playlists.first.name, Playlist.favouritesName);
  });

  test(
    'controller opens full player automatically for selected videos only',
    () async {
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);

      await controller.loadLibrary();

      await controller.activateSelected('');

      expect(playback.openedItem?.kind, MediaKind.audio);
      expect(controller.fullPlayer, isFalse);

      controller.selectTab(MediaKind.video);
      await controller.activateSelected('');

      expect(playback.openedItem?.kind, MediaKind.video);
      expect(controller.fullPlayer, isTrue);
    },
  );

  test(
    'controller starts selected audio after switching away from video',
    () async {
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);

      await controller.loadLibrary();

      controller.selectTab(MediaKind.video);
      await controller.activateSelected('');

      expect(playback.openedItem?.kind, MediaKind.video);
      expect(controller.fullPlayer, isTrue);

      controller.selectTab(MediaKind.audio);
      controller.selectItemByPath('C:\\Media\\Music\\Skyfall.wav', '');
      await controller.togglePlay('');

      expect(playback.openedItem?.title, 'Skyfall');
      expect(controller.selectedItem('')?.title, 'Skyfall');
      expect(controller.fullPlayer, isFalse);
    },
  );

  test(
    'controller next starts highlighted audio after stale video queue',
    () async {
      final playback = _FakePlaybackService();
      final controller = _testController(playback: playback);
      addTearDown(controller.dispose);

      await controller.loadLibrary();

      controller.selectTab(MediaKind.video);
      await controller.activateSelected('');

      controller.selectTab(MediaKind.audio);
      controller.selectItemByPath('C:\\Media\\Music\\Take Me Down.mp3', '');
      await controller.playNext('');

      expect(playback.openedItem?.title, 'Take Me Down');
      expect(controller.selectedItem('')?.title, 'Take Me Down');
      expect(controller.fullPlayer, isFalse);
    },
  );

  test('controller persists and resets custom background path', () async {
    final appSettings = MemoryAppSettingsRepository();
    final backgroundService = MemoryBackgroundImageService(
      nextPath: 'C:\\Fumic\\backgrounds\\custom_background.jpg',
    );
    final controller = _testController(
      appSettingsRepository: appSettings,
      backgroundImageService: backgroundService,
    );
    addTearDown(controller.dispose);

    await controller.loadLibrary();
    await controller.pickCustomBackground();

    expect(
      controller.visualizerSettings.customBackgroundPath,
      'C:\\Fumic\\backgrounds\\custom_background.jpg',
    );
    expect(
      (await appSettings.loadVisualizerSettings()).customBackgroundPath,
      'C:\\Fumic\\backgrounds\\custom_background.jpg',
    );

    await controller.resetCustomBackground();

    expect(controller.visualizerSettings.customBackgroundPath, isNull);
    expect(backgroundService.deletedPaths, [
      'C:\\Fumic\\backgrounds\\custom_background.jpg',
    ]);
  });

  testWidgets('Settings shows a clear missing custom background fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      appSettingsRepository: MemoryAppSettingsRepository(
        const VisualizerSettings(
          customBackgroundPath: 'C:\\Missing\\custom_background.jpg',
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Appearance'));
    await tester.pumpAndSettle();
    // File loading is asynchronous; let the missing-file reads complete before
    // asserting the error UI instead of depending on synchronous disk checks.
    for (var i = 0; i < 20 && find.text('Missing').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Appearance selects and loads the imported neon wallpapers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = MemoryAppSettingsRepository();
    final controller = _testController(appSettingsRepository: settings);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Appearance'));
    await tester.pumpAndSettle();
    for (final name in ['Sakura Night', 'Samurai Night', 'Matrix Rain']) {
      final choice = find.byTooltip(name);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(controller.visualizerSettings.background.name, name);
      expect((await settings.loadVisualizerSettings()).background.name, name);
      expect(
        (await rootBundle.load(
          controller.visualizerSettings.background.asset,
        )).lengthInBytes,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Appearance opacity controls update the app and saved preferences',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preferences = MemoryAppSettingsRepository();
      final controller = _testController(appSettingsRepository: preferences);
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Appearance'));
      await tester.pumpAndSettle();
      for (final key in ['card-opacity-slider', 'background-opacity-slider']) {
        final slider = find.byKey(ValueKey(key));
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        final rect = tester.getRect(slider);
        await tester.tapAt(
          Offset(rect.left + rect.width * 0.8, rect.center.dy),
        );
        await tester.pumpAndSettle();
      }
      final saved = await preferences.loadVisualizerSettings();
      expect(saved.effectiveCardOpacity, greaterThan(0.7));
      expect(saved.effectiveBackgroundOpacity, greaterThan(0.7));
      final overlay = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('background-dimming-overlay')),
      );
      expect(overlay.color.a, closeTo(saved.effectiveBackgroundOpacity, 0.005));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      final tile = find
          .ancestor(
            of: find.text('Skyfall').first,
            matching: find.byType(AnimatedContainer),
          )
          .first;
      final decoration =
          tester.widget<AnimatedContainer>(tile).decoration! as BoxDecoration;
      expect(decoration.color!.a, closeTo(saved.effectiveCardOpacity, 0.005));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected song cards have a stronger fill and a distinct playing indicator',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _testController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await controller.activateItemByPath(_sampleItems.first.path, '');
      controller.selectItemByPath(_sampleItems[1].path, '');
      await tester.pumpAndSettle();
      BoxDecoration decorationFor(String title) {
        final tile = find
            .ancestor(
              of: find.text(title).first,
              matching: find.byType(AnimatedContainer),
            )
            .first;
        return tester.widget<AnimatedContainer>(tile).decoration!
            as BoxDecoration;
      }

      final playing = decorationFor('Take Me Down');
      final selected = decorationFor('Skyfall');
      expect(selected.color, isNot(playing.color));
      expect(selected.color!.a, greaterThanOrEqualTo(0.85));
      expect((playing.border! as Border).top.color, FumicTheme.accent);
      expect((selected.border! as Border).top.color, FumicTheme.brand);
      expect(
        find.descendant(
          of: find.byType(HomeLibrary),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Settings playback controls update the active session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Playback'));
    await tester.pumpAndSettle();
    final previous = playback.snapshot.shuffle;
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(playback.snapshot.shuffle, !previous);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings disables spectrum controls when effects are off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _testController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Visualizer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(controller.visualizerSettings.enabled, isFalse);
    for (final control in tester.widgetList<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    )) {
      expect(control.onSelectionChanged, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing all folders can be cancelled before confirming', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _testController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.folders, isNotEmpty);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove all'));
    await tester.pumpAndSettle();
    expect(controller.folders, isEmpty);
    expect(controller.items, isEmpty);
  });

  testWidgets('Settings sections fit a smaller desktop window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _testController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    for (final section in ['Library', 'Appearance', 'Visualizer', 'Playback']) {
      final chip = find.widgetWithText(ChoiceChip, section);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: section);
    }
  });

  testWidgets(
    'right-clicking music offers a cover picker without starting playback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final covers = MemoryCoverArtRepository(
        nextPath: r'C:\Covers\chosen.jpg',
      );
      final playback = _FakePlaybackService();
      final controller = _testController(
        playback: playback,
        coverArtRepository: covers,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(FumicApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Skyfall').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose song cover'), findsOneWidget);
      await tester.tap(find.text('Choose song cover'));
      await tester.pumpAndSettle();
      expect(
        controller.items
            .firstWhere((item) => item.title == 'Skyfall')
            .thumbnailPath,
        covers.nextPath,
      );
      expect(playback.openedItem, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'custom covers survive rescan and restore the original artwork',
    () async {
      final covers = MemoryCoverArtRepository(
        nextPath: r'C:\Covers\chosen.jpg',
      );
      final original = _sampleItems.first.copyWith(
        thumbnailPath: r'C:\Embedded\original.jpg',
      );
      final controller = _testController(
        initialItems: [original],
        coverArtRepository: covers,
      );
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      await controller.changeCover(
        controller.items.single,
        CoverArtAction.chooseSong,
      );
      await controller.refreshLibrary();
      expect(controller.items.single.thumbnailPath, covers.nextPath);
      expect((await covers.load()).values.single, covers.nextPath);
      await controller.changeCover(
        controller.items.single,
        CoverArtAction.restoreSong,
      );
      expect(controller.items.single.thumbnailPath, original.thumbnailPath);
      expect(covers.covers, isEmpty);
      expect(covers.deletedPaths, [covers.nextPath]);
    },
  );

  test(
    'folder covers apply only to audio and shared files stay until unused',
    () async {
      final covers = MemoryCoverArtRepository(nextPath: r'C:\Covers\album.jpg');
      final controller = _testController(coverArtRepository: covers);
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      await controller.changeCover(
        controller.items.first,
        CoverArtAction.chooseFolder,
      );
      expect(
        controller.items
            .where((item) => item.kind == MediaKind.audio)
            .every((item) => item.thumbnailPath == covers.nextPath),
        isTrue,
      );
      expect(controller.items.last.thumbnailPath, isNull);
      await controller.changeCover(
        controller.items.first,
        CoverArtAction.restoreSong,
      );
      expect(covers.deletedPaths, isEmpty);
      await controller.changeCover(
        controller.items[1],
        CoverArtAction.restoreFolder,
      );
      expect(covers.covers, isEmpty);
      expect(covers.deletedPaths, [covers.nextPath]);
    },
  );

  test(
    'custom covers take precedence over later metadata and queued items',
    () async {
      final covers = MemoryCoverArtRepository(
        nextPath: r'C:\Covers\chosen.jpg',
      );
      final playback = _FakePlaybackService();
      final controller = _testController(
        initialItems: [_sampleItems.first],
        playback: playback,
        coverArtRepository: covers,
        metadataService: _FakeMetadataService(),
      );
      addTearDown(controller.dispose);
      await controller.loadLibrary();
      await controller.changeCover(
        controller.items.single,
        CoverArtAction.chooseSong,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.items.single.thumbnailPath, covers.nextPath);
      await playback.openQueue([_sampleItems.first], 0);
      expect(playback.snapshot.currentItem!.thumbnailPath, covers.nextPath);
      await controller.changeCover(
        controller.items.single,
        CoverArtAction.restoreSong,
      );
      expect(controller.items.single.thumbnailPath, r'C:\Cache\clip.jpg');
      expect(
        playback.snapshot.currentItem!.thumbnailPath,
        r'C:\Cache\clip.jpg',
      );
    },
  );

  test('cancelling cover selection preserves existing artwork', () async {
    final covers = MemoryCoverArtRepository();
    final controller = _testController(coverArtRepository: covers);
    addTearDown(controller.dispose);
    await controller.loadLibrary();
    final original = controller.items.first.thumbnailPath;
    await controller.changeCover(
      controller.items.first,
      CoverArtAction.chooseSong,
    );
    expect(controller.items.first.thumbnailPath, original);
    expect(covers.covers, isEmpty);
  });

  test('older library scans cannot replace a newer result', () async {
    final scanner = _DeferredScanner();
    final controller = _testController(scanner: scanner);
    addTearDown(controller.dispose);
    final first = controller.refreshLibrary();
    final second = controller.refreshLibrary();
    scanner.pending[1].complete([_sampleItems.first]);
    await second;
    scanner.pending[0].complete([_sampleItems.last]);
    await first;
    expect(controller.items.single.path, _sampleItems.first.path);
    expect(controller.scanning, isFalse);
  });

  test('a pending scan cannot restore a cleared library', () async {
    final scanner = _DeferredScanner();
    final controller = _testController(scanner: scanner);
    addTearDown(controller.dispose);
    final scan = controller.refreshLibrary();
    await controller.clearFolders();
    scanner.pending.single.complete(_sampleItems);
    await scan;
    expect(controller.items, isEmpty);
    expect(controller.scanning, isFalse);
  });

  testWidgets('Playlists page handles long names and missing files', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1418, 977));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController(
      playlistRepository: MemoryPlaylistRepository([
        const Playlist(
          id: 'playlist_long',
          name:
              'A very long playlist name that should not break the toolbar or rail layout',
          entries: [
            PlaylistEntry(path: 'C:\\Missing\\song-that-is-not-scanned.mp3'),
          ],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    controller.selectPlaylist('playlist_long');
    await tester.pumpAndSettle();

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _sendCtrlKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
}

FumicController _testController({
  PlaybackService? playback,
  MediaScanner? scanner,
  CoverArtRepository? coverArtRepository,
  FolderPickerService? folderPicker,
  AppSettingsRepository? appSettingsRepository,
  PlaylistRepository? playlistRepository,
  BackgroundImageService? backgroundImageService,
  MediaMetadataService metadataService = const NoopMediaMetadataService(),
  List<String> initialFolders = const ['C:\\Media'],
  List<MediaItem> initialItems = _sampleItems,
}) {
  return FumicController(
    coverArtRepository: coverArtRepository ?? MemoryCoverArtRepository(),
    libraryService: MediaLibraryService(
      settingsRepository: MemoryLibrarySettingsRepository(initialFolders),
      folderPicker: folderPicker ?? const _NullFolderPicker(),
      scanner: scanner ?? StaticMediaScanner(initialItems),
    ),
    playbackService: playback ?? _FakePlaybackService(),
    appSettingsRepository:
        appSettingsRepository ?? MemoryAppSettingsRepository(),
    playlistRepository: playlistRepository ?? MemoryPlaylistRepository(),
    backgroundImageService:
        backgroundImageService ?? MemoryBackgroundImageService(),
    metadataService: metadataService,
  );
}

const _sampleItems = [
  MediaItem(
    path: 'C:\\Media\\Music\\Take Me Down.mp3',
    title: 'Take Me Down',
    artist: 'Music',
    kind: MediaKind.audio,
    duration: Duration(minutes: 3, seconds: 6),
    colors: [Color(0xFF915923), Color(0xFF1F5E99), Color(0xFF101821)],
  ),
  MediaItem(
    path: 'C:\\Media\\Music\\Skyfall.wav',
    title: 'Skyfall',
    artist: 'Music',
    kind: MediaKind.audio,
    duration: Duration(minutes: 4, seconds: 44),
    colors: [Color(0xFF8B2E40), Color(0xFFBEC6D3), Color(0xFF2A2B35)],
  ),
  MediaItem(
    path: 'C:\\Media\\Videos\\2026-01-17 13-06-00.mp4',
    title: '2026-01-17 13-06-00',
    artist: 'VIDEO',
    kind: MediaKind.video,
    duration: Duration(seconds: 1),
    colors: [Color(0xFFB7F257), Color(0xFF07A755), Color(0xFF12302A)],
  ),
];

class _FailingAppearanceRepository extends MemoryAppSettingsRepository {
  _FailingAppearanceRepository(super.settings);
  bool failNext = false;

  @override
  Future<void> saveVisualizerSettings(VisualizerSettings settings) async {
    if (failNext) {
      failNext = false;
      throw StateError('disk full');
    }
    await super.saveVisualizerSettings(settings);
  }
}

class _DeferredBackgroundService extends MemoryBackgroundImageService {
  final pending = Completer<String?>();
  int picks = 0;

  @override
  Future<String?> pickAndStoreCustomBackground() {
    picks++;
    return pending.future;
  }
}

class _InvalidBackgroundService extends MemoryBackgroundImageService {
  @override
  Future<String?> pickAndStoreCustomBackground() async {
    throw const FormatException('Choose a wallpaper smaller than 24 MB.');
  }
}

class _NullFolderPicker implements FolderPickerService {
  const _NullFolderPicker();

  @override
  Future<String?> pickFolder() async => null;
}

class _FakeFolderPicker implements FolderPickerService {
  @override
  Future<String?> pickFolder() async => 'C:\\Media';
}

class _FakeDefaultLibraryFolders implements DefaultLibraryFolderProvider {
  const _FakeDefaultLibraryFolders(this.folders);

  final List<String> folders;

  @override
  Future<List<String>> defaultFolders() async => folders;
}

class _FakePlaybackService extends PlaybackService {
  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  MediaItem? openedItem;
  int openQueueCount = 0;
  List<MediaItem> _queue = const [];
  int _index = -1;

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Future<void> openQueue(
    List<MediaItem> queue,
    int index, {
    bool play = true,
  }) async {
    _queue = List<MediaItem>.from(queue);
    _index = index;
    openQueueCount++;
    openedItem = queue[index];
    _snapshot = _snapshot.copyWith(
      currentItem: openedItem,
      playing: play,
      duration: openedItem?.duration ?? Duration.zero,
    );
    notifyListeners();
  }

  @override
  Future<void> playNext() async {
    if (_queue.isEmpty) {
      return;
    }
    _index = (_index + 1).clamp(0, _queue.length - 1);
    await openQueue(_queue, _index);
  }

  @override
  Future<void> playPrevious() async {
    if (_queue.isEmpty) {
      return;
    }
    _index = (_index - 1).clamp(0, _queue.length - 1);
    await openQueue(_queue, _index);
  }

  @override
  Future<void> seekRelative(Duration delta) async {
    _snapshot = _snapshot.copyWith(position: _snapshot.position + delta);
    notifyListeners();
  }

  @override
  Future<void> setLoop(bool value) async {
    _snapshot = _snapshot.copyWith(loop: value);
    notifyListeners();
  }

  @override
  Future<void> setShuffle(bool value) async {
    _snapshot = _snapshot.copyWith(shuffle: value);
    notifyListeners();
  }

  @override
  Future<void> setVolume(double value) async {
    _snapshot = _snapshot.copyWith(volume: value.clamp(0, 1));
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double value) async {
    _snapshot = _snapshot.copyWith(speed: value.clamp(0.5, 3.0));
    notifyListeners();
  }

  @override
  Future<void> togglePlay() async {
    _snapshot = _snapshot.copyWith(playing: !_snapshot.playing);
    notifyListeners();
  }

  @override
  void updateCurrentItem(MediaItem item) {
    if (_snapshot.currentItem?.path == item.path) {
      _snapshot = _snapshot.copyWith(currentItem: item);
      notifyListeners();
    }
  }
}

class _FakeMetadataService implements MediaMetadataService {
  @override
  Future<void> enrich({
    required List<MediaItem> items,
    required void Function(MediaMetadata metadata) onMetadata,
    required bool Function() isCancelled,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (isCancelled()) {
      return;
    }
    onMetadata(
      MediaMetadata(
        path: items.single.path,
        duration: const Duration(seconds: 42),
        thumbnailPath: 'C:\\Cache\\clip.jpg',
      ),
    );
  }
}

class _DeferredScanner implements MediaScanner {
  final pending = <Completer<List<MediaItem>>>[];
  @override
  Future<List<MediaItem>> scanFolders(List<String> folders) {
    final result = Completer<List<MediaItem>>();
    pending.add(result);
    return result.future;
  }
}
