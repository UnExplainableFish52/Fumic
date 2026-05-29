import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class EmbeddedArtwork {
  const EmbeddedArtwork({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class EmbeddedArtworkExtractor {
  const EmbeddedArtworkExtractor();

  static const _maxTagBytes = 24 * 1024 * 1024;
  static const _maxOggBytes = 12 * 1024 * 1024;
  static const _maxMp4Bytes = 32 * 1024 * 1024;

  Future<EmbeddedArtwork?> extract(String path) async {
    final extension = p.extension(path).toLowerCase();
    return switch (extension) {
      '.aac' => _extractId3Artwork(File(path)),
      '.aif' || '.aiff' => _extractAiffArtwork(File(path)),
      '.flac' => _extractFlacArtwork(File(path)),
      '.m4a' || '.m4b' || '.alac' => _extractMp4Artwork(File(path)),
      '.mp3' => _extractId3Artwork(File(path)),
      '.oga' || '.ogg' => _extractOggVorbisArtwork(File(path)),
      '.opus' => _extractOpusArtwork(File(path)),
      '.wav' => _extractWavArtwork(File(path)),
      _ => null,
    };
  }

  Future<EmbeddedArtwork?> _extractId3Artwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      if (await input.length() < 10) {
        return null;
      }
      final header = await input.read(10);
      if (!_startsWith(header, [0x49, 0x44, 0x33])) {
        return null;
      }
      final majorVersion = header[3];
      final flags = header[5];
      final tagSize = _synchsafeInt(header, 6);
      if (tagSize <= 0) {
        return null;
      }
      final bytesToRead = math.min(tagSize, _maxTagBytes);
      final tag = await input.read(bytesToRead);
      final data = (flags & 0x80) != 0 ? _removeUnsynchronisation(tag) : tag;
      return _artworkFromId3Tag(
        _skipId3ExtendedHeader(data, majorVersion, flags),
        majorVersion,
      );
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractWavArtwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      final length = await input.length();
      if (length < 12) {
        return null;
      }
      final header = await input.read(12);
      if (!_startsWith(header, [0x52, 0x49, 0x46, 0x46]) ||
          !_startsWith(header.sublist(8), [0x57, 0x41, 0x56, 0x45])) {
        return null;
      }

      var offset = 12;
      while (offset + 8 <= length) {
        await input.setPosition(offset);
        final chunkHeader = await input.read(8);
        if (chunkHeader.length < 8) {
          return null;
        }
        final id = ascii.decode(chunkHeader.sublist(0, 4), allowInvalid: true);
        final size = _uint32Le(chunkHeader, 4);
        final dataOffset = offset + 8;
        if (size < 0 || dataOffset + size > length) {
          return null;
        }
        if (id.toLowerCase() == 'id3 ' || id == 'ID3 ') {
          if (size > _maxTagBytes) {
            return null;
          }
          await input.setPosition(dataOffset);
          final data = await input.read(size);
          if (data.length >= 10 && _startsWith(data, [0x49, 0x44, 0x33])) {
            final majorVersion = data[3];
            final flags = data[5];
            final tagSize = math.min(_synchsafeInt(data, 6), data.length - 10);
            final tag = data.sublist(10, 10 + tagSize);
            return _artworkFromId3Tag(
              _skipId3ExtendedHeader(
                (flags & 0x80) != 0 ? _removeUnsynchronisation(tag) : tag,
                majorVersion,
                flags,
              ),
              majorVersion,
            );
          }
        }
        offset = dataOffset + size + (size.isOdd ? 1 : 0);
      }
      return null;
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractAiffArtwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      final length = await input.length();
      if (length < 12) {
        return null;
      }
      final header = await input.read(12);
      if (!_startsWith(header, ascii.encode('FORM')) ||
          !_startsWith(header.sublist(8), ascii.encode('AIFF')) &&
              !_startsWith(header.sublist(8), ascii.encode('AIFC'))) {
        return null;
      }

      var offset = 12;
      while (offset + 8 <= length) {
        await input.setPosition(offset);
        final chunkHeader = await input.read(8);
        if (chunkHeader.length < 8) {
          return null;
        }
        final id = ascii.decode(chunkHeader.sublist(0, 4), allowInvalid: true);
        final size = _uint32Be(chunkHeader, 4);
        final dataOffset = offset + 8;
        if (size <= 0 || dataOffset + size > length) {
          return null;
        }
        if (id == 'ID3 ') {
          if (size > _maxTagBytes) {
            return null;
          }
          await input.setPosition(dataOffset);
          final data = await input.read(size);
          if (data.length >= 10 && _startsWith(data, ascii.encode('ID3'))) {
            final majorVersion = data[3];
            final flags = data[5];
            final tagSize = math.min(_synchsafeInt(data, 6), data.length - 10);
            final tag = data.sublist(10, 10 + tagSize);
            return _artworkFromId3Tag(
              _skipId3ExtendedHeader(
                (flags & 0x80) != 0 ? _removeUnsynchronisation(tag) : tag,
                majorVersion,
                flags,
              ),
              majorVersion,
            );
          }
        }
        offset = dataOffset + size + (size.isOdd ? 1 : 0);
      }
      return null;
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractFlacArtwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      if (await input.length() < 8) {
        return null;
      }
      final header = await input.read(4);
      if (!_startsWith(header, ascii.encode('fLaC'))) {
        return null;
      }

      var bytesRead = 4;
      var lastBlock = false;
      while (!lastBlock && bytesRead < _maxTagBytes) {
        final blockHeader = await input.read(4);
        bytesRead += blockHeader.length;
        if (blockHeader.length < 4) {
          return null;
        }
        lastBlock = (blockHeader[0] & 0x80) != 0;
        final type = blockHeader[0] & 0x7f;
        final size = _uint24Be(blockHeader, 1);
        if (size <= 0 ||
            size > _maxTagBytes ||
            bytesRead + size > _maxTagBytes) {
          return null;
        }
        final data = await input.read(size);
        bytesRead += data.length;
        if (data.length < size) {
          return null;
        }
        if (type == 6) {
          return _artworkFromFlacPictureBlock(data);
        }
        if (type == 4) {
          final artwork = _artworkFromVorbisComments(data, 0);
          if (artwork != null) {
            return artwork;
          }
        }
      }
      return null;
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractMp4Artwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      final length = math.min(await input.length(), _maxMp4Bytes);
      final buffer = await input.read(length);
      return _artworkFromMp4Atoms(buffer, 0, buffer.length, insideCovr: false);
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractOpusArtwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      final length = math.min(await input.length(), _maxOggBytes);
      final buffer = await input.read(length);
      for (final packet in _readOggPackets(buffer)) {
        if (_startsWith(packet, ascii.encode('OpusTags'))) {
          return _artworkFromVorbisComments(packet, 8);
        }
      }
      return null;
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  Future<EmbeddedArtwork?> _extractOggVorbisArtwork(File file) async {
    RandomAccessFile? input;
    try {
      input = await file.open();
      final length = math.min(await input.length(), _maxOggBytes);
      final buffer = await input.read(length);
      final header = [0x03, ...ascii.encode('vorbis')];
      for (final packet in _readOggPackets(buffer)) {
        if (_startsWith(packet, header)) {
          return _artworkFromVorbisComments(packet, header.length);
        }
      }
      return null;
    } on Object {
      return null;
    } finally {
      await input?.close();
    }
  }

  EmbeddedArtwork? _artworkFromId3Tag(List<int> data, int majorVersion) {
    var offset = 0;
    while (offset < data.length) {
      final frame = _readId3Frame(data, offset, majorVersion);
      if (frame == null) {
        return null;
      }
      offset = frame.nextOffset;
      if (frame.id == 'APIC') {
        final artwork = _artworkFromApicFrame(frame.data);
        if (artwork != null) {
          return artwork;
        }
      } else if (frame.id == 'PIC') {
        final artwork = _artworkFromPicFrame(frame.data);
        if (artwork != null) {
          return artwork;
        }
      }
    }
    return null;
  }

  _Id3Frame? _readId3Frame(List<int> data, int offset, int majorVersion) {
    final headerSize = majorVersion == 2 ? 6 : 10;
    if (offset + headerSize > data.length) {
      return null;
    }
    final idLength = majorVersion == 2 ? 3 : 4;
    final idBytes = data.sublist(offset, offset + idLength);
    if (idBytes.every((byte) => byte == 0)) {
      return null;
    }
    final id = ascii.decode(idBytes, allowInvalid: true);
    final size = majorVersion == 2
        ? _uint24Be(data, offset + 3)
        : majorVersion == 4
        ? _synchsafeInt(data, offset + 4)
        : _uint32Be(data, offset + 4);
    if (size <= 0 || offset + headerSize + size > data.length) {
      return null;
    }
    var frameData = data.sublist(
      offset + headerSize,
      offset + headerSize + size,
    );
    if (majorVersion == 4 && headerSize == 10) {
      final flags = (data[offset + 8] << 8) | data[offset + 9];
      if ((flags & 0x0002) != 0) {
        frameData = _removeUnsynchronisation(frameData);
      }
      if ((flags & 0x0001) != 0 && frameData.length > 4) {
        frameData = frameData.sublist(4);
      }
    }
    return _Id3Frame(
      id: id,
      data: frameData,
      nextOffset: offset + headerSize + size,
    );
  }

  EmbeddedArtwork? _artworkFromApicFrame(List<int> data) {
    if (data.length < 5) {
      return null;
    }
    final encoding = data[0];
    final mimeEnd = _indexOfZero(data, 1);
    if (mimeEnd < 0 || mimeEnd + 2 >= data.length) {
      return null;
    }
    final mimeType = ascii
        .decode(data.sublist(1, mimeEnd), allowInvalid: true)
        .toLowerCase();
    var offset = mimeEnd + 2;
    offset = _skipEncodedText(data, offset, encoding);
    if (offset <= 0 || offset >= data.length) {
      return null;
    }
    return EmbeddedArtwork(
      bytes: Uint8List.fromList(data.sublist(offset)),
      mimeType: _cleanMimeType(mimeType, data.sublist(offset)),
    );
  }

  EmbeddedArtwork? _artworkFromPicFrame(List<int> data) {
    if (data.length < 6) {
      return null;
    }
    final encoding = data[0];
    final format = ascii
        .decode(data.sublist(1, 4), allowInvalid: true)
        .toLowerCase();
    var offset = 5;
    offset = _skipEncodedText(data, offset, encoding);
    if (offset <= 0 || offset >= data.length) {
      return null;
    }
    return EmbeddedArtwork(
      bytes: Uint8List.fromList(data.sublist(offset)),
      mimeType: switch (format) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'image/jpeg',
      },
    );
  }

  EmbeddedArtwork? _artworkFromVorbisComments(List<int> data, int offset) {
    if (offset + 4 > data.length) {
      return null;
    }
    final vendorLength = _uint32Le(data, offset);
    offset += 4 + vendorLength;
    if (vendorLength < 0 || offset + 4 > data.length) {
      return null;
    }
    final commentCount = _uint32Le(data, offset);
    offset += 4;
    for (var i = 0; i < commentCount && offset + 4 <= data.length; i++) {
      final length = _uint32Le(data, offset);
      offset += 4;
      if (length <= 0 || offset + length > data.length) {
        return null;
      }
      final commentBytes = data.sublist(offset, offset + length);
      offset += length;
      final comment = utf8.decode(commentBytes, allowMalformed: true);
      final separator = comment.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = comment.substring(0, separator).toUpperCase();
      final value = comment.substring(separator + 1).trim();
      if (key == 'METADATA_BLOCK_PICTURE') {
        final artwork = _artworkFromFlacPictureBlock(base64Decode(value));
        if (artwork != null) {
          return artwork;
        }
      } else if (key == 'COVERART') {
        final bytes = Uint8List.fromList(base64Decode(value));
        return EmbeddedArtwork(
          bytes: bytes,
          mimeType: _cleanMimeType('image/jpeg', bytes),
        );
      }
    }
    return null;
  }

  EmbeddedArtwork? _artworkFromFlacPictureBlock(List<int> data) {
    if (data.length < 32) {
      return null;
    }
    var offset = 4;
    final mimeLength = _uint32Be(data, offset);
    offset += 4;
    if (offset + mimeLength + 4 > data.length) {
      return null;
    }
    final mimeType = ascii
        .decode(data.sublist(offset, offset + mimeLength), allowInvalid: true)
        .toLowerCase();
    offset += mimeLength;
    final descriptionLength = _uint32Be(data, offset);
    offset += 4 + descriptionLength;
    if (offset + 20 > data.length) {
      return null;
    }
    offset += 16;
    final pictureLength = _uint32Be(data, offset);
    offset += 4;
    if (pictureLength <= 0 || offset + pictureLength > data.length) {
      return null;
    }
    return EmbeddedArtwork(
      bytes: Uint8List.fromList(data.sublist(offset, offset + pictureLength)),
      mimeType: _cleanMimeType(
        mimeType,
        data.sublist(offset, offset + pictureLength),
      ),
    );
  }

  EmbeddedArtwork? _artworkFromMp4Atoms(
    List<int> data,
    int start,
    int end, {
    required bool insideCovr,
  }) {
    var offset = start;
    while (offset + 8 <= end) {
      final boxStart = offset;
      var size = _uint32Be(data, offset);
      final type = ascii.decode(
        data.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      offset += 8;
      if (size == 1) {
        if (offset + 8 > end) {
          return null;
        }
        size = _uint64Be(data, offset);
        offset += 8;
      } else if (size == 0) {
        size = end - boxStart;
      }
      final boxEnd = boxStart + size;
      if (size < offset - boxStart || boxEnd > end) {
        return null;
      }

      if (type == 'data' && insideCovr && offset + 8 <= boxEnd) {
        final format = _uint32Be(data, offset);
        final imageOffset = offset + 8;
        final bytes = data.sublist(imageOffset, boxEnd);
        if (bytes.length > 16) {
          return EmbeddedArtwork(
            bytes: Uint8List.fromList(bytes),
            mimeType: switch (format) {
              14 => 'image/png',
              13 => 'image/jpeg',
              _ => _cleanMimeType('', bytes),
            },
          );
        }
      }

      final childStart = type == 'meta' && offset + 4 <= boxEnd
          ? offset + 4
          : offset;
      if (_isMp4Container(type)) {
        final artwork = _artworkFromMp4Atoms(
          data,
          childStart,
          boxEnd,
          insideCovr: insideCovr || type == 'covr',
        );
        if (artwork != null) {
          return artwork;
        }
      }
      offset = boxEnd;
    }
    return null;
  }

  bool _isMp4Container(String type) {
    return const {'moov', 'udta', 'meta', 'ilst', 'covr'}.contains(type);
  }

  List<List<int>> _readOggPackets(List<int> data) {
    final packets = <List<int>>[];
    final current = <int>[];
    var offset = 0;

    while (offset + 27 <= data.length && packets.length < 12) {
      if (!_startsWithAt(data, ascii.encode('OggS'), offset)) {
        break;
      }
      final segmentCount = data[offset + 26];
      final segmentTableOffset = offset + 27;
      final payloadOffset = segmentTableOffset + segmentCount;
      if (payloadOffset > data.length) {
        break;
      }

      var payloadSize = 0;
      for (var i = 0; i < segmentCount; i++) {
        payloadSize += data[segmentTableOffset + i];
      }
      if (payloadOffset + payloadSize > data.length) {
        break;
      }

      var segmentPayloadOffset = payloadOffset;
      for (var i = 0; i < segmentCount; i++) {
        final segmentSize = data[segmentTableOffset + i];
        current.addAll(
          data.sublist(
            segmentPayloadOffset,
            segmentPayloadOffset + segmentSize,
          ),
        );
        segmentPayloadOffset += segmentSize;
        if (segmentSize < 255) {
          packets.add(List<int>.from(current));
          current.clear();
          if (packets.length >= 12) {
            break;
          }
        }
      }

      offset = payloadOffset + payloadSize;
    }

    return packets;
  }

  int _skipEncodedText(List<int> data, int offset, int encoding) {
    if (encoding == 1 || encoding == 2) {
      for (var i = offset; i + 1 < data.length; i += 2) {
        if (data[i] == 0 && data[i + 1] == 0) {
          return i + 2;
        }
      }
      return -1;
    }
    final end = _indexOfZero(data, offset);
    return end < 0 ? -1 : end + 1;
  }

  List<int> _skipId3ExtendedHeader(
    List<int> data,
    int majorVersion,
    int flags,
  ) {
    if ((flags & 0x40) == 0 || data.length < 4) {
      return data;
    }
    final size = majorVersion == 4
        ? _synchsafeInt(data, 0)
        : _uint32Be(data, 0) + 4;
    if (size <= 0 || size >= data.length) {
      return data;
    }
    return data.sublist(size);
  }

  String _cleanMimeType(String value, [List<int> bytes = const []]) {
    final fromBytes = _mimeTypeFromBytes(bytes);
    if (fromBytes != null) {
      return fromBytes;
    }
    if (value == 'image/jpg') {
      return 'image/jpeg';
    }
    if (value.startsWith('image/')) {
      return value;
    }
    return 'image/jpeg';
  }

  String? _mimeTypeFromBytes(List<int> bytes) {
    if (bytes.length >= 8 &&
        _startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return 'image/png';
    }
    if (bytes.length >= 3 && _startsWith(bytes, [0xff, 0xd8, 0xff])) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        _startsWith(bytes, ascii.encode('RIFF')) &&
        _startsWith(bytes.sublist(8), ascii.encode('WEBP'))) {
      return 'image/webp';
    }
    return null;
  }

  List<int> _removeUnsynchronisation(List<int> data) {
    final result = <int>[];
    for (var i = 0; i < data.length; i++) {
      final byte = data[i];
      result.add(byte);
      if (byte == 0xff && i + 1 < data.length && data[i + 1] == 0x00) {
        i++;
      }
    }
    return result;
  }

  bool _startsWith(List<int> data, List<int> prefix) {
    if (data.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  bool _startsWithAt(List<int> data, List<int> prefix, int offset) {
    if (offset < 0 || data.length - offset < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (data[offset + i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  int _indexOfZero(List<int> data, int start) {
    for (var i = start; i < data.length; i++) {
      if (data[i] == 0) {
        return i;
      }
    }
    return -1;
  }

  int _synchsafeInt(List<int> data, int offset) {
    return ((data[offset] & 0x7f) << 21) |
        ((data[offset + 1] & 0x7f) << 14) |
        ((data[offset + 2] & 0x7f) << 7) |
        (data[offset + 3] & 0x7f);
  }

  int _uint24Be(List<int> data, int offset) {
    return (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
  }

  int _uint32Be(List<int> data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  int _uint64Be(List<int> data, int offset) {
    return (data[offset] << 56) |
        (data[offset + 1] << 48) |
        (data[offset + 2] << 40) |
        (data[offset + 3] << 32) |
        (data[offset + 4] << 24) |
        (data[offset + 5] << 16) |
        (data[offset + 6] << 8) |
        data[offset + 7];
  }

  int _uint32Le(List<int> data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }
}

class _Id3Frame {
  const _Id3Frame({
    required this.id,
    required this.data,
    required this.nextOffset,
  });

  final String id;
  final List<int> data;
  final int nextOffset;
}
