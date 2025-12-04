import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:tunes4r/models/album.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/library/widgets/albums_tab.dart';
import 'package:tunes4r/library/widgets/favorites_tab.dart';
import 'library_actions.dart';
import 'library_commands.dart';
import 'library_state.dart';
import 'logger.dart';
import 'services/media_scan_service.dart';
import 'services/metadata_extraction_service.dart';

/// Main bounded context class for library management
/// Encapsulates all library-related functionality in a single component
class Library {
  // Core dependencies
  final DatabaseService _databaseService;

  // Domain services
  late final MediaScanService _mediaScanService;
  late final MetadataExtractionService _metadataExtractionService;

  // State management
  LibraryState _state = LibraryState.initial();
  final StreamController<LibraryState> _stateController =
      StreamController<LibraryState>.broadcast();
  final StreamController<LibraryEvent> _eventController =
      StreamController<LibraryEvent>.broadcast();

  Library._(this._databaseService);

  /// Factory constructor with database service
  factory Library(DatabaseService databaseService) {
    return Library._(databaseService);
  }

  /// Initialize the library bounded context
  Future<void> initialize() async {
    // Configure logger for this bounded context - INTERNAL concern
    LibraryLogger.configure(
      level: Level.INFO, // INFO for library operations, WARNING for errors
    );

    LibraryLogger.info('Initializing library bounded context');

    // Initialize domain services
    _mediaScanService = MediaScanService();
    _metadataExtractionService = MetadataExtractionService();

    await _executeCommand(InitializeLibraryCommand());

    try {
      // Load library and favorites from database
      final library = await _databaseService.loadAllSongs();
      final favorites = await _databaseService.loadFavorites();

      _state = LibraryActions.libraryInitialized(_state, library, favorites);

      LibraryLogger.libraryOperation(
        'loaded successfully',
        details: '${library.length} songs, ${favorites.length} favorites',
      );
    } catch (e) {
      _state = LibraryActions.libraryInitializationFailed(_state);
      LibraryLogger.warning('Failed to initialize library: $e', error: e);
    } finally {
      _stateController.add(_state);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _stateController.close();
    await _eventController.close();
  }

  /// Reactive state stream for UI updates
  Stream<LibraryState> get state => _stateController.stream;

  /// Event stream for inter-context communication
  Stream<LibraryEvent> get events => _eventController.stream;

  /// Current state snapshot (for convenience)
  LibraryState get currentState => _state;

  /// Computed properties from state
  List<Song> get library => _state.library;
  List<Song> get favorites => _state.favorites;
  List<Song> get displaySongs =>
      _state.displaySongs; // Shows search results or all songs
  bool get isLoading => _state.isLoading;
  bool get isSearching => _state.isSearchActive;
  bool get hasSelection => _state.hasSelection;
  LibraryStatistics get statistics => _state.statistics;

  /// Get all albums from the library, grouped by album name and sorted alphabetically
  List<Album> getAlbums() {
    final albumMap = <String, List<Song>>{};

    for (final song in library) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }

    return albumMap.entries
        .map((e) => Album(name: e.key, songs: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Reactive stream of albums that updates when library changes
  Stream<List<Album>> watchAlbums() {
    return state.map((libraryState) => getAlbums());
  }

  /// Command interface - all library operations go through here

  /// Save a song to the library
  /// Use emitEvent=false when doing bulk operations to avoid spam notifications
  Future<void> saveSong(Song song, {bool emitEvent = true}) async {
    try {
      LibraryLogger.songOperation('saving', song.title);

      await _databaseService.saveSong(song);
      _state = LibraryActions.saveSong(_state, SaveSongCommand(song));

      _stateController.add(_state);
      if (emitEvent) {
        _emitEvent(
          SongSavedEvent(song),
        ); // Only emit for single-song operations
      }

      LibraryLogger.songOperation('saved successfully', song.title);
    } catch (e) {
      LibraryLogger.warning(
        'Failed to save song "${song.title}": $e',
        error: e,
      );
      _emitEvent(
        LibraryErrorEvent('Failed to add song "${song.title}"', e.toString()),
      );
      rethrow;
    }
  }

  /// Remove a song from the library
  Future<void> removeSong(Song song) async {
    try {
      LibraryLogger.songOperation('removing', song.title);

      await _databaseService.deleteSong(song.path);
      _state = LibraryActions.removeSong(_state, RemoveSongCommand(song));

      _stateController.add(_state);
      _emitEvent(SongRemovedEvent(song));

      LibraryLogger.songOperation('removed successfully', song.title);
    } catch (e) {
      LibraryLogger.warning(
        'Failed to remove song "${song.title}": $e',
        error: e,
      );
      _emitEvent(
        LibraryErrorEvent(
          'Failed to remove song "${song.title}"',
          e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Clear the entire library
  Future<void> clearLibrary() async {
    try {
      LibraryLogger.libraryOperation('clearing all songs');

      await _databaseService.clearLibrary();
      _state = LibraryActions.clearLibrary(_state, ClearLibraryCommand());

      _stateController.add(_state);
      _emitEvent(LibraryClearedEvent());

      LibraryLogger.libraryOperation('cleared successfully');
    } catch (e) {
      LibraryLogger.warning('Failed to clear library: $e', error: e);
      _emitEvent(LibraryErrorEvent('Failed to clear library', e.toString()));
      rethrow;
    }
  }

  /// Toggle favorite status for a song
  Future<void> toggleFavorite(Song song) async {
    try {
      final isCurrentlyFavorite = _state.favorites.contains(song);
      final action = isCurrentlyFavorite
          ? 'removing from favorites'
          : 'adding to favorites';

      LibraryLogger.songOperation(action, song.title);

      final newFavoriteStatus = !isCurrentlyFavorite;
      await _databaseService.updateFavorite(song.path, newFavoriteStatus);

      _state = LibraryActions.toggleFavorite(
        _state,
        ToggleFavoriteCommand(song),
      );

      _stateController.add(_state);
      _emitEvent(FavoriteToggledEvent(song, newFavoriteStatus));

      LibraryLogger.songOperation(
        isCurrentlyFavorite ? 'removed from favorites' : 'added to favorites',
        song.title,
      );
    } catch (e) {
      LibraryLogger.warning(
        'Failed to toggle favorite status for "${song.title}": $e',
        error: e,
      );
      _emitEvent(
        LibraryErrorEvent(
          'Failed to update favorites for "${song.title}"',
          e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Check if a song is in favorites
  bool isFavorite(Song song) {
    return _state.favorites.contains(song);
  }

  /// Search songs by query
  void searchSongs(String query) {
    try {
      LibraryLogger.searchOperation(query, _state.searchResults.length);

      _state = LibraryActions.searchSongs(_state, SearchSongsCommand(query));
      _stateController.add(_state);

      _emitEvent(SearchResultsEvent(_state.searchResults, query));

      LibraryLogger.searchOperation(query, _state.searchResults.length);
    } catch (e) {
      LibraryLogger.warning('Failed to search songs: $e', error: e);
      _emitEvent(LibraryErrorEvent('Failed to search songs', e.toString()));
    }
  }

  /// Clear search and show all songs
  void clearSearch() {
    try {
      LibraryLogger.info('Clearing search');

      _state = LibraryActions.clearSearch(_state, ClearSearchCommand());
      _stateController.add(_state);

      LibraryLogger.info('Search cleared');
    } catch (e) {
      LibraryLogger.warning('Failed to clear search: $e', error: e);
    }
  }

  /// Start selection mode for playlist operations
  void startSelection(Song initialSong) {
    try {
      LibraryLogger.selectionOperation('starting selection', 1);

      _state = LibraryActions.startSelection(
        _state,
        StartSelectionCommand(initialSong),
      );
      _stateController.add(_state);

      _emitEvent(SelectionModeChangedEvent(true, _state.selectedSongs));

      LibraryLogger.selectionOperation(
        'selection started',
        _state.selectedSongs.length,
      );
    } catch (e) {
      LibraryLogger.warning('Failed to start selection mode: $e', error: e);
    }
  }

  /// Toggle selection of a specific song
  void toggleSongSelection(Song song) {
    try {
      final wasSelected = _state.selectedSongs.contains(song);
      _state = LibraryActions.toggleSelection(
        _state,
        ToggleSelectionCommand(song),
      );

      _stateController.add(_state);
      _emitEvent(
        SelectionModeChangedEvent(_state.isSelectingMode, _state.selectedSongs),
      );

      LibraryLogger.songOperation(
        wasSelected ? 'deselected' : 'selected',
        song.title,
      );
    } catch (e) {
      LibraryLogger.warning('Failed to toggle song selection: $e', error: e);
    }
  }

  /// Select all songs in current view (search results or all songs)
  void selectAllSongs() {
    try {
      _state = LibraryActions.selectAll(_state, SelectAllCommand());
      _stateController.add(_state);

      _emitEvent(SelectionModeChangedEvent(true, _state.selectedSongs));

      LibraryLogger.selectionOperation(
        'selected all',
        _state.selectedSongs.length,
      );
    } catch (e) {
      LibraryLogger.warning('Failed to select all songs: $e', error: e);
    }
  }

  /// Deselect all songs and exit selection mode
  void deselectAllSongs() {
    try {
      _state = LibraryActions.deselectAll(_state, DeselectAllCommand());
      _stateController.add(_state);

      _emitEvent(SelectionModeChangedEvent(false, _state.selectedSongs));

      LibraryLogger.selectionOperation('deselected all', 0);
    } catch (e) {
      LibraryLogger.warning('Failed to deselect all songs: $e', error: e);
    }
  }

  /// Finish selection mode and return selected songs
  Set<Song> finishSelection() {
    try {
      _state = LibraryActions.finishSelection(_state, FinishSelectionCommand());
      _stateController.add(_state);

      _emitEvent(SelectionModeChangedEvent(false, _state.selectedSongs));

      LibraryLogger.selectionOperation(
        'selection finished',
        _state.selectedSongs.length,
      );

      return _state.selectedSongs;
    } catch (e) {
      LibraryLogger.warning('Failed to finish selection: $e', error: e);
      return const {};
    }
  }

  /// Get library statistics (already available as getter)
  /// Future enhancement: could compute advanced analytics

  /// Import music files given their paths
  /// This is pure domain logic - UI layer handles path selection
  Future<int> importMusicFiles(List<String> filePaths) async {
    LibraryLogger.info('Importing ${filePaths.length} music files');

    if (filePaths.isEmpty) return 0;

    return await _processAndImportAudioFiles(filePaths);
  }

  /// Scan directory for audio files
  /// Returns list of audio file paths found in the directory
  Future<List<String>> scanDirectoryForAudio(String directoryPath) async {
    try {
      return await _mediaScanService.scanDirectory(directoryPath);
    } catch (e) {
      LibraryLogger.warning(
        'Error scanning directory "$directoryPath": $e',
        error: e,
      );
      return [];
    }
  }

  /// Check if we have necessary permissions for file access
  /// This is a domain concern for cross-platform permission checking
  Future<bool> checkPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final manageStoragePermission =
          await Permission.manageExternalStorage.status;
      final audioPermission = await Permission.audio.status;
      return manageStoragePermission.isGranted && audioPermission.isGranted;
    } catch (e) {
      LibraryLogger.warning('Permission check failed: $e', error: e);
      return false;
    }
  }

  /// Process and import audio files to the database
  /// This is pure domain logic - UI layer handles progress and feedback
  Future<int> _processAndImportAudioFiles(List<String> filePaths) async {
    int importedCount = 0;

    try {
      // Process all audio files
      final newSongs = await _metadataExtractionService.extractMultipleMetadata(
        filePaths,
      );

      // Determine if this is a bulk import (more than 1 file)
      final isBulkImport = newSongs.length > 1;

      // Save to database via the library context (reactive)
      for (var song in newSongs) {
        // Don't emit individual SongSavedEvent for bulk imports (>1 file)
        await saveSong(song, emitEvent: !isBulkImport);
        importedCount++;
      }

      // Emit bulk import event if this was a bulk import
      if (isBulkImport) {
        _emitEvent(FilesImportedEvent(importedCount));
      }

      LibraryLogger.libraryOperation(
        'imported successfully',
        details: 'Added $importedCount songs',
      );
    } catch (e) {
      LibraryLogger.warning('Error during import: $e', error: e);
      rethrow;
    }

    return importedCount;
  }

  /// Get the navigation title for the AppBar
  /// Domain provides data for UI to build widgets
  String getNavigationTitle() => 'Library (${library.length})';

  /// Provide the Albums tab widget - DDD encapsulation
  /// Each BC encapsulates its view components completely
  Widget getAlbumsTab(PlaybackManager audioPlayer) {
    return AlbumsTab(libraryContext: this, playbackManager: audioPlayer);
  }

  /// Provide the Favorites tab widget - DDD encapsulation
  /// Each BC encapsulates its view components completely
  Widget getFavoritesTab(PlaybackManager audioPlayer) {
    return FavoritesTab(libraryContext: this, playbackManager: audioPlayer);
  }

  /// Private methods

  Future<void> _executeCommand(LibraryCommand command) async {
    // Commands are executed through LibraryActions which are pure functions
    // This method is for consistency with the pattern, though most commands
    // are handled directly in the action methods above
  }

  void _emitEvent(LibraryEvent event) {
    _eventController.add(event);
  }
}
