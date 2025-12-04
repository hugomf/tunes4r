


import 'package:tunes4r/models/song.dart';

/// Statistics about the library
class LibraryStatistics {
  final int totalSongs;
  final int totalFavorites;
  final int totalAlbums;
  final int totalArtists;

  const LibraryStatistics({
    required this.totalSongs,
    required this.totalFavorites,
    required this.totalAlbums,
    required this.totalArtists,
  });

  // Empty statistics for when library is not loaded
  const LibraryStatistics.empty()
    : totalSongs = 0,
      totalFavorites = 0,
      totalAlbums = 0,
      totalArtists = 0;

  LibraryStatistics copyWith({
    int? totalSongs,
    int? totalFavorites,
    int? totalAlbums,
    int? totalArtists,
  }) {
    return LibraryStatistics(
      totalSongs: totalSongs ?? this.totalSongs,
      totalFavorites: totalFavorites ?? this.totalFavorites,
      totalAlbums: totalAlbums ?? this.totalAlbums,
      totalArtists: totalArtists ?? this.totalArtists,
    );
  }

  @override
  String toString() {
    return 'LibraryStatistics(songs: $totalSongs, favorites: $totalFavorites, albums: $totalAlbums, artists: $totalArtists)';
  }
}

/// State of the Library bounded context
class LibraryState {
  final List<Song> library;
  final List<Song> favorites;
  final List<Song> searchResults;
  final String searchQuery;
  final bool isLoading;
  final bool isSelectingMode;
  final Set<Song> selectedSongs;
  final LibraryStatistics statistics;

  const LibraryState({
    required this.library,
    required this.favorites,
    required this.searchResults,
    required this.searchQuery,
    required this.isLoading,
    required this.isSelectingMode,
    required this.selectedSongs,
    required this.statistics,
  });

  // Initial empty state
  const LibraryState.initial()
    : library = const [],
      favorites = const [],
      searchResults = const [],
      searchQuery = '',
      isLoading = false,
      isSelectingMode = false,
      selectedSongs = const {},
      statistics = const LibraryStatistics.empty();

  LibraryState copyWith({
    List<Song>? library,
    List<Song>? favorites,
    List<Song>? searchResults,
    String? searchQuery,
    bool? isLoading,
    bool? isSelectingMode,
    Set<Song>? selectedSongs,
    LibraryStatistics? statistics,
  }) {
    return LibraryState(
      library: library ?? this.library,
      favorites: favorites ?? this.favorites,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSelectingMode: isSelectingMode ?? this.isSelectingMode,
      selectedSongs: selectedSongs ?? this.selectedSongs,
      statistics: statistics ?? this.statistics,
    );
  }

  // Helper getters
  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get hasSelection => selectedSongs.isNotEmpty;
  bool get isSearchActive => searchQuery.isNotEmpty;
  List<Song> get displaySongs => hasSearchResults ? searchResults : library;

  @override
  String toString() {
    return 'LibraryState(library: ${library.length}, favorites: ${favorites.length}, '
        'searchResults: ${searchResults.length}, query: "$searchQuery", '
        'loading: $isLoading, selecting: $isSelectingMode, selected: ${selectedSongs.length})';
  }
}
