import 'dart:math' as math;
import '../playlist/models/playlist_import.dart';
import '../models/song.dart';

// Smart matching engine for finding songs in library
class SongMatcher {
  final List<Song> library;

  SongMatcher(this.library);

  // Main matching function
  Future<List<TrackImportResult>> matchAllTracks(
    List<ImportableTrack> tracks,
  ) async {
    final results = <TrackImportResult>[];

    for (final track in tracks) {
      final result = await matchTrack(track);
      results.add(result);
    }

    return results;
  }

  // Match a single track
  Future<TrackImportResult> matchTrack(ImportableTrack track) async {
    // Strategy 1: Exact title + artist match (highest priority)
    final exactMatches = _findExactMatches(track);
    if (exactMatches.isNotEmpty) {
      return TrackImportResult(
        originalTrack: track,
        matchResult: MatchResult(
          matchedSong: exactMatches.first,
          confidence: MatchConfidence.exact,
          score: 1.0,
          reason: 'Exact title and artist match',
        ),
      );
    }

    // Strategy 2: Fuzzy title + artist match
    final fuzzyMatches = _findFuzzyMatches(track);
    if (fuzzyMatches.isNotEmpty) {
      final bestMatch = fuzzyMatches.first;
      if (bestMatch.score >= 0.85) {
        return TrackImportResult(
          originalTrack: track,
          matchResult: MatchResult(
            matchedSong: bestMatch.song,
            confidence: MatchConfidence.high,
            score: bestMatch.score,
            reason:
                'High confidence fuzzy match: ${bestMatch.score.toStringAsFixed(2)}',
          ),
        );
      } else if (bestMatch.score >= 0.7) {
        return TrackImportResult(
          originalTrack: track,
          matchResult: MatchResult(
            matchedSong: bestMatch.song,
            confidence: MatchConfidence.medium,
            score: bestMatch.score,
            reason:
                'Medium confidence: ${bestMatch.score.toStringAsFixed(2)}, manual confirmation needed',
          ),
        );
      }
    }

    // Strategy 3: Title-only match
    final titleMatches = _findTitleOnlyMatches(track);
    if (titleMatches.isNotEmpty) {
      final bestMatch = titleMatches.first;
      if (bestMatch.score >= 0.8) {
        return TrackImportResult(
          originalTrack: track,
          matchResult: MatchResult(
            matchedSong: bestMatch.song,
            confidence: MatchConfidence.medium,
            score: bestMatch.score * 0.8, // Lower score since no artist match
            reason:
                'Title match only (${bestMatch.score.toStringAsFixed(2)}), multiple artists available',
          ),
          alternatives: titleMatches.map((m) => m.song).toList(),
        );
      }
    }

    // Strategy 4: Filename-based matching (last resort)
    final filenameMatches = _findFilenameMatches(track);
    if (filenameMatches.isNotEmpty) {
      return TrackImportResult(
        originalTrack: track,
        matchResult: MatchResult(
          matchedSong: filenameMatches.first.song,
          confidence: MatchConfidence.low,
          score: filenameMatches.first.score * 0.6, // Low confidence
          reason:
              'Filename similarity (${filenameMatches.first.score.toStringAsFixed(2)}), confirmation needed',
        ),
        alternatives: filenameMatches.take(3).map((m) => m.song).toList(),
      );
    }

    // No match found
    return TrackImportResult(
      originalTrack: track,
      matchResult: MatchResult(
        matchedSong: null,
        confidence: MatchConfidence.none,
        score: 0.0,
        reason: 'No matching song found in library',
      ),
    );
  }

  // Find exact title + artist matches
  List<Song> _findExactMatches(ImportableTrack track) {
    if (track.artist == null) return [];

    return library.where((song) {
      return _normalizeString(song.title) == _normalizeString(track.title) &&
          _normalizeString(song.artist) == _normalizeString(track.artist!);
    }).toList();
  }

  // Find fuzzy matches using string similarity
  List<MatchScore> _findFuzzyMatches(ImportableTrack track) {
    if (track.artist == null) return [];

    final scores = <MatchScore>[];

    for (final song in library) {
      final titleScore = _calculateSimilarity(track.title, song.title);
      final artistScore = track.artist != null
          ? _calculateSimilarity(track.artist!, song.artist)
          : 0.0;

      // Weight: 70% title, 30% artist
      final combinedScore = (titleScore * 0.7) + (artistScore * 0.3);

      scores.add(MatchScore(song: song, score: combinedScore));
    }

    // Sort by score descending and return top matches
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.where((s) => s.score > 0.5).take(5).toList();
  }

  // Find title-only matches
  List<MatchScore> _findTitleOnlyMatches(ImportableTrack track) {
    final scores = <MatchScore>[];

    for (final song in library) {
      final score = _calculateSimilarity(track.title, song.title);
      if (score > 0.7) {
        scores.add(MatchScore(song: song, score: score));
      }
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(5).toList();
  }

  // Find filename-based matches
  List<MatchScore> _findFilenameMatches(ImportableTrack track) {
    final scores = <MatchScore>[];

    for (final song in library) {
      final fileName = _extractFilename(song.path);
      final score = _calculateSimilarity(track.title, fileName);
      if (score > 0.6) {
        scores.add(MatchScore(song: song, score: score));
      }
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(3).toList();
  }

  // Calculate string similarity (simplified Levenshtein-like approach)
  double _calculateSimilarity(String a, String b) {
    final normalizedA = _normalizeString(a);
    final normalizedB = _normalizeString(b);

    if (normalizedA == normalizedB) return 1.0;

    // Exact substring match
    if (normalizedA.contains(normalizedB) ||
        normalizedB.contains(normalizedA)) {
      return 0.9;
    }

    // Word overlap similarity
    final wordsA = normalizedA.split(' ');
    final wordsB = normalizedB.split(' ');

    int commonWords = 0;
    for (final wordA in wordsA) {
      if (wordA.length < 3) continue; // Skip very short words
      for (final wordB in wordsB) {
        if (wordB.length < 3) continue;
        if (_wordsSimilar(wordA, wordB)) {
          commonWords++;
          break;
        }
      }
    }

    final overlapScore = commonWords / math.max(wordsA.length, wordsB.length);

    // Boost score if it's reasonably high
    return math.min(overlapScore * 1.2, 0.85);
  }

  // Check if two words are similar (exact, substring, or edit distance)
  bool _wordsSimilar(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;

    // Simple edit distance check for small words
    if (a.length <= 4 && b.length <= 4) {
      return _levenshteinDistance(a, b) <= 1;
    }

    return false;
  }

  // Simple Levenshtein distance calculation
  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List<int>.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          matrix[i - 1][j] + 1, // deletion
          math.min(
            matrix[i][j - 1] + 1, // insertion
            matrix[i - 1][j - 1] + cost, // substitution
          ),
        );
      }
    }

    return matrix[a.length][b.length];
  }

  // Normalize strings for comparison
  String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }

  // Extract filename from path
  String _extractFilename(String path) {
    final parts = path.split('/');
    final file = parts.last.split('.');
    if (file.length > 1) {
      file.removeLast(); // Remove extension
    }
    return file.join('.').replaceAll('_', ' ').replaceAll('-', ' ');
  }
}

// Helper class for match scoring
class MatchScore {
  final Song song;
  final double score;

  MatchScore({required this.song, required this.score});
}
