import 'dart:math';
import 'playback_state.dart';
import 'playback_commands.dart';
import '../../models/song.dart';

/// Pure functions that transform PlaybackState based on commands
/// No side effects, just state transformations
class PlaybackActions {
  /// Helper to clamp Duration values between min and max
  static Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Play a song, optionally with playlist context
  static PlaybackState playSong(PlaybackState state, PlaySongCommand command) {
    final newQueue = _setupQueue(state.queue, command.song, command.context);

    return state.copyWith(
      currentSong: command.song,
      status: PlaybackStatus.loading,
      queue: newQueue,
      currentPlaylist: command.context,
      lastError: null, // Clear any previous errors
    );
  }

  /// Pause playback
  static PlaybackState pause(PlaybackState state, PauseCommand command) {
    return state.copyWith(status: PlaybackStatus.paused);
  }

  /// Resume playback from paused state
  static PlaybackState resume(PlaybackState state, ResumeCommand command) {
    if (state.currentSong != null && state.status == PlaybackStatus.paused) {
      return state.copyWith(status: PlaybackStatus.playing);
    }
    return state;
  }

  /// Stop playback completely
  static PlaybackState stop(PlaybackState state, StopCommand command) {
    return state.copyWith(
      status: PlaybackStatus.stopped,
      position: Duration.zero,
    );
  }

  /// Toggle between play and pause
  static PlaybackState togglePlayPause(
    PlaybackState state,
    TogglePlayPauseCommand command,
  ) {
    switch (state.status) {
      case PlaybackStatus.playing:
        return pause(state, PauseCommand());
      case PlaybackStatus.paused:
      case PlaybackStatus.stopped:
        return resume(state, ResumeCommand());
      default:
        return state;
    }
  }

  /// Seek to specific position in current song
  static PlaybackState seekTo(PlaybackState state, SeekToCommand command) {
    if (state.currentSong == null) return state;

    final clampedPosition = _clampDuration(
      command.position,
      Duration.zero,
      state.duration,
    );

    return state.copyWith(position: clampedPosition);
  }

  /// Add song to end of queue
  static PlaybackState addToQueue(
    PlaybackState state,
    AddToQueueCommand command,
  ) {
    if (state.queue.contains(command.song)) {
      return state; // Don't add duplicates
    }

    return state.copyWith(queue: [...state.queue, command.song]);
  }

  /// Add song to play next (after current song)
  static PlaybackState addToPlayNext(
    PlaybackState state,
    AddToPlayNextCommand command,
  ) {
    if (state.queue.contains(command.song)) {
      return state; // Don't add duplicates
    }

    return state.copyWith(queue: [command.song, ...state.queue]);
  }

  /// Clear the entire queue
  static PlaybackState clearQueue(
    PlaybackState state,
    ClearQueueCommand command,
  ) {
    return state.copyWith(queue: []);
  }

  /// Remove specific song from queue
  static PlaybackState removeFromQueue(
    PlaybackState state,
    RemoveFromQueueCommand command,
  ) {
    return state.copyWith(
      queue: state.queue.where((song) => song != command.song).toList(),
    );
  }

  /// Start playlist playback
  static PlaybackState startPlaylist(
    PlaybackState state,
    StartPlaylistCommand command,
  ) {
    final startSong = command.playlist.elementAtOrNull(command.startIndex);
    if (startSong == null) return state;

    final remainingSongs = command.playlist
        .skip(command.startIndex + 1)
        .toList();
    final newQueue = [startSong, ...remainingSongs];

    return state.copyWith(
      currentPlaylist: command.playlist,
      queue: newQueue,
      currentSong: startSong,
      status: PlaybackStatus.loading,
      lastError: null,
    );
  }

  /// End playlist playback
  static PlaybackState endPlaylist(
    PlaybackState state,
    EndPlaylistCommand command,
  ) {
    return state.copyWith(
      currentPlaylist: null,
      // Note: We don't clear queue here in case songs were manually added
    );
  }

  /// Move to next song in playlist or queue
  static PlaybackState nextSong(PlaybackState state, NextSongCommand command) {
    final nextSong = _determineNextSong(state);
    if (nextSong == null) {
      // No next song available, stop playback
      return stop(state, StopCommand());
    }

    return playSong(
      state,
      PlaySongCommand(nextSong, context: state.currentPlaylist),
    );
  }

  /// Move to previous song or restart current song
  static PlaybackState previousSong(
    PlaybackState state,
    PreviousSongCommand command,
  ) {
    final previousSong = _determinePreviousSong(state);
    if (previousSong == null) {
      // Restart current song
      return state.copyWith(position: Duration.zero);
    }

    return playSong(
      state,
      PlaySongCommand(previousSong, context: state.currentPlaylist),
    );
  }

  /// Toggle shuffle mode
  static PlaybackState toggleShuffle(
    PlaybackState state,
    ToggleShuffleCommand command,
  ) {
    return state.copyWith(isShuffling: !state.isShuffling);
  }

  /// Toggle repeat mode
  static PlaybackState toggleRepeat(
    PlaybackState state,
    ToggleRepeatCommand command,
  ) {
    return state.copyWith(isRepeating: !state.isRepeating);
  }

  /// Enable/disable equalizer
  static PlaybackState setEqualizerEnabled(
    PlaybackState state,
    SetEqualizerEnabledCommand command,
  ) {
    return state.copyWith(isEqualizerEnabled: command.enabled);
  }

