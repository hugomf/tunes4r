import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/playlist_import.dart';
import '../models/song.dart';

// Service for enriching song metadata using web APIs
class MetadataEnricher {
  // Last.fm API configuration (free API key needed)
  static const String _lastFmApiKey = 'YOUR_LASTFM_API_KEY'; // Replace with actual key

  // Cache to avoid repeated API calls
  final Map<String, EnrichedMetadata> _cache = {};

  // Enrich a single track with web metadata
  Future<EnrichedMetadata> enrichTrack(String title, String artist, {String? album}) async {
    final cacheKey = '$artist-$title'.toLowerCase();

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final metadata = await _fetchFromLastFm(title, artist, album);
      _cache[cacheKey] = metadata;
      return metadata;
    } catch (e) {
      // Fallback: return empty metadata instead of failing
      final fallback = EnrichedMetadata();
      _cache[cacheKey] = fallback;
      return fallback;
    }
  }

  // Enrich multiple tracks in batch
  Future<List<EnrichedMetadata>> enrichTracks(List<ImportableTrack> tracks) async {
    final results = <EnrichedMetadata>[];

    for (final track in tracks) {
      final metadata = await enrichTrack(
        track.title,
        track.artist ?? '',
        album: track.album,
      );
      results.add(metadata);
    }

    return results;
  }

  // Fetch metadata from Last.fm API
  Future<EnrichedMetadata> _fetchFromLastFm(String title, String artist, String? album) async {
    if (_lastFmApiKey == 'YOUR_LASTFM_API_KEY') {
      return EnrichedMetadata(); // Return empty if no API key
    }

    try {
      // Search for track info
      final trackUrl = Uri.parse(
        'http://ws.audioscrobbler.com/2.0/?method=track.getInfo'
        '&api_key=$_lastFmApiKey&artist=${Uri.encodeComponent(artist)}'
        '&track=${Uri.encodeComponent(title)}&format=json'
      );

      final trackResponse = await http.get(trackUrl);

      if (trackResponse.statusCode != 200) {
        return EnrichedMetadata();
      }

      final trackData = json.decode(trackResponse.body);

      String? coverArtUrl;
      String? genre;
      String? releaseYear;
      final additionalData = <String, dynamic>{};

      if (trackData['track'] != null) {
        final track = trackData['track'];

        // Extract album art
        if (track['album'] != null && track['album']['image'] != null) {
          final images = track['album']['image'] as List;
          // Get the largest image available
          for (final img in images.reversed) {
            if (img['#text'] != null && img['#text'].isNotEmpty) {
              coverArtUrl = img['#text'];
              break;
            }
          }
        }

        // Extract tags/genres
        if (track['toptags'] != null && track['toptags']['tag'] != null) {
          final tags = track['toptags']['tag'];
          if (tags is List && tags.isNotEmpty) {
            genre = tags[0]['name'];
            additionalData['genres'] = tags.take(3).map((t) => t['name']).toList();
          }
        }

        // Store additional metadata
        if (track['duration'] != null) {
          additionalData['duration_ms'] = int.tryParse(track['duration'].toString());
        }

        if (track['listeners'] != null) {
          additionalData['listeners'] = int.tryParse(track['listeners'].toString());
        }

        if (track['playcount'] != null) {
          additionalData['playcount'] = int.tryParse(track['playcount'].toString());
        }

        // Try to get release year from album or wiki
        if (track['album'] != null && track['album']['wiki'] != null) {
          final wikiContent = track['album']['wiki']['content'] ?? '';
          final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(wikiContent);
          if (yearMatch != null) {
            releaseYear = yearMatch.group(0);
          }
        }
      }

      return EnrichedMetadata(
        coverArtUrl: coverArtUrl,
        genre: genre,
        releaseYear: releaseYear,
        additionalData: additionalData,
      );

    } catch (e) {
      // Log error but don't fail
      print('Error fetching metadata for $artist - $title: $e');
      return EnrichedMetadata();
    }
  }

  // Get artist top albums (for additional context)
  Future<List<String>> getArtistTopAlbums(String artist) async {
    if (_lastFmApiKey == 'YOUR_LASTFM_API_KEY') {
      return [];
    }

    try {
      final url = Uri.parse(
        'http://ws.audioscrobbler.com/2.0/?method=artist.getTopAlbums'
        '&api_key=$_lastFmApiKey&artist=${Uri.encodeComponent(artist)}&limit=5&format=json'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['topalbums'] != null && data['topalbums']['album'] != null) {
          final albums = data['topalbums']['album'] as List;
          return albums.map((a) => a['name'].toString()).toList();
        }
      }
    } catch (e) {
      print('Error fetching artist albums for $artist: $e');
    }

    return [];
  }

  // Clear cache (useful for memory management)
  void clearCache() {
    _cache.clear();
  }

  // Get cache size for debugging
  int get cacheSize => _cache.length;
}

// Extended metadata for already matched songs
class SongMetadataViewer {
  final MetadataEnricher _enricher = MetadataEnricher();

  // Get enhanced view of a song with web data
  Future<EnrichedSongView> getEnrichedSongView(Song song) async {
    final enrichedMetadata = await _enricher.enrichTrack(song.title, song.artist, album: song.album);

    return EnrichedSongView(
      song: song,
      enrichedMetadata: enrichedMetadata,
    );
  }

  // Batch enrich multiple songs
  Future<List<EnrichedSongView>> getEnrichedSongViews(List<Song> songs) async {
    final views = <EnrichedSongView>[];

    for (final song in songs) {
      final view = await getEnrichedSongView(song);
      views.add(view);
    }

    return views;
  }
}

// Enhanced song view with web metadata
class EnrichedSongView {
  final Song song;
  final EnrichedMetadata enrichedMetadata;

  EnrichedSongView({
    required this.song,
    required this.enrichedMetadata,
  });

  // Get the best available cover art URL
  String? get bestCoverArt {
    return enrichedMetadata.coverArtUrl ?? song.albumArt?.toString();
  }

  // Get genre information
  String? get genre => enrichedMetadata.genre;

  // Get formatted metadata summary
  String getMetadataSummary() {
    final parts = <String>[];

    if (enrichedMetadata.genre != null) {
      parts.add('Genre: ${enrichedMetadata.genre}');
    }

    if (enrichedMetadata.releaseYear != null) {
      parts.add('Year: ${enrichedMetadata.releaseYear}');
    }

    if (enrichedMetadata.additionalData['listeners'] != null) {
      final listeners = enrichedMetadata.additionalData['listeners'];
      parts.add('$_listeners listeners');
    }

    return parts.isEmpty ? 'No additional metadata available' : parts.join(' • ');
  }

  String _listeners(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// Utility functions for metadata processing
class MetadataUtils {
  // Extract year from various date formats
  static String? extractYear(String dateString) {
    final patterns = [
      RegExp(r'\b(19|20)\d{2}\b'), // YYYY
      RegExp(r'\b(19|20)\d{2}-\d{2}-\d{2}\b'), // YYYY-MM-DD
      RegExp(r'\b\d{2}/\d{2}/(19|20)\d{2}\b'), // MM/DD/YYYY
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateString);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  // Clean up genre strings
  static String normalizeGenre(String genre) {
    return genre
        .toLowerCase()
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word)
        .join(' ')
        .trim();
  }

  // Validate cover art URLs
  static bool isValidImageUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Check for common image extensions
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
           path.endsWith('.jpeg') ||
           path.endsWith('.png') ||
           path.endsWith('.webp');
  }
}
