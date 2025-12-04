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
import 'package:tunes4r/library/library.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/library/library_commands.dart';

class FileImportService {
  final DatabaseService _databaseService;
  final LibraryService _libraryService;
  final Library? _libraryContext;

  FileImportService(
    this._databaseService, {
    LibraryService? libraryService,
    Library? libraryContext,
  }) : _libraryService = libraryService ?? LibraryService(_databaseService),
       _libraryContext = libraryContext;

  /// Main entry point for file import process
  /// Returns the number of songs added, or -1 if cancelled
  Future<int> importFiles(BuildContext context) async {
    try {
      print('🎵 Starting file selection process...');

      // Step 1: Handle platform-specific permission requirements
      // Skip permission checks on macOS due to plugin compatibility issues
      bool isMacOS = !kIsWeb && Platform.isMacOS;
      bool isAndroid = !kIsWeb && Platform.isAndroid;

      if (isMacOS) {
        print(
          '🎵 Running on macOS - skipping permission checks due to plugin limitations',
        );
      } else {
        print(
          '🎵 Running on ${kIsWeb ? 'web' : Platform.operatingSystem} - attempting permission checks...',
        );
        try {
          if (isAndroid) {
            // On Android 11+, we need MANAGE_EXTERNAL_STORAGE for full folder access
            final manageStoragePermission =
                await Permission.manageExternalStorage.status;
            print(
              '🎵 MANAGE_EXTERNAL_STORAGE status: ${manageStoragePermission.toString()}',
            );

            if (!manageStoragePermission.isGranted) {
              print('🎵 Requesting MANAGE_EXTERNAL_STORAGE permission...');
              final result = await Permission.manageExternalStorage.request();
              print(
                '🎵 MANAGE_EXTERNAL_STORAGE request result: ${result.toString()}',
              );
            }

            // Also check audio permissions for file picking
            final audioPermission = await Permission.audio.status;
            print('🎵 Audio permission status: ${audioPermission.toString()}');
            if (!audioPermission.isGranted) {
              await Permission.audio.request();
            }
          } else {
            // On iOS and other platforms
            final audioPermission = await Permission.audio.status;
            if (!audioPermission.isGranted) {
              await Permission.audio.request();
            }
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
              style: TextButton.styleFrom(
                foregroundColor: ThemeColorsUtil.primaryColor,
              ),
              child: const Text('Files'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('folder'),
              style: TextButton.styleFrom(
                foregroundColor: ThemeColorsUtil.secondary,
              ),
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
            print(
              '🎵 Scanned folder "$folderPath" and found ${audioFilePaths.length} music files',
            );
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
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorSecondary,
                        ),
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
                                  style: TextStyle(
                                    color: ThemeColorsUtil.textColorPrimary,
                                  ),
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
  Future<int> _importAudioFiles(
    List<String> filePaths,
    BuildContext context,
  ) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
              const SizedBox(height: 16),
              Text(
                'Importing ${filePaths.length} ${filePaths.length == 1 ? 'music file' : 'music files'}...',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    int importedCount = 0;

    try {
      // Process all audio files
      final newSongs = await _processAudioFiles(filePaths);

      // Save to database via bounded context (preferred) or library service (fallback)
      if (_libraryContext != null) {
        // Use bounded context - this will trigger reactive updates
        for (var song in newSongs) {
          await _libraryContext!.saveSong(song);
          importedCount++;
        }
      } else {
        // Fallback to direct library service
        for (var song in newSongs) {
          await _libraryService.saveSong(song);
          importedCount++;
        }
      }

      print(
        'Added $importedCount songs to library via ${this._libraryContext != null ? 'bounded context' : 'library service'}',
      );
    } catch (e) {
      print('Error during import: $e');
      // Continue to close dialog and show error
    }

    // Close the progress dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show completion message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $importedCount ${importedCount == 1 ? 'song' : 'songs'} to library!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    }

    return importedCount;
  }

  /// Scan a directory for audio files recursively
  Future<List<String>> _getAudioFilesFromDirectory(String dirPath) async {
    final List<String> audioFiles = [];
    final directory = Directory(dirPath);

    print('🎵 About to scan directory: $dirPath');
    print('🎵 Directory exists: ${await directory.exists()}');

    try {
      int totalFilesScanned = 0;
      List<String> foundExtensions = [];

      // Define supported audio file extensions
      final audioExtensions = [
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

      await for (var entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalFilesScanned++;
          final fileName = p.basename(entity.path);
          final extension = p.extension(entity.path).toLowerCase();

          // Skip system files and macOS resource fork files
          if (fileName.startsWith('._')) {
            print('🎵 Skipping macOS resource fork file: $fileName');
            continue;
          }

          // Skip very small files that are likely not actual music
          try {
            final fileSize = await entity.length();
            if (fileSize < 10000) {
              // Less than 10KB, likely not a real music file
              print(
                '🎵 Skipping very small file (${(fileSize / 1024).toStringAsFixed(2)} KB): $fileName',
              );
              continue;
            }
          } catch (e) {
            print('🎵 Could not check file size for $fileName: $e');
            // Continue anyway
          }

          // Log first few non-audio files for debugging
          if (!audioExtensions.contains(extension) &&
              foundExtensions.length < 5) {
            foundExtensions.add('$extension: ${fileName}');
          }

          // Check for common audio file extensions
          if (audioExtensions.contains(extension)) {
            audioFiles.add(entity.path);
          }
        } else if (entity is Directory) {
          print('🎵 Found subdirectory: ${entity.path}');
        }
      }

      print('🎵 Total files scanned: $totalFilesScanned');
      if (foundExtensions.isNotEmpty) {
        print('🎵 Sample non-audio files found: $foundExtensions');
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
      // On Android, if access is denied, try to provide more specific error information
      if (Platform.isAndroid) {
        print('🎵 Android directory access issue. Checking permissions...');
        try {
          final permission = await Permission.manageExternalStorage.status;
          print(
            '🎵 MANAGE_EXTERNAL_STORAGE permission status: ${permission.toString()}',
          );
        } catch (permError) {
          print('🎵 Could not check external storage permission: $permError');
        }
      }
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

        newSongs.add(
          Song(
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
          ),
        );
      } catch (e) {
        print('Error reading metadata for $fileName: $e');
        // Fallback - create song with basic info
        newSongs.add(
          Song(
            title: fileName,
            path: path,
            artist: 'Unknown Artist',
            album: 'Unknown Album',
          ),
        );
      }
    }

    return newSongs;
  }
}
