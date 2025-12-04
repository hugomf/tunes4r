import 'dart:io';
import '../models/playlist_import.dart';
import '../models/playlist.dart';
import '../../../models/song.dart';
import 'playlist_parser.dart';
import '../../../services/song_matcher.dart';
import '../../../services/metadata_enricher.dart';

// Main service for importing playlists
class PlaylistImportService {
  final List<Song> library;
  final List<Playlist> existingPlaylists;

  PlaylistImportService({
    required this.library,
    required this.existingPlaylists,
  });

  // Main import workflow
  Future<PlaylistImportResult> importPlaylist(File playlistFile) async {
    // Step 1: Parse the playlist file
    final parsedPlaylist = await PlaylistParser.parseFile(playlistFile);

    // Step 2: Match tracks against library
    final matcher = SongMatcher(library);
    final matchResults = await matcher.matchAllTracks(parsedPlaylist.tracks);

    // Step 3: Create import result summary
    final importResult = PlaylistImportResult(
      playlistName: parsedPlaylist.name,
      trackResults: matchResults,
      importedAt: DateTime.now(),
    );

    return importResult;
  }

  // Confirm and import tracks with manual overrides
  Future<List<Song>> importConfirmedTracks(
    PlaylistImportResult importResult,
    List<TrackImportResult> confirmations,
  ) async {
    final importedSongs = <Song>[];

    for (final confirmation in confirmations) {
      // For tracks that need confirmation, user has selected specific matches
      if (confirmation.matchResult.needsConfirmation) {
        // Use the first alternative or user selection
        final matchedSong = confirmation.alternatives.isNotEmpty
            ? confirmation.alternatives.first
            : confirmation.matchResult.matchedSong;

        if (matchedSong != null) {
          importedSongs.add(matchedSong);
        }
        // Could add logic to add to a created playlist
      } else if (confirmation.matchResult.isMatch) {
        // Auto-matched tracks
        if (confirmation.matchResult.matchedSong != null) {
          importedSongs.add(confirmation.matchResult.matchedSong!);
        }
      }
    }

    return importedSongs;
  }

  // Create a new playlist from imported tracks
  Future<Playlist?> createPlaylistFromImport(
    String playlistName,
    List<Song> importedSongs,
  ) async {
    if (importedSongs.isEmpty) return null;

    // Import the actual database operations from main.dart logic
    // Database operations will be handled in main.dart to avoid circular dependencies

    final now = DateTime.now();
    final playlist = Playlist(
      id: null, // ID will be set later by database insertion in main.dart
      name: playlistName,
      type: PlaylistType.userCreated,
      songs: importedSongs,
      createdAt: now,
      updatedAt: now,
    );

    return playlist;
  }

  // Enrich unmatched tracks with web metadata
  Future<List<EnrichedMetadata>> getMetadataForUnmatched(
    List<TrackImportResult> unmatchedTracks,
  ) async {
    final enricher = MetadataEnricher();
    final tracks = unmatchedTracks
        .where((result) => !result.matchResult.isMatch)
        .map((result) => result.originalTrack)
        .toList();

    return enricher.enrichTracks(tracks);
  }

  // Get metadata for a specific track
  Future<EnrichedMetadata> getMetadataForTrack(
    String title,
    String artist, {
    String? album,
  }) async {
    final enricher = MetadataEnricher();
    return enricher.enrichTrack(title, artist, album: album);
  }

  // Search for tracks by query (for manual finding)
  List<Song> searchLibrary(String query) {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();
    return library.where((song) {
      return song.title.toLowerCase().contains(queryLower) ||
          song.artist.toLowerCase().contains(queryLower) ||
          (song.album.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  // Validate if a playlist name conflicts
  bool playlistNameExists(String name) {
    return existingPlaylists.any(
      (playlist) => playlist.name.toLowerCase() == name.toLowerCase(),
    );
  }

  // Suggest a unique playlist name
  String suggestPlaylistName(String baseName) {
    if (!playlistNameExists(baseName)) {
      return baseName;
    }

    int counter = 1;
    while (true) {
      final suggestion = '$baseName ($counter)';
      if (!playlistNameExists(suggestion)) {
        return suggestion;
      }
      counter++;
    }
  }

  // Get statistics about the import
  Map<String, int> getImportStats(PlaylistImportResult result) {
    return {
      'total_tracks': result.totalTracks,
      'auto_imported': result.autoImported,
      'needs_confirmation': result.needsConfirmation,
      'not_found': result.notFound,
      'import_percentage': result.autoImported * 100 ~/ result.totalTracks,
    };
  }
}

// Simple import preview class for UI
class PlaylistImportPreview {
  final ImportablePlaylist parsedPlaylist;
  final PlaylistImportResult importResult;

  PlaylistImportPreview({
    required this.parsedPlaylist,
    required this.importResult,
  });

  int get totalTracks => importResult.totalTracks;
  int get willBeImported => importResult.autoImported;
  int get needsAction => importResult.needsConfirmation + importResult.notFound;
  double get successRate =>
      totalTracks > 0 ? willBeImported / totalTracks : 0.0;
}

// Import progress tracking
class ImportProgress {
  final String stage; // "parsing", "matching", "importing", "complete"
  final double progress; // 0.0 to 1.0
  final String? message;

  const ImportProgress({
    required this.stage,
    required this.progress,
    this.message,
  });

  ImportProgress.empty() : stage = 'idle', progress = 0.0, message = null;

  ImportProgress copyWith({String? stage, double? progress, String? message}) {
    return ImportProgress(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      message: message ?? this.message,
    );
  }
}

// Import error handling
class PlaylistImportException implements Exception {
  final String message;
  final String? fileName;
  final dynamic originalError;

  PlaylistImportException({
    required this.message,
    this.fileName,
    this.originalError,
  });

  @override
  String toString() =>
      'PlaylistImportException: $message${fileName != null ? ' (File: $fileName)' : ''}';
}

// Validation utilities
class PlaylistImportValidator {
  static bool isValidPlaylistName(String name) {
    return name.trim().isNotEmpty && name.trim().length <= 100;
  }

  static String? validatePlaylistName(String name) {
    name = name.trim();
    if (name.isEmpty) {
      return 'Playlist name cannot be empty';
    }
    if (name.length > 100) {
      return 'Playlist name is too long (max 100 characters)';
    }
    return null; // Valid
  }

  static bool isValidFileForImport(File file) {
    return PlaylistValidator.isValidPlaylistFile(file);
  }

  static String getFileFormat(File file) {
    final extension = file.path.toLowerCase().split('.').last;
    switch (extension) {
      case 'm3u':
      case 'm3u8':
        return 'M3U Playlist';
      case 'pls':
        return 'PLS Playlist';
      default:
        return 'Unknown Format';
    }
  }
}
