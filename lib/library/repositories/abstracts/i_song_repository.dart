import '../../../models/song.dart';

/// Abstract interface for song data access operations
/// Defines the contract for song persistence and retrieval
abstract class ISongRepository {
  /// Saves a song to the underlying data store
  /// Returns true if successful, throws exception on failure
  Future<bool> saveSong(Song song);

  /// Updates an existing song in the data store
  /// Returns true if updated successfully, false if song not found
  Future<bool> updateSong(Song song);

  /// Retrieves a song by its file path
  /// Returns the song if found, null otherwise
  Future<Song?> getSongByPath(String path);

  /// Retrieves all songs from the data store
  /// Returns an empty list if no songs exist
  Future<List<Song>> getAllSongs();

  /// Retrieves all favorite songs
  /// Returns an empty list if no favorites exist
  Future<List<Song>> getFavoriteSongs();

  /// Updates the favorite status of a song by path
  /// Returns true if updated successfully, false if song not found
  Future<bool> updateFavoriteStatus(String path, bool isFavorite);

  /// Deletes a song from the data store by path
  /// Returns true if deleted successfully, false if song not found
  Future<bool> deleteSong(String path);

  /// Deletes all songs from the data store
  /// Returns the number of songs deleted
  Future<int> clearAllSongs();

  /// Searches songs by query (title, artist, album)
  /// Returns matching songs ordered by relevance
  Future<List<Song>> searchSongs(String query);

  /// Checks if a song exists in the data store
  Future<bool> songExists(String path);

  /// Gets the total count of songs
  Future<int> getSongCount();

  /// Gets the count of favorite songs
  Future<int> getFavoriteCount();

  /// Refreshes the data store with latest data
  /// This could involve syncing with external sources or validating data integrity
  Future<void> refreshData();
}
