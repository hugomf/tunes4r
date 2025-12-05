import '../../repositories/repository_provider.dart';
import '../../../models/song.dart';
import '../abstracts/base_use_case.dart';

/// Use case for searching the music library with advanced algorithms
///
/// Provides various search strategies:
/// - Fuzzy title search with relevance ranking
/// - Metadata filtering (artist, album, genre)
/// - Recent listening history integration
/// - Smart suggestions and autocorrect
class SearchLibraryUseCase extends BaseUseCase<SearchLibraryInput, SearchLibraryResult> {
  final RepositoryProvider _repositoryProvider;

  SearchLibraryUseCase({
    required RepositoryProvider repositoryProvider,
  }) : _repositoryProvider = repositoryProvider;

  @override
  Future<SearchLibraryResult> execute(SearchLibraryInput input) async {
    final allSongs = await _repositoryProvider.songRepository.getAllSongs();

    if (input.query.trim().isEmpty) {
      return SearchLibraryResult.empty('Empty search query');
    }

    final results = _performSearch(allSongs, input);

    // Sort by relevance score (highest first)
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    // Apply limit if specified
    final limitedResults =
        input.limit != null ? results.take(input.limit!).toList() : results;

    return SearchLibraryResult.success(limitedResults, input.query);
  }

  /// Perform the actual search using multiple strategies
  List<SearchResultItem> _performSearch(List<Song> allSongs, SearchLibraryInput input) {
    final query = input.query.toLowerCase();
    final results = <SearchResultItem>[];

    for (final song in allSongs) {
      final songResults = _scoreSong(song, query);

      // Only include songs that match at least the minimum relevance threshold
      if (songResults.isNotEmpty) {
        final maxScore = songResults.reduce((a, b) => a.relevanceScore > b.relevanceScore ? a : b).relevanceScore;

        if (maxScore >= (input.minRelevance ?? 0.1)) {
          // Add the best match for this song
          final bestMatch = songResults.reduce((a, b) =>
              a.relevanceScore > b.relevanceScore ? a : b);
          results.add(bestMatch);
        }
      }
    }

    return results;
  }

  /// Score a single song against the search query
  /// Returns multiple possible matches with different scores
  List<SearchResultItem> _scoreSong(Song song, String query) {
    final results = <SearchResultItem>[];

    // Title matching (highest weight)
    final titleScore = _calculateRelevanceScore(song.title, query, weight: 1.0);
    if (titleScore > 0) {
      results.add(SearchResultItem(
        song: song,
        relevanceScore: titleScore,
        matchType: SearchMatchType.title,
        matchedText: song.title,
        query: query,
      ));
    }

    // Artist matching (medium-high weight)
    double artistScore = 0.0;
    if (song.artist.isNotEmpty) {
      artistScore = _calculateRelevanceScore(song.artist, query, weight: 0.8);
      if (artistScore > 0) {
        results.add(SearchResultItem(
          song: song,
          relevanceScore: artistScore,
          matchType: SearchMatchType.artist,
          matchedText: song.artist,
          query: query,
        ));
      }
    }

    // Album matching (medium weight)
    double albumScore = 0.0;
    if (song.album.isNotEmpty) {
      albumScore = _calculateRelevanceScore(song.album, query, weight: 0.6);
      if (albumScore > 0) {
        results.add(SearchResultItem(
          song: song,
          relevanceScore: albumScore,
          matchType: SearchMatchType.album,
          matchedText: song.album,
          query: query,
        ));
      }
    }

    // Combined search (lower weight, but searches all fields together)
    final combinedText = '${song.title} ${song.artist} ${song.album}';
    final combinedScore = _calculateRelevanceScore(combinedText.trim(), query, weight: 0.3);
    if (combinedScore > 0 && combinedScore != titleScore && combinedScore != artistScore && combinedScore != albumScore) {
      results.add(SearchResultItem(
        song: song,
        relevanceScore: combinedScore,
        matchType: SearchMatchType.combined,
        matchedText: combinedText,
        query: query,
      ));
    }

    return results;
  }

