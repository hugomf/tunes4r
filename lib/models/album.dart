/// Represents a music album grouping multiple songs
import '../models/song.dart';

class Album {
  final String name;
  final List<Song> songs;

  const Album({required this.name, required this.songs});

  /// Number of tracks in this album
  int get trackCount => songs.length;

  /// Total duration of all songs in the album
  Duration? get totalDuration {
    if (songs.isEmpty) return null;
    return songs.fold<Duration>(
      Duration.zero,
      (total, song) => total + (song.duration ?? Duration.zero),
    );
  }

  /// A representative song with album artwork, or the first song if none have artwork
  /// Returns null if album is empty
  Song? get coverSong {
    if (songs.isEmpty) return null;
    try {
      return songs.firstWhere((song) => song.albumArt != null);
    } catch (e) {
      return songs.first; // Return first song if no album artwork found
    }
  }

  /// Sort songs by track number (if available), then by title
  List<Song> get sortedSongs {
    final sorted = List<Song>.from(songs);
    sorted.sort((a, b) {
      // Sort by track number if available
      if (a.trackNumber != null && b.trackNumber != null) {
        return a.trackNumber!.compareTo(b.trackNumber!);
      }
      if (a.trackNumber != null) return -1;
      if (b.trackNumber != null) return 1;
      // Fall back to title sorting
      return a.title.compareTo(b.title);
    });
    return sorted;
  }

  @override
  String toString() {
    return 'Album(name: $name, tracks: $trackCount, duration: $totalDuration)';
  }
}
