import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/services/embedded_artwork_extractor.dart';

void main() {
  test('extracts embedded MP3 ID3 artwork', () async {
    final directory = await Directory.systemTemp.createTemp('fumic_artwork_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}song.mp3');
    final artwork = Uint8List.fromList(_onePixelPng);
    await file.writeAsBytes(_id3v23TagWithApic(artwork));

    final result = await const EmbeddedArtworkExtractor().extract(file.path);

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/png');
    expect(result.bytes, artwork);
  });

  test('extracts native FLAC picture artwork', () async {
    final directory = await Directory.systemTemp.createTemp('fumic_artwork_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}song.flac');
    final artwork = Uint8List.fromList(_onePixelPng);
    await file.writeAsBytes(_flacWithPictureBlock(artwork));

    final result = await const EmbeddedArtworkExtractor().extract(file.path);

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/png');
    expect(result.bytes, artwork);
  });

  test('extracts M4A covr artwork', () async {
    final directory = await Directory.systemTemp.createTemp('fumic_artwork_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}song.m4a');
    final artwork = Uint8List.fromList(_onePixelPng);
    await file.writeAsBytes(_m4aWithCover(artwork));

    final result = await const EmbeddedArtworkExtractor().extract(file.path);

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/png');
    expect(result.bytes, artwork);
  });

  test('extracts OPUS metadata block picture artwork', () async {
    final directory = await Directory.systemTemp.createTemp('fumic_artwork_');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}${Platform.pathSeparator}song.opus');
    final artwork = Uint8List.fromList(_onePixelPng);
    await file.writeAsBytes(_opusWithPictureComment(artwork));

    final result = await const EmbeddedArtworkExtractor().extract(file.path);

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/png');
    expect(result.bytes, artwork);
  });
}

List<int> _id3v23TagWithApic(List<int> artwork) {
  final frameData = <int>[0, ...ascii.encode('image/png'), 0, 3, 0, ...artwork];
  final frame = <int>[
    ...ascii.encode('APIC'),
    ..._uint32Be(frameData.length),
    0,
    0,
    ...frameData,
  ];
  return <int>[
    ...ascii.encode('ID3'),
    3,
    0,
    0,
    ..._synchsafe(frame.length),
    ...frame,
  ];
}

List<int> _uint32Be(int value) {
  return [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

List<int> _uint32Le(int value) {
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}

List<int> _uint24Be(int value) {
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

List<int> _synchsafe(int value) {
  return [
    (value >> 21) & 0x7f,
    (value >> 14) & 0x7f,
    (value >> 7) & 0x7f,
    value & 0x7f,
  ];
}

List<int> _flacWithPictureBlock(List<int> artwork) {
  final mime = ascii.encode('image/png');
  final picture = <int>[
    ..._uint32Be(3),
    ..._uint32Be(mime.length),
    ...mime,
    ..._uint32Be(0),
    ..._uint32Be(1),
    ..._uint32Be(1),
    ..._uint32Be(24),
    ..._uint32Be(0),
    ..._uint32Be(artwork.length),
    ...artwork,
  ];
  return [
    ...ascii.encode('fLaC'),
    0x80 | 6,
    ..._uint24Be(picture.length),
    ...picture,
  ];
}

List<int> _m4aWithCover(List<int> artwork) {
  final data = _atom('data', [..._uint32Be(14), ..._uint32Be(0), ...artwork]);
  final covr = _atom('covr', data);
  final ilst = _atom('ilst', covr);
  final meta = _atom('meta', [..._uint32Be(0), ...ilst]);
  final udta = _atom('udta', meta);
  final moov = _atom('moov', udta);
  return [..._atom('ftyp', ascii.encode('M4A ')), ...moov];
}

List<int> _opusWithPictureComment(List<int> artwork) {
  final picture = _flacPictureBlock(artwork);
  final comment =
      'METADATA_BLOCK_PICTURE=${base64Encode(Uint8List.fromList(picture))}';
  final vendor = ascii.encode('fumic-test');
  final commentBytes = utf8.encode(comment);
  final tags = <int>[
    ...ascii.encode('OpusTags'),
    ..._uint32Le(vendor.length),
    ...vendor,
    ..._uint32Le(1),
    ..._uint32Le(commentBytes.length),
    ...commentBytes,
  ];
  return [
    ..._oggPage(ascii.encode('OpusHead'), sequence: 0),
    ..._oggPage(tags, sequence: 1),
  ];
}

List<int> _flacPictureBlock(List<int> artwork) {
  final mime = ascii.encode('image/png');
  return <int>[
    ..._uint32Be(3),
    ..._uint32Be(mime.length),
    ...mime,
    ..._uint32Be(0),
    ..._uint32Be(1),
    ..._uint32Be(1),
    ..._uint32Be(24),
    ..._uint32Be(0),
    ..._uint32Be(artwork.length),
    ...artwork,
  ];
}

List<int> _oggPage(List<int> packet, {required int sequence}) {
  final segments = <int>[];
  var remaining = packet.length;
  while (remaining >= 255) {
    segments.add(255);
    remaining -= 255;
  }
  segments.add(remaining);
  return [
    ...ascii.encode('OggS'),
    0,
    0,
    ...List<int>.filled(8, 0),
    1,
    0,
    0,
    0,
    ..._uint32Le(sequence),
    ...List<int>.filled(4, 0),
    segments.length,
    ...segments,
    ...packet,
  ];
}

List<int> _atom(String type, List<int> payload) {
  return [..._uint32Be(payload.length + 8), ...ascii.encode(type), ...payload];
}

const _onePixelPng = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
