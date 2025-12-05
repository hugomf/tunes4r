import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/file_import_service.dart';
import 'package:tunes4r/core/di/service_locator.dart';
import 'package:tunes4r/library/library_state.dart';
import 'package:tunes4r/library/library_actions.dart';
import 'package:tunes4r/library/library_commands.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/models/album.dart';

// ============================================================================
// INFRASTRUCTURE PROVIDERS (Services)
// ============================================================================

/// Provides DatabaseService instance through dependency injection
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return getIt<DatabaseService>();
});

/// Provides FileImportService instance through dependency injection
final fileImportServiceProvider = Provider<FileImportService>((ref) {
  return getIt<FileImportService>();
});

// ============================================================================
// STATE NOTIFIERS (Business Logic Layer)
// ============================================================================

/// Main library state notifier that manages reactive state with Riverpod
/// This replaces the StreamController approach with Riverpod's StateNotifier
class LibraryNotifier extends StateNotifier<LibraryState> {
  final DatabaseService _databaseService;

  LibraryNotifier(this._databaseService) : super(LibraryState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Start initialization loading state
    state = state.copyWith(isLoading: true);

    try {
      final library = await _databaseService.loadAllSongs();
      final favorites = await _databaseService.loadFavorites();

      state = LibraryActions.libraryInitialized(state, library, favorites);

      print('✅ Library initialized with ${library.length} songs, ${favorites.length} favorites');
    } catch (e) {
      state = LibraryActions.libraryInitializationFailed(state);
      print('❌ Failed to initialize library: $e');
    }
  }

  // ============================================================================
  // SONG MANAGEMENT
  // ============================================================================

  Future<void> saveSong(Song song) async {
    try {
      await _databaseService.saveSong(song);
      state = LibraryActions.saveSong(state, SaveSongCommand(song));
      print('✅ Saved song: ${song.title}');
    } catch (e) {
      print('❌ Failed to save song ${song.title}: $e');
      rethrow;
    }
  }

  Future<void> removeSong(Song song) async {
    try {
      await _databaseService.deleteSong(song.path);
      state = LibraryActions.removeSong(state, RemoveSongCommand(song));
      print('✅ Removed song: ${song.title}');
    } catch (e) {
      print('❌ Failed to remove song ${song.title}: $e');
      rethrow;
    }
  }

  Future<void> toggleFavorite(Song song) async {
    try {
      final isCurrentlyFavorite = state.favorites.contains(song);
      final newFavoriteStatus = !isCurrentlyFavorite;

      await _databaseService.updateFavorite(song.path, newFavoriteStatus);

      state = LibraryActions.toggleFavorite(
        state,
        ToggleFavoriteCommand(song),
      );

      print(
        isCurrentlyFavorite
          ? '✅ Removed ${song.title} from favorites'
          : '✅ Added ${song.title} to favorites'
      );
    } catch (e) {
      print('❌ Failed to toggle favorite for ${song.title}: $e');
      rethrow;
    }
  }

  Future<void> clearLibrary() async {
    try {
      await _databaseService.clearLibrary();
      state = LibraryActions.clearLibrary(state, ClearLibraryCommand());
      print('✅ Library cleared');
    } catch (e) {
      print('❌ Failed to clear library: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SEARCH & FILTERING
  // ============================================================================

  void searchSongs(String query) {
    state = LibraryActions.searchSongs(state, SearchSongsCommand(query));
    print('🔍 Searched songs with query: "$query" (${state.searchResults.length} results)');
  }

  void clearSearch() {
    state = LibraryActions.clearSearch(state, ClearSearchCommand());
    print('🔍 Search cleared');
  }

  // ============================================================================
  // SELECTION MANAGEMENT
  // ============================================================================

  void startSelection(Song initialSong) {
    state = LibraryActions.startSelection(state, StartSelectionCommand(initialSong));
    print('✅ Started selection mode with ${state.selectedSongs.length} songs');
  }

  void toggleSongSelection(Song song) {
    final wasSelected = state.selectedSongs.contains(song);
    state = LibraryActions.toggleSelection(state, ToggleSelectionCommand(song));
    print(
      wasSelected
        ? '❌ Deselected ${song.title}'
        : '✅ Selected ${song.title} (${state.selectedSongs.length} total)'
    );
  }

  void selectAllSongs() {
    state = LibraryActions.selectAll(state, SelectAllCommand());
    print('✅ Selected all songs (${state.selectedSongs.length} total)');
  }

  void deselectAllSongs() {
    state = LibraryActions.deselectAll(state, DeselectAllCommand());
    print('❌ Deselected all songs');
  }

  Set<Song> finishSelection() {
    state = LibraryActions.finishSelection(state, FinishSelectionCommand());
    final selectedSongs = state.selectedSongs;
    print('✅ Finished selection with ${selectedSongs.length} songs');
    return selectedSongs;
  }

  // ============================================================================
  // REFRESH FUNCTIONALITY (for Pull-to-Refresh)
  // ============================================================================

  Future<void> refreshLibrary() async {
    try {
      print('🔄 Refreshing library...');
      await _initialize();
      print('✅ Library refreshed successfully');
    } catch (e) {
      print('❌ Failed to refresh library: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDERS (Presentation Layer)
// ============================================================================

/// Main library provider - provides reactive state to UI
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return LibraryNotifier(databaseService);
});

// ============================================================================
// COMPUTED PROVIDERS (Derived State)
// ============================================================================

/// Computed provider for current display songs (search results or all songs)
final displaySongsProvider = Provider<List<Song>>((ref) {
  final state = ref.watch(libraryProvider);
  return state.displaySongs;
});

/// Computed provider for favorites list
final favoritesProvider = Provider<List<Song>>((ref) {
  final state = ref.watch(libraryProvider);
  return state.favorites;
});

/// Computed provider for album data (reactive)
final albumsProvider = Provider<List<Album>>((ref) {
  final state = ref.watch(libraryProvider);
  final albumsMap = <String, List<Song>>{};

  for (final song in state.library) {
    albumsMap.putIfAbsent(song.album, () => []).add(song);
  }

  return albumsMap.entries
      .map((e) => Album(name: e.key, songs: e.value))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Computed provider for library statistics
final libraryStatisticsProvider = Provider<LibraryStatistics>((ref) {
  final state = ref.watch(libraryProvider);
  return state.statistics;
});

/// Selection state providers
final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(libraryProvider).isSelectingMode;
});

final selectedSongsProvider = Provider<Set<Song>>((ref) {
  return ref.watch(libraryProvider).selectedSongs;
});

final hasSelectionProvider = Provider<bool>((ref) {
  return ref.watch(libraryProvider).hasSelection;
});

// ============================================================================
// ACTION PROVIDERS (Methods exposed to UI)
// ============================================================================

/// Provider to access LibraryNotifier methods from UI
final libraryActionsProvider = Provider<LibraryNotifier>((ref) {
  return ref.watch(libraryProvider.notifier);
});
