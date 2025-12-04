import 'dart:io';
import 'package:path/path.dart' as p;

/// Service responsible for scanning directories to find audio files
/// Handles file system traversal, extension validation, and audio file discovery
class MediaScanService {
  /// Supported audio file extensions
  static const List<String> audioExtensions = [
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.flac',
    '.wav',
    '.wma',
    '.aiff',
    '.opus',
    '.dsd',
    '.dsdiff',
    '.m4b',
    '.m4p',
  ];

  /// Scan a directory recursively for audio files
  Future<List<String>> scanDirectory(String directoryPath) async {
    final List<String> audioFiles = [];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    await for (var entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final extension = p.extension(entity.path).toLowerCase();

        // Skip system files
        if (_shouldSkipFile(fileName, extension)) {
          continue;
        }

        // Check file size (skip very small files)
        if (!await _isValidFileSize(entity)) {
          continue;
        }

        // Check if it's an audio file
        if (audioExtensions.contains(extension)) {
          audioFiles.add(entity.path);
        }
      }
    }

    return audioFiles;
  }

  /// Check if a file should be skipped during scanning
  bool _shouldSkipFile(String fileName, String extension) {
    // Skip macOS resource fork files
    if (fileName.startsWith('._')) {
      return true;
    }

    // Skip hidden files (starting with .)
    if (fileName.startsWith('.')) {
      return true;
    }

    return false;
  }

  /// Check if file size is reasonable for audio files
  Future<bool> _isValidFileSize(File file) async {
    try {
      final fileSize = await file.length();
      // Skip files smaller than 10KB (likely not real music files)
      return fileSize >= 10000;
    } catch (e) {
      // If we can't check size, default to valid
      return true;
    }
  }

  /// Get all supported audio extensions
  List<String> getSupportedExtensions() => audioExtensions;
}
