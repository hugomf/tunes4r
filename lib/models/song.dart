import 'dart:typed_data';

/// Represents a music track in the Tunes4R library
class Song {
  final String title;
  final String path;
  final String artist;
  final String album;
  final Uint8List? albumArt;
  final Duration? duration;
  final int? trackNumber; // Track number for albums

  Song({
    required this.title,
    required this.path,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.albumArt,
    this.duration,
    this.trackNumber,
  });

  /// Creates a copy of this Song with modified fields
  Song copyWith({
    String? title,
    String? path,
    String? artist,
    String? album,
    Uint8List? albumArt,
    Duration? duration,
    int? trackNumber,
  }) {
    return Song(
      title: title ?? this.title,
      path: path ?? this.path,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
    );
  }

  /// Equality comparison based on file path
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.path == path;
  }

  /// Hash code based on file path
  @override
  int get hashCode => path.hashCode;

  /// String representation for debugging
  @override
  String toString() {
    return 'Song(title: $title, artist: $artist, path: $path, duration: $duration, hasAlbumArt: ${albumArt != null})';
  }
}
