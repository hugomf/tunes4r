import 'dart:typed_data';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../../models/song.dart';

/// Service responsible for extracting metadata from audio files
/// Handles metadata parsing, fallback processing, and song object creation
class MetadataExtractionService {
  /// Process a single audio file and return a Song object
  Future<Song> extractMetadata(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileName = p.basenameWithoutExtension(filePath);

    try {
      // Extract metadata using audio_metadata_reader
      final metadata = readMetadata(file, getImage: true);

      Uint8List? albumArtBytes;
      if (metadata.pictures.isNotEmpty) {
        albumArtBytes = metadata.pictures.first.bytes;
      }

      final durationMs = metadata.duration?.inMilliseconds;

      return Song(
        title: metadata.title?.trim().isNotEmpty == true
            ? metadata.title!
            : fileName,
        path: filePath,
        artist: metadata.artist?.trim().isNotEmpty == true
            ? metadata.artist!
            : 'Unknown Artist',
        album: metadata.album?.trim().isNotEmpty == true
            ? metadata.album!
            : 'Unknown Album',
        albumArt: albumArtBytes,
        duration: durationMs != null
            ? Duration(milliseconds: durationMs)
            : null,
        trackNumber: metadata.trackNumber ?? metadata.trackTotal,
      );
    } catch (e) {
      // Fallback - create song with basic info
      return Song(
        title: fileName,
        path: filePath,
        artist: 'Unknown Artist',
        album: 'Unknown Album',
      );
    }
  }

  /// Process multiple audio files and return Song objects
  Future<List<Song>> extractMultipleMetadata(List<String> filePaths) async {
    final List<Song> songs = [];

    for (var path in filePaths) {
      final song = await extractMetadata(path);
      songs.add(song);
    }

    return songs;
  }
}
