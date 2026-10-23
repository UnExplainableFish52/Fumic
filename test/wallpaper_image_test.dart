import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/widgets/wallpaper_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every wallpaper preset references a bundled image', () async {
    for (final preset in VisualizerBackground.presets) {
      expect(
        (await rootBundle.load(preset.asset)).lengthInBytes,
        greaterThan(0),
        reason: '${preset.name} must be registered under flutter.assets',
      );
    }
    expect(VisualizerBackground.presets.first.id, 'fumic');
    expect(VisualizerBackground.presets[1].name, 'Tanjiro');
    expect(VisualizerBackground.presets[5].name, 'Night Girl');
  });

  testWidgets('replaced wallpapers leave the cache without clearing artwork', (
    tester,
  ) async {
    Future<void> show(int index) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WallpaperImage(
            settings: VisualizerSettings(backgroundIndex: index),
          ),
        ),
      );
      final context = tester.element(find.byType(WallpaperImage));
      final provider = tester.widget<Image>(find.byType(Image)).image;
      await tester.runAsync(() => precacheImage(provider, context));
      await tester.pumpAndSettle();
    }

    await show(0);
    final context = tester.element(find.byType(WallpaperImage));
    final configuration = createLocalImageConfiguration(context);
    final oldProvider = tester.widget<Image>(find.byType(Image)).image;
    final oldKey = await oldProvider.obtainKey(configuration);
    const artwork = AssetImage('icons/icon.png');
    await tester.runAsync(() => precacheImage(artwork, context));
    final artKey = await artwork.obtainKey(configuration);
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.statusForKey(oldKey).keepAlive, isTrue);
    expect(cache.statusForKey(artKey).keepAlive, isTrue);
    await show(1);
    expect(cache.statusForKey(oldKey).keepAlive, isFalse);
    expect(cache.statusForKey(artKey).keepAlive, isTrue);
    final current = tester.widget<Image>(find.byType(Image)).image;
    final currentKey = await current.obtainKey(configuration);
    expect(cache.statusForKey(currentKey).keepAlive, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cache.statusForKey(currentKey).keepAlive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the settings preview retains the active wallpaper', (
    tester,
  ) async {
    const settings = VisualizerSettings(backgroundIndex: 0);
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Expanded(
              child: WallpaperImage(key: ValueKey('main'), settings: settings),
            ),
            Expanded(
              child: WallpaperImage(
                key: ValueKey('preview'),
                settings: settings,
                cacheWidth: 1200,
              ),
            ),
          ],
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final context = tester.element(find.byKey(const ValueKey('main')));
    for (final image in images) {
      await tester.runAsync(() => precacheImage(image.image, context));
    }
    await tester.pumpAndSettle();
    final configuration = createLocalImageConfiguration(context);
    final mainKey = await images[0].image.obtainKey(configuration);
    final previewKey = await images[1].image.obtainKey(configuration);
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Expanded(
              child: WallpaperImage(key: ValueKey('main'), settings: settings),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.statusForKey(mainKey).keepAlive, isTrue);
    expect(cache.statusForKey(previewKey).keepAlive, isFalse);
    expect(tester.takeException(), isNull);
  });
}
