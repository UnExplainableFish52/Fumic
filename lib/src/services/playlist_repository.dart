import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';

abstract class PlaylistRepository {
  Future<List<Playlist>> loadPlaylists();
  Future<void> savePlaylists(List<Playlist> playlists);
}

class JsonPlaylistRepository implements PlaylistRepository {
  JsonPlaylistRepository({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  static const _fileName = 'fumic_playlists.json';
  static const _version = 1;

  final Directory? _supportDirectory;

  @override
  Future<List<Playlist>> loadPlaylists() async {
    final file = await _playlistFile();
    if (!await file.exists()) {
      return _withDefaultPlaylist(const []);
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _withDefaultPlaylist(const []);
      }
      final rawPlaylists = decoded['playlists'];
      if (rawPlaylists is! List) {
        return _withDefaultPlaylist(const []);
      }
      final playlists = rawPlaylists
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .where((playlist) {
            return playlist.id.trim().isNotEmpty &&
                playlist.name.trim().isNotEmpty;
          })
          .toList(growable: false);
      return _withDefaultPlaylist(playlists);
    } on Object {
      return _withDefaultPlaylist(const []);
    }
  }

  @override
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final file = await _playlistFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert({
        'version': _version,
        'playlists': _withDefaultPlaylist(
          playlists,
        ).map((playlist) => playlist.toJson()).toList(),
      }),
      flush: true,
    );
  }

  Future<File> _playlistFile() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }
}

class MemoryPlaylistRepository implements PlaylistRepository {
  MemoryPlaylistRepository([List<Playlist> playlists = const []])
    : _playlists = _withDefaultPlaylist(playlists);

  List<Playlist> _playlists;

  @override
  Future<List<Playlist>> loadPlaylists() async {
    return List<Playlist>.from(_playlists);
  }

  @override
  Future<void> savePlaylists(List<Playlist> playlists) async {
    _playlists = _withDefaultPlaylist(playlists);
  }
}

List<Playlist> _withDefaultPlaylist(List<Playlist> source) {
  Playlist? favourites;
  final result = <Playlist>[];
  final seen = <String>{};

  for (final playlist in source) {
    final id = playlist.id.trim();
    if (id.isEmpty || !seen.add(id)) {
      continue;
    }
    if (id == Playlist.favouritesId) {
      favourites = Playlist.favourites(_dedupeEntries(playlist.entries));
      continue;
    }
    result.add(playlist.copyWith(entries: _dedupeEntries(playlist.entries)));
  }

  return [favourites ?? Playlist.favourites(), ...result];
}

List<PlaylistEntry> _dedupeEntries(List<PlaylistEntry> entries) {
  final seen = <String>{};
  final deduped = <PlaylistEntry>[];
  for (final entry in entries) {
    final path = entry.path.trim();
    if (path.isEmpty) {
      continue;
    }
    final key = path.toLowerCase();
    if (seen.add(key)) {
      deduped.add(PlaylistEntry(path: path));
    }
  }
  return deduped;
}
