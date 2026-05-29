import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fumic/src/app/fumic_app.dart';
import 'package:fumic/src/app/fumic_controller.dart';
import 'package:fumic/src/models/media_item.dart';
import 'package:fumic/src/models/media_kind.dart';
import 'package:fumic/src/models/playlist.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/services/app_settings_repository.dart';
import 'package:fumic/src/services/background_image_service.dart';
import 'package:fumic/src/services/folder_picker_service.dart';
import 'package:fumic/src/services/library_settings_repository.dart';
import 'package:fumic/src/services/media_library_service.dart';
import 'package:fumic/src/services/media_metadata_service.dart';
import 'package:fumic/src/services/media_scanner.dart';
import 'package:fumic/src/services/playlist_repository.dart';
import 'package:fumic/src/services/playback_service.dart';

void main() {
  testWidgets('Fumic shell renders library and navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _testController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

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

    expect(find.text('The Magical Media Player (FOSS)'), findsOneWidget);
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

    expect(playback.snapshot.shuffle, isFalse);
    expect(playback.snapshot.loop, isFalse);
  });

  testWidgets('shuffle and loop shortcuts update playback state', (
    tester,
  ) async {
    final playback = _FakePlaybackService();
    final controller = _testController(playback: playback);
    addTearDown(controller.dispose);

    await tester.pumpWidget(FumicApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(playback.snapshot.shuffle, isTrue);
    expect(playback.snapshot.loop, isFalse);

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

  testWidgets('Ctrl+B dialog works from visualizer with keyboard controls', (
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
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
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

    expect(find.text('Missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

FumicController _testController({
  PlaybackService? playback,
  FolderPickerService? folderPicker,
  AppSettingsRepository? appSettingsRepository,
  PlaylistRepository? playlistRepository,
  BackgroundImageService backgroundImageService =
      const FilePickerBackgroundImageService(),
  MediaMetadataService metadataService = const NoopMediaMetadataService(),
  List<String> initialFolders = const ['C:\\Media'],
  List<MediaItem> initialItems = _sampleItems,
}) {
  return FumicController(
    libraryService: MediaLibraryService(
      settingsRepository: MemoryLibrarySettingsRepository(initialFolders),
      folderPicker: folderPicker ?? const _NullFolderPicker(),
      scanner: StaticMediaScanner(initialItems),
    ),
    playbackService: playback ?? _FakePlaybackService(),
    appSettingsRepository:
        appSettingsRepository ?? MemoryAppSettingsRepository(),
    playlistRepository: playlistRepository ?? MemoryPlaylistRepository(),
    backgroundImageService: backgroundImageService,
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
