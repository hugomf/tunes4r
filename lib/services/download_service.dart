import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class DownloadService {
  final String baseUrl;

  DownloadService({this.baseUrl = 'http://127.0.0.1:8000'});

  // Get service status
  Future<Map<String, dynamic>?> getServiceStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error checking download service: $e');
    }
    return null;
  }

  // Search and download a song
  Future<Map<String, dynamic>?> searchSong({String? query, String? title, String? artist}) async {
    if (query != null) {
      // Parse query into title and artist if not provided
      final parts = query.split(' - ');
      if (parts.length == 2) {
        artist = parts[0].trim();
        title = parts[1].trim();
      } else {
        // No separator found, try to parse artist from song name
        final parsed = _parseArtistFromSongName(query);
        artist = parsed['artist'];
        title = parsed['title'];
      }
    }

    return downloadSong(title!, artist!);
  }

  // Smart parsing of artist from song name
  Map<String, String> _parseArtistFromSongName(String query) {
    final words = query.trim().split(' ');

    // Common artist patterns (bands/artists that have multiple words in name)
    final multiWordArtists = [
      'imagine dragons', 'twenty one pilots', 'the beatles', 'queen band',
      'led zeppelin', 'pink floyd', 'coldplay', 'arctic monkeys',
      'the weeknd', 'ed sheeran', 'justin bieber', 'taylor swift',
      'billie eilish', 'dua lipa', 'ariana grande', 'olivia rodrigo',
      'the rolling stones', 'guns n roses', 'foo fighters', 'red hot chili peppers'
    ];

    // Check for exact multi-word artist matches
    for (final artist in multiWordArtists) {
      if (query.toLowerCase().startsWith(artist)) {
        return {
          'artist': artist.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' '),
          'title': query.substring(artist.length).trim()
        };
      }
    }

    // Check for "The [Band]" pattern
    if (words.length >= 2 && words[0].toLowerCase() == 'the') {
      // Look for artist name after "The"
      final remainingQuery = query.substring(4).trim(); // Remove "The "
      for (final artist in multiWordArtists) {
        if (artist.startsWith('the ')) continue; // Avoid double "The"
        if (remainingQuery.toLowerCase().startsWith(artist.replaceFirst('the ', ''))) {
          return {
            'artist': 'The ${artist.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}',
            'title': remainingQuery.substring(artist.length - 4).trim()
          };
        }
      }
    }

    // Check for patterns like "Artist ft." or "Artist featuring"
    final ftIndex = query.toLowerCase().indexOf(' ft');
    final featIndex = query.toLowerCase().indexOf(' feat');

    if (ftIndex != -1) {
      return {
        'artist': query.substring(0, ftIndex).trim(),
        'title': query.substring(ftIndex).trim()
      };
    }

    if (featIndex != -1) {
      return {
        'artist': query.substring(0, featIndex).trim(),
        'title': query.substring(featIndex).trim()
      };
    }

    // Default: if first word is 1-3 words long, treat as artist (common for popular artists)
    if (words.length > 1) {
      final potentialArtistWordCount = words.length > 2 ? 1 : (words.length - 1).clamp(1, 2);

      // Check if first 1-2 words look like an artist name (capitalize properly)
      final potentialArtistWords = words.sublist(0, potentialArtistWordCount);
      final remainingWords = words.sublist(potentialArtistWordCount);

      // If remaining words exist and first artist word is properly cased, assume parsed correctly
      if (remainingWords.isNotEmpty && potentialArtistWords[0].length > 1) {
        return {
          'artist': potentialArtistWords.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' '),
          'title': remainingWords.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ')
        };
      }
    }

    // Fallback: put everything as title with unknown artist
    return {
      'artist': 'Unknown Artist',
      'title': query
    };
  }

  // Download from YouTube URL
  Future<Map<String, dynamic>?> downloadFromUrl(String url) async {
    // For now, treat URL download as a song download with URL as title
    // In a full implementation, this would use yt-dlp directly with the URL
    return downloadSong(url, 'YouTube URL');
  }

  // Download a single song
  Future<Map<String, dynamic>?> downloadSong(String title, String artist) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/download/song'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'artist': artist,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Song not found');
      } else {
        throw Exception('Failed to download song: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Download an album
  Future<Map<String, dynamic>?> downloadAlbum(String artist, String album) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/download/album'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'artist': artist,
          'album': album,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Album not found');
      } else if (response.statusCode == 400) {
        throw Exception('Album has too many tracks or is invalid');
      } else {
        throw Exception('Failed to download album: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search songs
  Future<List<Map<String, dynamic>>?> searchSongs(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/search/songs').replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results']);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during song search: $e');
    }
  }

  // Search albums
  Future<List<Map<String, dynamic>>?> searchAlbums(String query, {int limit = 5}) async {
    try {
      final uri = Uri.parse('$baseUrl/search/albums').replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during album search: $e');
    }
  }

  // Check download status
  Future<Map<String, dynamic>?> getDownloadStatus(String downloadId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status/$downloadId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null; // Download not found
      }
    } catch (e) {
      print('Error checking download status: $e');
    }
    return null;
  }

  // Cancel download
  Future<bool> cancelDownload(String downloadId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/download/$downloadId'));
      if (response.statusCode == 200) {
        print('Successfully cancelled download: $downloadId');
        return true;
      } else if (response.statusCode == 400) {
        print('Cannot cancel download (wrong status): ${response.body}');
        return false;
      } else if (response.statusCode == 404) {
        print('Download not found: $downloadId');
        return false;
      } else {
        print('Cancel failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error cancelling download: $e');
      return false;
    }
  }

  // Convert downloaded songs to Song objects for import
  List<Song> convertDownloadedSongsToSongs(List<dynamic> downloadedSongsList) {
    return downloadedSongsList.map((songMap) {
      return Song(
        title: songMap['title'],
        artist: songMap['artist'] ?? 'Unknown Artist',
        album: songMap['album'] ?? 'Downloaded Music',
        path: songMap['filepath'], // Local path where file was saved
        albumArt: null, // Will be loaded from file metadata
      );
    }).toList();
  }
}
