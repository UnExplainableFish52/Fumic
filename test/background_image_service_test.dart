import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/services/background_image_service.dart';
import 'package:path/path.dart' as p;

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
}
