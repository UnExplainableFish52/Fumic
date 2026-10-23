import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/services/cover_art_repository.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late JsonCoverArtRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fumic_cover_test_');
    repository = JsonCoverArtRepository(supportDirectory: directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  test(
    'import copies and resizes artwork and reloads saved assignments',
    () async {
      final source = File(p.join(directory.path, 'original.png'));
      await source.writeAsBytes(
        img.encodePng(img.Image(width: 1400, height: 700)),
      );
      final path = await repository.storeCover(source);
      final secondPath = await repository.storeCover(source);
      expect(secondPath, isNot(path));
      final stored = img.decodeJpg(await File(path).readAsBytes())!;
      expect(stored.width, 1000);
      expect(stored.height, 500);
      await repository.save({'song.mp3': path});
      final reopened = JsonCoverArtRepository(supportDirectory: directory);
      expect(await reopened.load(), {'song.mp3': path});
      await repository.deleteManagedCover(path);
      expect(await File(path).exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await reopened.load(), isEmpty);
    },
  );

  test('unreadable images are rejected without producing a cover', () async {
    final source = File(p.join(directory.path, 'broken.png'));
    await source.writeAsString('not an image');
    await expectLater(repository.storeCover(source), throwsFormatException);
  });

  test(
    'cleanup preserves user images and the cover assignment index',
    () async {
      final unrelated = File(p.join(directory.path, 'album.jpg'));
      await unrelated.writeAsString('original image');
      await repository.save({});
      final index = File(
        p.join(directory.path, 'custom_covers', 'covers.json'),
      );
      await repository.deleteManagedCover(unrelated.path);
      await repository.deleteManagedCover(index.path);
      expect(await unrelated.exists(), isTrue);
      expect(await index.exists(), isTrue);
    },
  );
}
