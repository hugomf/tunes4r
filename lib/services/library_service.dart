import 'dart:async';
import 'package:flutter/material.dart';
import '../models/song.dart';
import 'database_service.dart';
import '../utils/theme_colors.dart';

/// Service for managing the music library and favorites
class LibraryService {
  final DatabaseService _databaseService;

  LibraryService(this._databaseService);

  /// Stream of library songs for reactive updates
  Stream<List<Song>> get libraryStream => _libraryController.stream;
  final StreamController<List<Song>> _libraryController =
      StreamController<List<Song>>.broadcast();

  /// Stream of favorite songs for reactive updates
  Stream<List<Song>> get favoritesStream => _favoritesController.stream;
  final StreamController<List<Song>> _favoritesController =
      StreamController<List<Song>>.broadcast();

  /// Current library state
  List<Song> _library = [];
  List<Song> _favorites = [];

  List<Song> get library => _library;
  List<Song> get favorites => _favorites;

  /// Initialize the library by loading from database
  Future<void> initializeLibrary() async {
    await loadLibrary();
    await loadFavorites();
  }

  /// Load all songs from the database
  Future<void> loadLibrary() async {
    try {
      final songs = await _databaseService.loadAllSongs();
      _library = songs;
      _libraryController.add(_library);
      print('🎵 Library loaded: ${_library.length} songs');
    } catch (e) {
      print('❌ Error loading library: $e');
      // Keep empty library on error
      _library = [];
      _libraryController.add(_library);
    }
  }

  /// Load favorite songs from the database
  Future<void> loadFavorites() async {
    try {
      final favorites = await _databaseService.loadFavorites();
      _favorites = favorites;
      _favoritesController.add(_favorites);
      print('🎵 Favorites loaded: ${_favorites.length} songs');
    } catch (e) {
      print('❌ Error loading favorites: $e');
      // Keep empty favorites on error
      _favorites = [];
      _favoritesController.add(_favorites);
    }
  }

  /// Save a song to the database
  Future<void> saveSong(Song song) async {
    try {
      await _databaseService.saveSong(song);
      // Update local library if this song isn't already there
      if (!_library.any((s) => s.path == song.path)) {
        _library.add(song);
        _libraryController.add(_library);
        print('📝 Song added to library: ${song.title}');
      }
    } catch (e) {
      print('❌ Error saving song ${song.title}: $e');
      rethrow; // Re-throw to let caller handle
    }
  }

  /// Toggle favorite status for a song
  Future<void> toggleFavorite(Song song) async {
    try {
      final isCurrentlyFavorite = _favorites.contains(song);
      final newFavoriteStatus = !isCurrentlyFavorite;

      await _databaseService.updateFavorite(song.path, newFavoriteStatus);

      if (newFavoriteStatus) {
        // Add to favorites
        if (!_favorites.contains(song)) {
          _favorites.add(song);
        }
        print('❤️ Added to favorites: ${song.title}');
      } else {
        // Remove from favorites
        _favorites.remove(song);
        print('💔 Removed from favorites: ${song.title}');
      }

      _favoritesController.add(_favorites);
    } catch (e) {
      print('❌ Error toggling favorite for ${song.title}: $e');
      rethrow;
    }
  }

  /// Check if a song is in favorites
  bool isFavorite(Song song) {
    return _favorites.contains(song);
  }

  /// Remove a single song from the library
  Future<void> removeSong(Song song) async {
    try {
      await _databaseService.deleteSong(song.path);

      _library.remove(song);
      _favorites.remove(song); // Also remove from favorites if it was there

      _libraryController.add(_library);
      _favoritesController.add(_favorites);

      print('🗑️ Removed from library: ${song.title}');
    } catch (e) {
      print('❌ Error removing song ${song.title}: $e');
      rethrow;
    }
  }

  /// Clear all songs from the library
  Future<void> clearLibrary() async {
    try {
      await _databaseService.clearLibrary();

      _library.clear();
      _favorites.clear();

      _libraryController.add(_library);
      _favoritesController.add(_favorites);

      print('🧹 Library cleared successfully');
    } catch (e) {
      print('❌ Error clearing library: $e');
      rethrow;
    }
  }

  /// Get library statistics
  Map<String, int> getStatistics() {
    return {
      'totalSongs': _library.length,
      'totalFavorites': _favorites.length,
      'totalAlbums': _library.map((song) => song.album).toSet().length,
      'totalArtists': _library.map((song) => song.artist).toSet().length,
    };
  }

  /// Search songs by query
  List<Song> searchSongs(String query) {
    if (query.isEmpty) return _library;

    final lowerQuery = query.toLowerCase();
    return _library.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          song.artist.toLowerCase().contains(lowerQuery) ||
          song.album.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Close all streams
  void dispose() {
    _libraryController.close();
    _favoritesController.close();
  }
}
