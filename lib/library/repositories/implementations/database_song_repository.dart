import 'dart:async';

import '../../../models/song.dart';
import '../../../services/database_service.dart';
import '../abstracts/i_song_repository.dart';

/// Concrete implementation of ISongRepository using DatabaseService
/// Provides song persistence with in-memory caching for performance
class DatabaseSongRepository implements ISongRepository {
  final DatabaseService _databaseService;

  // In-memory cache for improved performance
  List<Song>? _songsCache;
  List<Song>? _favoritesCache;
  Map<String, Song> _songsByPathCache = {};
  DateTime? _lastCacheUpdate;

  // Cache expiry time (5 minutes)
  static const Duration _cacheExpiryTime = Duration(minutes: 5);

  DatabaseSongRepository(this._databaseService);

  /// Checks if cache is valid and not expired
  bool get _isCacheValid =>
      _songsCache != null &&
      _lastCacheUpdate != null &&
      DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiryTime;

  /// Invalidates the cache to force fresh data load
  void _invalidateCache() {
    _songsCache = null;
    _favoritesCache = null;
    _songsByPathCache.clear();
    _lastCacheUpdate = null;
  }

  /// Updates the cache with fresh data
  void _updateCache(List<Song> songs) {
    _songsCache = songs;
    _songsByPathCache = {for (var song in songs) song.path: song};
    _lastCacheUpdate = DateTime.now();
    // Note: favoritesCache is updated separately when getFavoriteSongs is called
  }

  @override
  Future<bool> saveSong(Song song) async {
    try {
      await _databaseService.saveSong(song);
      _invalidateCache(); // Invalidate cache since data changed
      return true;
    } catch (e) {
      // Log error in a production app
      rethrow;
    }
  }

  @override
  Future<bool> updateSong(Song song) async {
    try {
      // DatabaseService doesn't have a direct update method,
      // so we'll use save with replace strategy
      await _databaseService.saveSong(song);
      _invalidateCache();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Song?> getSongByPath(String path) async {
    // Try cache first
    if (_isCacheValid && _songsByPathCache.containsKey(path)) {
      return _songsByPathCache[path];
    }

    // Load from database if not in cache
    final songs = await getAllSongs();
    return songs.cast<Song?>().firstWhere(
          (song) => song?.path == path,
          orElse: () => null,
        );
  }

  @override
  Future<List<Song>> getAllSongs() async {
    if (_isCacheValid && _songsCache != null) {
      return _songsCache!;
    }

    // Load from database
    final songs = await _databaseService.loadAllSongs();
    _updateCache(songs);
    return songs;
  }

  @override
  Future<List<Song>> getFavoriteSongs() async {
    // Check if cache is valid and has favorites data
    if (_isCacheValid && _favoritesCache != null) {
      return _favoritesCache!;
    }

    // Load from database
    final favorites = await _databaseService.loadFavorites();

    // Update cache if all songs are also cached
    if (_songsCache != null) {
      _favoritesCache = favorites;
    }

    return favorites;
  }

  @override
  Future<bool> updateFavoriteStatus(String path, bool isFavorite) async {
    try {
      await _databaseService.updateFavorite(path, isFavorite);
      _invalidateCache(); // Invalidate cache since favorites changed
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteSong(String path) async {
    try {
      await _databaseService.deleteSong(path);
      _invalidateCache(); // Invalidate cache since data changed
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> clearAllSongs() async {
    try {
      // Note: This would need to be added to DatabaseService if not present
      await _databaseService.clearLibrary();
      _invalidateCache();
      return 1; // DatabaseService.clearLibrary() doesn't return count
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    if (query.trim().isEmpty) {
      return await getAllSongs();
    }

    final allSongs = await getAllSongs();
    final lowercaseQuery = query.toLowerCase();

    // Simple text-based search implementation
    return allSongs.where((song) {
      return song.title.toLowerCase().contains(lowercaseQuery) ||
             song.artist.toLowerCase().contains(lowercaseQuery) ||
             song.album.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  @override
  Future<bool> songExists(String path) async {
    if (_isCacheValid) {
      return _songsByPathCache.containsKey(path);
    }

    final song = await getSongByPath(path);
    return song != null;
  }

  @override
  Future<int> getSongCount() async {
    final songs = await getAllSongs();
    return songs.length;
  }

  @override
  Future<int> getFavoriteCount() async {
    final favorites = await getFavoriteSongs();
    return favorites.length;
  }

  @override
  Future<void> refreshData() async {
    _invalidateCache();
    // Force refresh by loading from database
    await getAllSongs();
  }
}
