// import 'dart:io';
// import 'dart:typed_data';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/song.dart';

class MediaService {
  /// Scans a directory recursively for audio files
  Future<List<String>> getAudioFilesFromDirectory(String dirPath) async {
    final List<String> audioFiles = [];
    final directory = Directory(dirPath);

    try {
      await for (var entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          if (_isAudioExtension(extension)) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
    }

    return audioFiles;
  }

  /// Checks if a file extension is an audio format
  bool _isAudioExtension(String extension) {
    const supportedExtensions = [
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.flac',
      '.wav',
      '.wma',
      '.aiff',
    ];
    return supportedExtensions.contains(extension);
  }

  /// Processes a list of audio file paths and extracts metadata
  Future<List<Song>> processAudioFiles(List<String> filePaths) async {
    List<Song> newSongs = [];

    for (var path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final fileName = p.basenameWithoutExtension(path);

      try {
        final metadata = readMetadata(file, getImage: true);
        final song = await _createSongFromMetadata(path, metadata, fileName);
        newSongs.add(song);
      } catch (e) {
        print('Error reading metadata for $fileName: $e');
        // Fallback to basic song creation
        newSongs.add(
          Song(title: fileName, path: path, artist: 'Unknown Artist'),
        );
      }
    }

    return newSongs;
  }

  /// Creates a Song object from audio metadata
  Future<Song> _createSongFromMetadata(
    String path,
    dynamic metadata,
    String fileName,
  ) async {
    Uint8List? albumArtBytes;
    if (metadata.pictures.isNotEmpty) {
      albumArtBytes = metadata.pictures.first.bytes;
    }

    final durationMs = metadata.duration?.inMilliseconds;

    return Song(
      title: metadata.title?.trim().isNotEmpty == true
          ? metadata.title!
          : fileName,
      path: path,
      artist: metadata.artist?.trim().isNotEmpty == true
          ? metadata.artist!
          : 'Unknown Artist',
      album: metadata.album?.trim().isNotEmpty == true
          ? metadata.album!
          : 'Unknown Album',
      albumArt: albumArtBytes,
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      trackNumber: metadata.trackNumber ?? metadata.trackTotal,
    );
  }
}