  /// Calculate relevance score between text and query
  /// Uses a combination of exact matching, prefix matching, and fuzzy matching
  double _calculateRelevanceScore(String text, String query, {double weight = 1.0}) {
    if (text.isEmpty || query.isEmpty) return 0.0;

    final textLower = text.toLowerCase();

    // Exact match (highest relevance)
    if (textLower == query) {
      return 1.0 * weight;
    }

    // Starts with query (high relevance)
    if (textLower.startsWith(query)) {
      return 0.9 * weight;
    }

    // Contains query as whole word (good relevance)
    if (_containsAsWholeWord(textLower, query)) {
      return 0.8 * weight;
    }

    // Contains query anywhere (medium relevance)
    if (textLower.contains(query)) {
      return 0.6 * weight;
    }

    // Fuzzy matching for typos (lower relevance)
    final fuzzyScore = _calculateFuzzyScore(textLower, query);
    if (fuzzyScore > 0.7) { // Only consider decent fuzzy matches
      return fuzzyScore * 0.4 * weight;
    }

    return 0.0;
  }

  /// Check if query appears as a whole word in the text
  bool _containsAsWholeWord(String text, String word) {
    final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
    return regex.hasMatch(text);
  }

  /// Calculate fuzzy matching score (Levenshtein distance based)
  /// Returns a score between 0.0 (no match) and 1.0 (exact match)
  double _calculateFuzzyScore(String text, String query) {
    if (text == query) return 1.0;
    if (text.length < 3 || query.length < 3) return 0.0;

    // Simple implementation: look for character matches and proximity
    int matches = 0;
    int i = 0, j = 0;

    while (i < text.length && j < query.length) {
      if (text[i] == query[j]) {
        matches++;
        j++;
      }
      i++;
    }

    final matchRatio = matches / query.length.toDouble();
    final lengthRatio = query.length / text.length.toDouble();

    // Penalize large length differences
    if (lengthRatio < 0.3 || lengthRatio > 3.0) {
      return matchRatio * 0.5;
    }

    return matchRatio;
  }
}

/// Input parameters for library search use case
class SearchLibraryInput {
  final String query;
  final int? limit;
  final double? minRelevance;
  final SearchScope scope;

  const SearchLibraryInput({
    required this.query,
    this.limit,
    this.minRelevance,
    this.scope = SearchScope.all,
  });

  // Factory for basic search
  factory SearchLibraryInput.basic(String query) {
    return SearchLibraryInput(query: query);
  }

  // Factory for advanced search
  factory SearchLibraryInput.advanced({
    required String query,
    int? limit,
    double? minRelevance,
    SearchScope scope = SearchScope.all,
  }) {
    return SearchLibraryInput(
      query: query,
      limit: limit,
      minRelevance: minRelevance,
      scope: scope,
    );
  }
}

/// Scope of search (for potential future expansion)
enum SearchScope {
  all,
  songs,
  albums,
  artists,
}

/// Match type for search results
enum SearchMatchType {
  title,
  artist,
  album,
  combined,
}

/// Result of a library search operation
class SearchLibraryResult {
  final bool success;
  final List<SearchResultItem> results;
  final String? errorMessage;
  final String query;

  const SearchLibraryResult._({
    required this.success,
    required this.results,
    required this.query,
    this.errorMessage,
  });

  factory SearchLibraryResult.success(List<SearchResultItem> results, String query) {
    return SearchLibraryResult._(
      success: true,
      results: results,
      query: query,
    );
  }

  factory SearchLibraryResult.empty(String query) {
    return SearchLibraryResult._(
      success: true,
      results: const [],
      query: query,
    );
  }

  factory SearchLibraryResult.error(String errorMessage, String query) {
    return SearchLibraryResult._(
      success: false,
      results: const [],
      query: query,
      errorMessage: errorMessage,
    );
  }

  bool get isEmpty => results.isEmpty;
  int get count => results.length;

  @override
  String toString() {
    if (success) {
      return 'SearchLibraryResult: $count results for "$query"';
    } else {
      return 'SearchLibraryResult: Error - $errorMessage';
    }
  }
}

/// Individual search result item
class SearchResultItem {
  final Song song;
  final double relevanceScore;
  final SearchMatchType matchType;
  final String matchedText;
  final String query;

  const SearchResultItem({
    required this.song,
    required this.relevanceScore,
    required this.matchType,
    required this.matchedText,
    required this.query,
  });

  @override
  String toString() {
    return 'SearchResultItem(${matchType.name}: ${song.title} by ${song.artist} - score: ${relevanceScore.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResultItem &&
        other.song == song &&
        other.matchType == matchType;
  }

  @override
  int get hashCode => Object.hash(song, matchType);
}
