import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/services/background_image_service.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('fumic_backgrounds_');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('custom background reset does not delete arbitrary paths', () async {
    final service = FilePickerBackgroundImageService(
      supportDirectory: tempDirectory,
    );
    final unrelated = File(p.join(tempDirectory.path, 'unrelated.txt'));
    await unrelated.writeAsString('keep');

    await service.deleteCustomBackground(unrelated.path);

    expect(await unrelated.exists(), isTrue);
  });

  test('custom background reset deletes the managed background file', () async {
    final service = FilePickerBackgroundImageService(
      supportDirectory: tempDirectory,
    );
    final managed = File(
      p.join(tempDirectory.path, 'backgrounds', 'custom_background.jpg'),
    );
    await managed.parent.create(recursive: true);
    await managed.writeAsString('custom background');

    await service.deleteCustomBackground(managed.path);

    expect(await managed.exists(), isFalse);
  });

  test(
    'imports use fresh paths, normalize size, and preserve originals',
    () async {
      final service = FilePickerBackgroundImageService(
        supportDirectory: tempDirectory,
      );
      final source = File(p.join(tempDirectory.path, 'original.png'));
      final original = img.encodePng(img.Image(width: 2200, height: 22));
      await source.writeAsBytes(original);
      final first = (await service.storeCustomBackground(source))!;
      final second = (await service.storeCustomBackground(source))!;
      expect(second, isNot(first));
      final decoded = img.decodeJpg(await File(first).readAsBytes())!;
      expect(decoded.width, 1920);
      expect(decoded.height, lessThanOrEqualTo(22));
      expect(await source.readAsBytes(), original);
      expect(await File(first).exists(), isTrue);
      expect(await File(second).exists(), isTrue);
      expect(
        await Directory(
          p.dirname(first),
        ).list().where((file) => file.path.endsWith('.tmp')).length,
        0,
      );
    },
  );

  test('corrupt and huge decoded images are rejected before storing', () async {
    final service = FilePickerBackgroundImageService(
      supportDirectory: tempDirectory,
    );
    final source = File(p.join(tempDirectory.path, 'bad.png'));
    await source.writeAsString('not an image');
    await expectLater(
      service.storeCustomBackground(source),
      throwsFormatException,
    );
    await source.writeAsBytes(_pngWithDimensions(8192, 8192));
    await expectLater(
      service.storeCustomBackground(source),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('16 megapixels'),
        ),
      ),
    );
    expect(
      await Directory(p.join(tempDirectory.path, 'backgrounds')).exists(),
      isFalse,
    );
  });

  test('oversized files are rejected before reading or decoding', () async {
    final service = FilePickerBackgroundImageService(
      supportDirectory: tempDirectory,
    );
    final source = File(p.join(tempDirectory.path, 'oversized.png'));
    final handle = await source.open(mode: FileMode.write);
    await handle.truncate(FilePickerBackgroundImageService.maxFileBytes + 1);
    await handle.close();
    await expectLater(
      service.storeCustomBackground(source),
      throwsFormatException,
    );
  });

  test(
    'startup removes only obsolete managed files and interrupted imports',
    () async {
      final service = FilePickerBackgroundImageService(
        supportDirectory: tempDirectory,
      );
      final directory = Directory(p.join(tempDirectory.path, 'backgrounds'));
      await directory.create();
      final keep = File(
        p.join(directory.path, 'custom_background_123_abc.jpg'),
      );
      final old = File(p.join(directory.path, 'custom_background.jpg'));
      final partial = File(
        p.join(directory.path, 'custom_background_122_def.jpg.tmp'),
      );
      final unrelated = File(p.join(directory.path, 'personal.jpg'));
      for (final file in [keep, old, partial, unrelated]) {
        await file.writeAsString('image');
      }
      await service.cleanupUnusedBackgrounds(keep.path);
      expect(await keep.exists(), isTrue);
      expect(await old.exists(), isFalse);
      expect(await partial.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
      await service.cleanupUnusedBackgrounds(null);
      expect(await keep.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );
}

Uint8List _pngWithDimensions(int width, int height) {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8)),
  );
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, width);
  data.setUint32(20, height);
  var crc = 0xffffffff;
  for (var i = 12; i < 29; i++) {
    crc ^= bytes[i];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
    }
  }
  data.setUint32(29, crc ^ 0xffffffff);
  return bytes;
}
