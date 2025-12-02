import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/library_service.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class FileImportService {
  final DatabaseService _databaseService;
  final LibraryService _libraryService;

  FileImportService(this._databaseService, {LibraryService? libraryService})
      : _libraryService = libraryService ?? LibraryService(_databaseService);

  /// Main entry point for file import process
  /// Returns the number of songs added, or -1 if cancelled
  Future<int> importFiles(BuildContext context) async {
    try {
      print('🎵 Starting file selection process...');

      // Step 1: Handle platform-specific permission requirements
      // Skip permission checks on macOS due to plugin compatibility issues
      bool isMacOS = !kIsWeb && Platform.isMacOS;
      if (isMacOS) {
        print('🎵 Running on macOS - skipping permission checks due to plugin limitations');
      } else {
        print('🎵 Running on ${kIsWeb ? 'web' : Platform.operatingSystem} - attempting permission checks...');
        try {
          // Only attempt permission checks on platforms where the plugin works
          final audioPermission = await Permission.audio.status;
          if (!audioPermission.isGranted) {
            await Permission.audio.request();
          }
        } catch (permissionError) {
          print('🎵 Permission check failed but continuing: $permissionError');
        }
      }

      print('🎵 Permission handling complete - proceeding with file picker...');

      // Step 2: Let user choose between files and folders
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          title: Text(
            'Select Music',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          content: Text(
            'Would you like to select individual files or a folder?',
            style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('files'),
              style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.primaryColor),
              child: const Text('Files'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('folder'),
              style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.secondary),
              child: const Text('Folder'),
            ),
          ],
        ),
      );

      if (result == null) return -1; // Cancelled

      // Step 3: Pick files based on user choice
      List<String> audioFilePaths = [];

      if (result == 'files') {
        FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: true,
        );

        if (fileResult != null && fileResult.files.isNotEmpty) {
          audioFilePaths = fileResult.files
              .map((f) => f.path)
              .where((path) => path != null)
              .cast<String>()
              .toList();
        }
      } else {
        // Pick a folder
        String? folderPath = await FilePicker.platform.getDirectoryPath();

        if (folderPath != null) {
          try {
            audioFilePaths = await _getAudioFilesFromDirectory(folderPath);
            print('🎵 Scanned folder "$folderPath" and found ${audioFilePaths.length} music files');
          } catch (e) {
            print('🎵 Folder scan failed: $e');

            // Show dialog explaining folder access issues
            if (context.mounted) {
              await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  backgroundColor: ThemeColorsUtil.surfaceColor,
                  title: Text(
                    'Folder Access Needed',
                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                  ),
                  content: Text(
                    'Tunes4R needs full storage access to scan music folders. This requires special "All files access" permission on newer Android versions.\n\n'
                    'Please:\n'
                    '1. Tap "Open Settings" below\n'
                    '2. Find "Tunes4R" in the list\n'
                    '3. Enable "All files access" or "Allow access to all files"\n'
                    '4. Return to the app and try again\n\n'
                    'This permission allows Tunes4R to scan your entire music library.',
                    style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await openAppSettings();
                        } catch (e) {
                          print('🎵 Failed to open app settings: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to open settings on this platform',
                                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                                ),
                                backgroundColor: ThemeColorsUtil.error,
                              ),
                            );
                          }
                        }
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(
                        'Open Settings',
                        style: TextStyle(color: ThemeColorsUtil.primaryColor),
                      ),
                    ),
                  ],
                ),
              );
            }
            return -1; // Cancelled due to folder access issues
          }
        }
      }

      if (audioFilePaths.isEmpty) return 0;

      // Step 4: Process and import the files
      final resultCount = await _importAudioFiles(audioFilePaths, context);
      return resultCount;

    } catch (e) {
      print('Error picking files: $e');

      // Check if this is a permission plugin issue
      if (e.toString().contains('MissingPluginException') &&
          e.toString().contains('checkPermissionStatus')) {
        print('🎵 Permission plugin not available - proceeding anyway...');

        // Show a friendly message instead of the technical error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File picker ready - select your music files',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.primaryColor,
            ),
          );
        }

        // Try to open file picker directly without permissions
        try {
          print('🎵 Opening file picker directly...');
          FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: true,
          );

          if (fileResult != null && fileResult.files.isNotEmpty) {
            final List<String> audioFilePaths = fileResult.files
                .map((f) => f.path)
                .where((path) => path != null)
                .cast<String>()
                .toList();

            return await _importAudioFiles(audioFilePaths, context);
          }
        } catch (fallbackError) {
          print('🎵 File picker fallback failed: $fallbackError');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File picker unavailable. Try running on a different platform.',
                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                ),
                backgroundColor: ThemeColorsUtil.error,
              ),
            );
          }
        }
      } else {
        // Show the original error for other types of errors
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error adding music: $e',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.error,
            ),
          );
        }
      }
    }
    return 0;
  }

  /// Process and import audio files to the database
  Future<int> _importAudioFiles(List<String> filePaths, BuildContext context) async {
    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Adding music files...',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    }

    // Process all audio files
    final newSongs = await _processAudioFiles(filePaths);

    // Save to database via library service
    for (var song in newSongs) {
      await _libraryService.saveSong(song);
    }

    print('Added ${newSongs.length} songs to library');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${newSongs.length} ${newSongs.length == 1 ? 'song' : 'songs'} to library!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    }

    return newSongs.length;
  }

  /// Scan a directory for audio files recursively
  Future<List<String>> _getAudioFilesFromDirectory(String dirPath) async {
    final List<String> audioFiles = [];
    final directory = Directory(dirPath);

    try {
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          // Check for common audio file extensions
          if (['.mp3', '.m4a', '.aac', '.ogg', '.flac', '.wav', '.wma', '.aiff'].contains(extension)) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
    }

    return audioFiles;
  }

  /// Process audio files and extract metadata
  Future<List<Song>> _processAudioFiles(List<String> filePaths) async {
    List<Song> newSongs = [];

    for (var path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final fileName = p.basenameWithoutExtension(path);

      try {
        // Extract metadata using audio_metadata_reader
        final metadata = readMetadata(file, getImage: true);

        Uint8List? albumArtBytes;
        if (metadata.pictures.isNotEmpty) {
          albumArtBytes = metadata.pictures.first.bytes;
        }

        final durationMs = metadata.duration?.inMilliseconds;

        newSongs.add(Song(
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
          duration: durationMs != null
              ? Duration(milliseconds: durationMs)
              : null,
          trackNumber: metadata.trackNumber ?? metadata.trackTotal,
        ));
      } catch (e) {
        print('Error reading metadata for $fileName: $e');
        // Fallback - create song with basic info
        newSongs.add(Song(
          title: fileName,
          path: path,
          artist: 'Unknown Artist',
          album: 'Unknown Album',
        ));
      }
    }

    return newSongs;
  }
}