  /// Apply equalizer bands
  static PlaybackState applyEqualizerBands(
    PlaybackState state,
    ApplyEqualizerBandsCommand command,
  ) {
    return state.copyWith(
      // Note: We'd need to add equalizerBands to PlaybackState
      // For now, this is a placeholder
    );
  }

  /// Reset equalizer to flat response
  static PlaybackState resetEqualizer(
    PlaybackState state,
    ResetEqualizerCommand command,
  ) {
    return state.copyWith(
      // Note: We'd need to add equalizerBands to PlaybackState
      // For now, this is a placeholder
    );
  }

  /// Set playback speed
  static PlaybackState setPlaybackSpeed(
    PlaybackState state,
    SetPlaybackSpeedCommand command,
  ) {
    const validSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    double clampedSpeed = validSpeeds.first;
    for (final speed in validSpeeds) {
      if ((command.speed - speed).abs() <
          (command.speed - clampedSpeed).abs()) {
        clampedSpeed = speed;
      }
    }

    return state.copyWith(playbackSpeed: clampedSpeed);
  }

  /// Load song without playing it
  static PlaybackState loadSong(PlaybackState state, LoadSongCommand command) {
    return state.copyWith(
      currentSong: command.song,
      status: PlaybackStatus.stopped,
      position: Duration.zero,
      duration: Duration.zero, // Will be updated when loaded
      lastError: null,
    );
  }

  /// Handle automatic song completion (when song ends naturally)
  static PlaybackState handleSongCompleted(PlaybackState state) {
    final nextSong = _determineNextSong(state);
    if (nextSong != null) {
      return playSong(
        state,
        PlaySongCommand(nextSong, context: state.currentPlaylist),
      );
    } else {
      return stop(state, StopCommand());
    }
  }

  /// Set playback position and duration (called from platform updates)
  static PlaybackState updatePosition(PlaybackState state, Duration position) {
    return state.copyWith(
      position: _clampDuration(position, Duration.zero, state.duration),
    );
  }

  static PlaybackState updateDuration(PlaybackState state, Duration duration) {
    return state.copyWith(duration: duration);
  }

  /// Set playing status (called from platform updates)
  static PlaybackState setPlaying(PlaybackState state, bool isPlaying) {
    final newStatus = isPlaying
        ? PlaybackStatus.playing
        : PlaybackStatus.paused;
    return state.copyWith(status: newStatus);
  }

  /// Set error state
  static PlaybackState setError(
    PlaybackState state,
    String message,
    PlaybackErrorType type,
  ) {
    return state.copyWith(
      status: PlaybackStatus.error,
      lastError: PlaybackError(message, type),
    );
  }

  /// Clear error state
  static PlaybackState clearError(PlaybackState state) {
    return state.copyWith(lastError: null);
  }

  /// Update spectrum data for visualization
  static PlaybackState updateSpectrum(
    PlaybackState state,
    List<double> spectrumData,
  ) {
    return state.copyWith(spectrumData: spectrumData);
  }

  /// Helper: Set up queue when playing a song
  static List<Song> _setupQueue(
    List<Song> currentQueue,
    Song song,
    List<Song>? context,
  ) {
    if (context != null && context.isNotEmpty) {
      // When playing from playlist context, replace queue with playlist after current song
      final currentIndex = context.indexOf(song);
      if (currentIndex >= 0 && currentIndex < context.length - 1) {
        return context.sublist(currentIndex + 1);
      } else {
        return [];
      }
    } else if (currentQueue.isEmpty || !currentQueue.contains(song)) {
      // Single song playback, no queue changes needed
      return currentQueue;
    } else {
      // Song is already in queue, keep queue as-is
      return currentQueue;
    }
  }

  /// Helper: Determine next song based on state and modes
  static Song? _determineNextSong(PlaybackState state) {
    // First priority: explicit queue
    if (state.queue.isNotEmpty) {
      if (state.isShuffling) {
        final random = Random();
        return state.queue[random.nextInt(state.queue.length)];
      } else {
        return state.queue.first;
      }
    }

    // Second priority: playlist context
    if (state.currentPlaylist != null && state.currentSong != null) {
      final currentIndex = state.currentPlaylist!.indexOf(state.currentSong!);
      if (currentIndex >= 0) {
        if (state.isShuffling) {
          // Shuffle within playlist (excluding current song)
          final remainingSongs = List<Song>.from(state.currentPlaylist!)
            ..removeAt(currentIndex);
          if (remainingSongs.isNotEmpty) {
            final random = Random();
            return remainingSongs[random.nextInt(remainingSongs.length)];
          }
        } else if (currentIndex < state.currentPlaylist!.length - 1) {
          // Next in playlist
          return state.currentPlaylist![currentIndex + 1];
        } else if (state.isRepeating) {
          // Loop back to beginning
          return state.currentPlaylist!.first;
        }
      }
    }

    return null; // No next song available
  }

  /// Helper: Determine previous song in playlist
  static Song? _determinePreviousSong(PlaybackState state) {
    if (state.currentPlaylist != null && state.currentSong != null) {
      final currentIndex = state.currentPlaylist!.indexOf(state.currentSong!);
      if (currentIndex > 0) {
        return state.currentPlaylist![currentIndex - 1];
      }
      // If at beginning and repeating, go to end
      else if (state.isRepeating && state.currentPlaylist!.isNotEmpty) {
        return state.currentPlaylist!.last;
      }
    }

    // If no playlist context, just restart current song (handled in previousSong)
    return null;
  }
}
