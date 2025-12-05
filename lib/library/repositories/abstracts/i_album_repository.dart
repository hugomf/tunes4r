import '../../../models/album.dart';
import '../../../models/song.dart';

/// Abstract interface for album data access operations
/// Handles album-related data persistence and retrieval
abstract class IAlbumRepository {
  /// Retrieves all albums with their associated songs
  /// Returns albums grouped and sorted alphabetically
  Future<List<Album>> getAllAlbums();

  /// Gets albums for a specific artist
  Future<List<Album>> getAlbumsByArtist(String artist);

  /// Finds a specific album by name
  Future<Album?> getAlbumByName(String albumName);

  /// Gets songs belonging to a specific album
  Future<List<Song>> getSongsByAlbum(String albumName);

  /// Updates metadata for all songs in an album
  Future<bool> updateAlbumMetadata(String albumName, Map<String, dynamic> metadata);

  /// Checks if an album exists
  Future<bool> albumExists(String albumName);

  /// Removes all songs from a specific album
  /// Returns the number of songs removed
  Future<int> removeAlbum(String albumName);

  /// Refreshes album data (recomputes albums from songs)
  Future<void> refreshAlbums();
}
