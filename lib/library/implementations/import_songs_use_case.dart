import 'dart:async';
import 'dart:io';

import '../../repositories/repository_provider.dart';
import '../../../models/song.dart';
import '../../../library/services/media_scan_service.dart';
import '../../../library/services/metadata_extraction_service.dart';
import '../abstracts/base_use_case.dart';

/// Use case for importing music files into the library
///
/// This is a complex operation that:
/// - Scans directories for audio files
/// - Extracts metadata from each file
/// - Saves songs to the repository
/// - Provides progress updates for UI feedback
///
/// The use case supports cancellation and proper error handling
class ImportSongsUseCase extends BaseUseCase<ImportSongsInput, int> {
  final RepositoryProvider _repositoryProvider;
  final MediaScanService _mediaScanService;
  final MetadataExtractionService _metadataExtractionService;

  bool _isCancelled = false;
  Completer<bool>? _cancellationCompleter;

  ImportSongsUseCase({
    required RepositoryProvider repositoryProvider,
    required MediaScanService mediaScanService,
    required MetadataExtractionService metadataExtractionService,
  })  : _repositoryProvider = repositoryProvider,
        _mediaScanService = mediaScanService,
        _metadataExtractionService = metadataExtractionService;

  @override
  Future<int> execute(ImportSongsInput input) async {
    _isCancelled = false;

    // Step 1: Validate input files exist
    await _validateInputFiles(input.filePaths);

    // Step 2: Extract metadata from all files
    final rawSongs = await _metadataExtractionService.extractMultipleMetadata(input.filePaths);

    if (_isCancelled) throw OperationCancelledException();

    int importedCount = 0;

    // Step 3: Save each song to repository
    for (int i = 0; i < rawSongs.length; i++) {
      if (_isCancelled) throw OperationCancelledException();

      final song = rawSongs[i];
      await _repositoryProvider.songRepository.saveSong(song);
      importedCount++;

      // Update progress through progress tracking
      final progressPercentage = ((i + 1) / rawSongs.length * 100).round();
    }

    return importedCount;
  }

  @override
  Stream<UseCaseProgress<int>> executeWithProgress(ImportSongsInput input) async* {
    _isCancelled = false;

    try {
      yield UseCaseProgress.initial('Preparing to import music files...');

      // Step 1: Validate input files
      yield UseCaseProgress.running(5, 'Validating music files...');
      await _validateInputFiles(input.filePaths);

      if (_isCancelled) throw OperationCancelledException();

      // Step 2: Extract metadata
      yield UseCaseProgress.running(20, 'Scanning for audio files...');
      final audioPaths = await _scanForAudioFiles(input.filePaths);

      yield UseCaseProgress.running(40, 'Extracting metadata from ${audioPaths.length} files...');
      final rawSongs = await _metadataExtractionService.extractMultipleMetadata(audioPaths);

      if (_isCancelled) throw OperationCancelledException();

      int importedCount = 0;

      // Step 3: Save songs to repository
      yield UseCaseProgress.running(60, 'Saving songs to library...');

      for (int i = 0; i < rawSongs.length; i++) {
        if (_isCancelled) throw OperationCancelledException();

        final song = rawSongs[i];
        await _repositoryProvider.songRepository.saveSong(song);
        importedCount++;

        final progressPercentage = 60 + ((i + 1) / rawSongs.length * 40).round();
        yield UseCaseProgress.running(
          progressPercentage.clamp(60, 100),
          'Imported $importedCount of ${rawSongs.length} songs...',
        );
      }

      yield UseCaseProgress.completed(importedCount);

    } catch (error) {
      if (error is OperationCancelledException) {
        yield UseCaseProgress.failed('Import was cancelled by user');
      } else {
        yield UseCaseProgress.failed('Import failed: ${error.toString()}');
      }
      rethrow;
    }
  }

  @override
  Future<bool> cancel() async {
    _isCancelled = true;
    if (_cancellationCompleter == null) {
      _cancellationCompleter = Completer<bool>();
      // Give a small delay to ensure cancellation is processed
      Future.delayed(const Duration(milliseconds: 100), () {
        _cancellationCompleter?.complete(true);
      });
    }
    return _cancellationCompleter!.future;
  }

  /// Validate that input files exist and are accessible
  Future<void> _validateInputFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) {
      throw ImportException('No files provided for import');
    }

    for (final path in filePaths) {
      final file = File(path);
      if (!await file.exists()) {
        throw ImportException('File not found: $path');
      }
      if ((await file.length()) <= 0) {
        throw ImportException('File is empty: $path');
      }
    }
  }

  /// Scan for actual audio files (handles both files and directories)
  Future<List<String>> _scanForAudioFiles(List<String> filePaths) async {
    final List<String> audioFiles = [];

    for (final path in filePaths) {
      final file = File(path);
      final directory = Directory(path);

      if (await file.exists()) {
        // Direct file - check if it's audio
        if (await _isAudioFile(file)) {
          audioFiles.add(path);
        }
      } else if (await directory.exists()) {
        // Directory - scan recursively for audio files
        final foundFiles = await _mediaScanService.scanDirectory(path);
        audioFiles.addAll(foundFiles);
      }
    }

    if (audioFiles.isEmpty) {
      throw ImportException('No audio files found in the selected paths');
    }

    return audioFiles;
  }

  /// Check if a file is an audio file based on extension
  Future<bool> _isAudioFile(File file) async {
    final audioExtensions = [
      '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.flac', '.wav'
    ];

    final fileName = file.path.toLowerCase();
    return audioExtensions.any((ext) => fileName.endsWith(ext));
  }
}

/// Input parameters for song import use case
class ImportSongsInput {
  final List<String> filePaths;

  const ImportSongsInput(this.filePaths);

  // Factory for importing a single file
  factory ImportSongsInput.singleFile(String filePath) {
    return ImportSongsInput([filePath]);
  }

  // Factory for importing a directory
  factory ImportSongsInput.directory(String directoryPath) {
    return ImportSongsInput([directoryPath]);
  }

  // Factory for importing multiple files
  factory ImportSongsInput.multipleFiles(List<String> filePaths) {
    return ImportSongsInput(filePaths);
  }
}

/// Custom exceptions for import operations
class ImportException implements Exception {
  final String message;

  ImportException(this.message);

  @override
  String toString() => 'ImportException: $message';
}

class OperationCancelledException implements Exception {
  @override
  String toString() => 'OperationCancelledException: Operation was cancelled by user';
}
