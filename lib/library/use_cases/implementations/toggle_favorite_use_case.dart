import '../../repositories/repository_provider.dart';
import '../../../models/song.dart';
import '../abstracts/base_use_case.dart';

/// Use case for toggling a song's favorite status
/// Handles the business logic of adding/removing favorites with validation
class ToggleFavoriteUseCase extends BaseUseCase<ToggleFavoriteInput, ToggleFavoriteResult> {
  final RepositoryProvider _repositoryProvider;

  ToggleFavoriteUseCase({
    required RepositoryProvider repositoryProvider,
  }) : _repositoryProvider = repositoryProvider;

  @override
  Future<ToggleFavoriteResult> execute(ToggleFavoriteInput input) async {
    try {
      // Validate that the song exists
      final songExists = await _repositoryProvider.songRepository.songExists(input.song.path);
      if (!songExists) {
        return ToggleFavoriteResult.error(
          'Song not found in library: ${input.song.title}',
          input.song,
        );
      }

      // Get current favorite status
      final favorites = await _repositoryProvider.songRepository.getFavoriteSongs();
      final isCurrentlyFavorite = favorites.any((song) => song.path == input.song.path);

      // Toggle the status
      final newFavoriteStatus = !isCurrentlyFavorite;

      await _repositoryProvider.songRepository.updateFavoriteStatus(
        input.song.path,
        newFavoriteStatus,
      );

      // Create updated song for result
      final updatedSong = newFavoriteStatus ?
        input.song : // No change in song model, favorite status is handled separately
        input.song;

      return ToggleFavoriteResult.success(
        updatedSong,
        newFavoriteStatus,
        isCurrentlyFavorite,
      );

    } catch (e) {
      return ToggleFavoriteResult.error(
        'Failed to update favorite status: ${e.toString()}',
        input.song,
      );
    }
  }
}

/// Input parameters for toggle favorite use case
class ToggleFavoriteInput {
  final Song song;

  const ToggleFavoriteInput(this.song);

  // Factory from song
  factory ToggleFavoriteInput.fromSong(Song song) {
    return ToggleFavoriteInput(song);
  }
}

/// Result of toggle favorite operation
class ToggleFavoriteResult {
  final bool success;
  final Song song;
  final bool isFavorite;
  final bool wasChanged; // Whether the status actually changed
  final String? errorMessage;

  const ToggleFavoriteResult._({
    required this.success,
    required this.song,
    required this.isFavorite,
    required this.wasChanged,
    this.errorMessage,
  });

  factory ToggleFavoriteResult.success(Song song, bool newFavoriteStatus, bool previousFavoriteStatus) {
    return ToggleFavoriteResult._(
      success: true,
      song: song,
      isFavorite: newFavoriteStatus,
      wasChanged: newFavoriteStatus != previousFavoriteStatus,
    );
  }

  factory ToggleFavoriteResult.error(String errorMessage, Song song) {
    return ToggleFavoriteResult._(
      success: false,
      song: song,
      isFavorite: false,
      wasChanged: false,
      errorMessage: errorMessage,
    );
  }

  /// Returns a user-friendly message describing the operation result
  String get message {
    if (!success) return errorMessage ?? 'Unknown error';
    if (!wasChanged) return 'No change needed';
    return isFavorite ? 'Added to favorites' : 'Removed from favorites';
  }

  @override
  String toString() {
    if (success) {
      return 'ToggleFavoriteResult: ${song.title} ${isFavorite ? "added to" : "removed from"} favorites';
    } else {
      return 'ToggleFavoriteResult: Error - $errorMessage';
    }
  }
}
