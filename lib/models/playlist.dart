import 'package:tunes4r/models/song.dart';

enum PlaylistType {
  userCreated,
  album,
  favorites,
  recentlyAdded,
  mostPlayed,
}

class Playlist {
  final int? id;
  final String name;
  final PlaylistType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Song> songs;

  const Playlist({
    this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.songs,
  });

  Playlist copyWith({
    int? id,
    String? name,
    PlaylistType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map, List<Song> songs) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: PlaylistType.values[map['type'] as int],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      songs: songs,
    );
  }

  // Built-in system playlists
  static Playlist favorites(List<Song> favoriteSongs) {
    return Playlist(
      id: -1, // Special ID for favorites
      name: 'Favorites',
      type: PlaylistType.favorites,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      songs: favoriteSongs,
    );
  }

  static Playlist recent(List<Song> recentSongs) {
    return Playlist(
      id: -2, // Special ID for recent
      name: 'Recently Added',
      type: PlaylistType.recentlyAdded,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      songs: recentSongs,
    );
  }

  bool get isSystemPlaylist =>
      type != PlaylistType.userCreated || (id != null && id! < 0);

  bool get isEmpty => songs.isEmpty;

  int get songCount => songs.length;

  Duration get totalDuration =>
      songs.fold(Duration.zero, (total, song) => total + (song.duration ?? Duration.zero));
}
