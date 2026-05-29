class PlaylistEntry {
  const PlaylistEntry({required this.path});

  final String path;

  factory PlaylistEntry.fromJson(Object? json) {
    if (json is String) {
      return PlaylistEntry(path: json);
    }
    if (json is Map<String, dynamic>) {
      return PlaylistEntry(path: json['path'] as String? ?? '');
    }
    return const PlaylistEntry(path: '');
  }

  Map<String, dynamic> toJson() {
    return {'path': path};
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.entries,
    this.protected = false,
  });

  static const favouritesId = 'favourites';
  static const favouritesName = 'Favourites';

  final String id;
  final String name;
  final List<PlaylistEntry> entries;
  final bool protected;

  bool get isFavourites => id == favouritesId;
  bool get isProtected => protected || isFavourites;

  factory Playlist.favourites([List<PlaylistEntry> entries = const []]) {
    return Playlist(
      id: favouritesId,
      name: favouritesName,
      entries: List<PlaylistEntry>.from(entries),
      protected: true,
    );
  }

  Playlist copyWith({
    String? id,
    String? name,
    List<PlaylistEntry>? entries,
    bool? protected,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
      protected: protected ?? this.protected,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final entries = json['entries'];
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      protected: json['protected'] as bool? ?? false,
      entries: entries is List
          ? entries
                .map(PlaylistEntry.fromJson)
                .where((entry) => entry.path.trim().isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'protected': isProtected,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }
}
