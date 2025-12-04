import 'library_state.dart';
import 'library_commands.dart';
import '../../models/song.dart';

/// Pure functions that transform LibraryState based on commands
/// No side effects, just state transformations
class LibraryActions {

  /// Initialize library by loading from storage
  static LibraryState initializeLibrary(LibraryState state, InitializeLibraryCommand command) {
    return state.copyWith(
      isLoading: true,
      statistics: LibraryStatistics.empty(),
    );
  }

  /// Handle successful library initialization
  static LibraryState libraryInitialized(LibraryState state, List<Song> library, List<Song> favorites) {
    final statistics = _calculateStatistics(library);
    return state.copyWith(
      library: library,
      favorites: favorites,
      statistics: statistics,
      isLoading: false,
    );
  }

  /// Handle failed library initialization
  static LibraryState libraryInitializationFailed(LibraryState state) {
    return state.copyWith(
      isLoading: false,
      library: [],
      favorites: [],
    );
  }

  /// Save a song to the library
  static LibraryState saveSong(LibraryState state, SaveSongCommand command) {
    final updatedLibrary = state.library.contains(command.song)
        ? state.library  // Already exists
        : [...state.library, command.song];

    final statistics = _calculateStatistics(updatedLibrary);

    return state.copyWith(
      library: updatedLibrary,
      statistics: statistics,
    );
  }

  /// Remove a song from the library
  static LibraryState removeSong(LibraryState state, RemoveSongCommand command) {
    final updatedLibrary = state.library.where((song) => song != command.song).toList();
    final updatedFavorites = state.favorites.where((song) => song != command.song).toList();

    final statistics = _calculateStatistics(updatedLibrary);

    return state.copyWith(
      library: updatedLibrary,
      favorites: updatedFavorites,
      statistics: statistics,
      // Clear selection if removed song was selected
      selectedSongs: state.selectedSongs.where((song) => song != command.song).toSet(),
    );
  }

  /// Clear the entire library
  static LibraryState clearLibrary(LibraryState state, ClearLibraryCommand command) {
    return state.copyWith(
      library: [],
      favorites: [],
      searchResults: [],
      searchQuery: '',
      selectedSongs: {},
      isSelectingMode: false,
      statistics: LibraryStatistics.empty(),
    );
  }

  /// Toggle favorite status for a song
  static LibraryState toggleFavorite(LibraryState state, ToggleFavoriteCommand command) {
    final isCurrentlyFavorite = state.favorites.contains(command.song);
    final List<Song> updatedFavorites;

    if (isCurrentlyFavorite) {
      // Remove from favorites
      updatedFavorites = state.favorites.where((song) => song != command.song).toList();
    } else {
      // Add to favorites
      updatedFavorites = [...state.favorites, command.song];
    }

    final statistics = state.statistics.copyWith(
      totalFavorites: updatedFavorites.length,
    );

    return state.copyWith(
      favorites: updatedFavorites,
      statistics: statistics,
    );
  }

  /// Search songs by query
  static LibraryState searchSongs(LibraryState state, SearchSongsCommand command) {
    if (command.query.isEmpty) {
      return clearSearch(state, ClearSearchCommand());
    }

    final query = command.query.toLowerCase();
    final results = state.library.where((song) {
      return song.title.toLowerCase().contains(query) ||
             song.artist.toLowerCase().contains(query) ||
             song.album.toLowerCase().contains(query);
    }).toList();

    return state.copyWith(
      searchQuery: command.query,
      searchResults: results,
    );
  }

  /// Clear search and show all songs
  static LibraryState clearSearch(LibraryState state, ClearSearchCommand command) {
    return state.copyWith(
      searchQuery: '',
      searchResults: [],
    );
  }

  /// Start selection mode for playlist operations
  static LibraryState startSelection(LibraryState state, StartSelectionCommand command) {
    return state.copyWith(
      isSelectingMode: true,
      selectedSongs: {command.initialSong},
    );
  }

  /// Toggle selection of a song in selection mode
  static LibraryState toggleSelection(LibraryState state, ToggleSelectionCommand command) {
    final Set<Song> updatedSelection;
    if (state.selectedSongs.contains(command.song)) {
      // Remove from selection
      updatedSelection = Set<Song>.from(state.selectedSongs)..remove(command.song);
      // Auto-exit selection mode if no songs selected
      if (updatedSelection.isEmpty) {
        return state.copyWith(
          isSelectingMode: false,
          selectedSongs: updatedSelection,
        );
      }
    } else {
      // Add to selection
      updatedSelection = Set<Song>.from(state.selectedSongs)..add(command.song);
    }

    return state.copyWith(selectedSongs: updatedSelection);
  }

  /// Select all songs in selection mode
  static LibraryState selectAll(LibraryState state, SelectAllCommand command) {
    final songsToSelect = state.hasSearchResults ? state.searchResults : state.library;
    return state.copyWith(
      selectedSongs: Set<Song>.from(songsToSelect),
    );
  }

  /// Deselect all songs in selection mode
  static LibraryState deselectAll(LibraryState state, DeselectAllCommand command) {
    return state.copyWith(
      isSelectingMode: false,
      selectedSongs: {},
    );
  }

  /// Finish selection mode and return selected songs
  static LibraryState finishSelection(LibraryState state, FinishSelectionCommand command) {
    return state.copyWith(
      isSelectingMode: false,
    );
  }

  /// Update loading state
  static LibraryState setLoading(LibraryState state, bool isLoading) {
    return state.copyWith(isLoading: isLoading);
  }

  /// Helper: Calculate statistics from library
  static LibraryStatistics _calculateStatistics(List<Song> library) {
    return LibraryStatistics(
      totalSongs: library.length,
      totalFavorites: 0, // This will be set separately when favorites are loaded
      totalAlbums: library.map((song) => song.album).toSet().length,
      totalArtists: library.map((song) => song.artist).toSet().length,
    );
  }
}
