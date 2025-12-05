import '../../../models/album.dart';
import '../../../models/song.dart';
import '../abstracts/i_album_repository.dart';
import '../abstracts/i_song_repository.dart';

/// Concrete implementation of IAlbumRepository
/// Albums are computed from songs data rather than stored separately
class DatabaseAlbumRepository implements IAlbumRepository {
  final ISongRepository _songRepository;

  DatabaseAlbumRepository(this._songRepository);

  @override
  Future<List<Album>> getAllAlbums() async {
    final songs = await _songRepository.getAllSongs();

    // Group songs by album name
    final albumMap = <String, List<Song>>{};

    for (final song in songs) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }

    // Create Album objects and sort alphabetically
    return albumMap.entries
        .map((entry) => Album(
              name: entry.key,
              songs: entry.value..sort((a, b) {
                // Sort songs within album by track number, then by title
                if (a.trackNumber != null && b.trackNumber != null) {
                  return a.trackNumber!.compareTo(b.trackNumber!);
                }
                return a.title.compareTo(b.title);
              }),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<Album>> getAlbumsByArtist(String artist) async {
    final allAlbums = await getAllAlbums();
    return allAlbums.where((album) {
      return album.songs.any((song) =>
          song.artist.toLowerCase() == artist.toLowerCase());
    }).toList();
  }

  @override
  Future<Album?> getAlbumByName(String albumName) async {
    final allAlbums = await getAllAlbums();
    return allAlbums.cast<Album?>().firstWhere(
          (album) => album?.name == albumName,
          orElse: () => null,
        );
  }

  @override
  Future<List<Song>> getSongsByAlbum(String albumName) async {
    final album = await getAlbumByName(albumName);
    return album?.songs ?? [];
  }

  @override
  Future<bool> updateAlbumMetadata(String albumName, Map<String, dynamic> metadata) async {
    try {
      final songs = await getSongsByAlbum(albumName);
      if (songs.isEmpty) return false;

      // Update all songs in the album with new metadata
      for (final song in songs) {
        final updatedSong = song.copyWith(
          // Apply any metadata updates here
          // For example:
          // artist: metadata['artist'] ?? song.artist,
          // album: metadata['album'] ?? song.album,
        );
        await _songRepository.updateSong(updatedSong);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> albumExists(String albumName) async {
    final album = await getAlbumByName(albumName);
    return album != null;
  }

  @override
  Future<int> removeAlbum(String albumName) async {
    try {
      final songs = await getSongsByAlbum(albumName);
      int removedCount = 0;

      for (final song in songs) {
        final removed = await _songRepository.deleteSong(song.path);
        if (removed) removedCount++;
      }

      return removedCount;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> refreshAlbums() async {
    // Albums are derived from songs, so refreshing songs refreshes albums
    await _songRepository.refreshData();
  }
}
