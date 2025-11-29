import 'song.dart';

// Model for tracks parsed from playlist files
class ImportableTrack {
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? originalLine; // Raw line from playlist file

  const ImportableTrack({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.originalLine,
  });

  // Create from M3U entry (simplified parsing)
  factory ImportableTrack.fromM3U(String line) {
    if (line.startsWith('#') || line.trim().isEmpty) {
      throw FormatException('Invalid M3U entry');
    }

    // Basic parsing - could be enhanced
    final parts = line.split(' - ');
    if (parts.length >= 2) {
      return ImportableTrack(
        title: parts.last.trim(),
        artist: parts.first.trim(),
        originalLine: line,
      );
    } else {
      return ImportableTrack(
        title: line.trim(),
        originalLine: line,
      );
    }
  }
}

// Result of matching a track against the library
enum MatchConfidence { none, low, medium, high, exact }

class MatchResult {
  final Song? matchedSong;
  final MatchConfidence confidence;
  final double score; // 0.0 to 1.0
  final String reason;

  const MatchResult({
    this.matchedSong,
    required this.confidence,
    required this.score,
    required this.reason,
  });

  bool get isMatch => confidence != MatchConfidence.none;
  bool get needsConfirmation => confidence == MatchConfidence.medium || confidence == MatchConfidence.low;
}

// Complete import result for a track
class TrackImportResult {
  final ImportableTrack originalTrack;
  final MatchResult matchResult;
  final List<Song> alternatives;

  TrackImportResult({
    required this.originalTrack,
    required this.matchResult,
    this.alternatives = const [],
  });

  bool get willBeImported => matchResult.isMatch && !matchResult.needsConfirmation;
  bool get needsConfirmation => matchResult.needsConfirmation;
  bool get notFound => !matchResult.isMatch;
}

// Summary of an entire playlist import
class PlaylistImportResult {
  final String playlistName;
  final List<TrackImportResult> trackResults;
  final DateTime importedAt;

  PlaylistImportResult({
    required this.playlistName,
    required this.trackResults,
    required this.importedAt,
  });

  int get totalTracks => trackResults.length;
  int get autoImported => trackResults.where((r) => r.willBeImported).length;
  int get needsConfirmation => trackResults.where((r) => r.needsConfirmation).length;
  int get notFound => trackResults.where((r) => r.notFound).length;
}

// Playlist data parsed but not yet imported
class ImportablePlaylist {
  final String name;
  final List<ImportableTrack> tracks;

  const ImportablePlaylist({
    required this.name,
    required this.tracks,
  });
}

// Web metadata enrichment data
class EnrichedMetadata {
  final String? coverArtUrl;
  final String? genre;
  final String? releaseYear;
  final Map<String, dynamic> additionalData;

  const EnrichedMetadata({
    this.coverArtUrl,
    this.genre,
    this.releaseYear,
    this.additionalData = const {},
  });
}
