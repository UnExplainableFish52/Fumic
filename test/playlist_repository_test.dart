import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/playlist.dart';
import 'package:fumic/src/services/playlist_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('fumic_playlists_');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('loads protected Favourites by default', () async {
    final repository = JsonPlaylistRepository(supportDirectory: tempDirectory);

    final playlists = await repository.loadPlaylists();

    expect(playlists, hasLength(1));
    expect(playlists.single.id, Playlist.favouritesId);
    expect(playlists.single.name, Playlist.favouritesName);
    expect(playlists.single.isProtected, isTrue);
  });

  test('roundtrips playlists and removes duplicate entries', () async {
    final repository = JsonPlaylistRepository(supportDirectory: tempDirectory);

    await repository.savePlaylists([
      Playlist.favourites([
        const PlaylistEntry(path: 'C:\\Media\\Track.mp3'),
        const PlaylistEntry(path: 'c:\\media\\track.mp3'),
      ]),
      const Playlist(
        id: 'playlist_1',
        name: 'Road',
        entries: [PlaylistEntry(path: 'C:\\Media\\Skyfall.wav')],
      ),
    ]);

    final playlists = await repository.loadPlaylists();

    expect(playlists, hasLength(2));
    expect(playlists.first.name, Playlist.favouritesName);
    expect(playlists.first.entries, hasLength(1));
    expect(playlists.last.name, 'Road');
    expect(playlists.last.entries.single.path, 'C:\\Media\\Skyfall.wav');
  });

  test('falls back to Favourites for corrupt JSON', () async {
    final file = File(p.join(tempDirectory.path, 'fumic_playlists.json'));
    await file.writeAsString('{bad json');

    final repository = JsonPlaylistRepository(supportDirectory: tempDirectory);

    final playlists = await repository.loadPlaylists();

    expect(playlists, hasLength(1));
    expect(playlists.single.id, Playlist.favouritesId);
  });

  test('keeps Favourites first when loading raw JSON', () async {
    final file = File(p.join(tempDirectory.path, 'fumic_playlists.json'));
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'playlists': [
          {'id': 'playlist_1', 'name': 'Late Night', 'entries': <Object?>[]},
          {
            'id': Playlist.favouritesId,
            'name': 'Renamed',
            'protected': false,
            'entries': [
              {'path': 'C:\\Media\\One.mp3'},
            ],
          },
        ],
      }),
    );

    final repository = JsonPlaylistRepository(supportDirectory: tempDirectory);

    final playlists = await repository.loadPlaylists();

    expect(playlists.first.id, Playlist.favouritesId);
    expect(playlists.first.name, Playlist.favouritesName);
    expect(playlists.first.isProtected, isTrue);
    expect(playlists.last.name, 'Late Night');
  });
}
