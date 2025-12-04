import 'package:flutter/foundation.dart';
import '../../models/song.dart';

/// Immutable representation of the complete audio playback state
@immutable
class PlaybackState {
  final Song? currentSong;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool isShuffling;
  final bool isRepeating;
  final bool isEqualizerEnabled;
  final List<Song> queue;
  final List<Song>? currentPlaylist;
  final double playbackSpeed;
  final List<double> spectrumData;
  final PlaybackError? lastError;

  const PlaybackState({
    this.currentSong,
    this.status = PlaybackStatus.none,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffling = false,
    this.isRepeating = false,
    this.isEqualizerEnabled = false,
    this.queue = const [],
    this.currentPlaylist,
    this.playbackSpeed = 1.0,
    this.spectrumData = const [],
    this.lastError,
  });

  PlaybackState copyWith({
    Song? currentSong,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? isShuffling,
    bool? isRepeating,
    bool? isEqualizerEnabled,
    List<Song>? queue,
    List<Song>? currentPlaylist,
    double? playbackSpeed,
    List<double>? spectrumData,
    PlaybackError? lastError,
  }) {
    return PlaybackState(
      currentSong: currentSong ?? this.currentSong,
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffling: isShuffling ?? this.isShuffling,
      isRepeating: isRepeating ?? this.isRepeating,
      isEqualizerEnabled: isEqualizerEnabled ?? this.isEqualizerEnabled,
      queue: queue ?? this.queue,
      currentPlaylist: currentPlaylist ?? this.currentPlaylist,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      spectrumData: spectrumData ?? this.spectrumData,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Computed properties
  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isPaused => status == PlaybackStatus.paused;
  bool get isLoading => status == PlaybackStatus.loading;
  bool get isIdle => status == PlaybackStatus.none || status == PlaybackStatus.stopped;
  bool get hasError => lastError != null;
  bool get hasQueue => queue.isNotEmpty;
  bool get hasPlaylist => currentPlaylist != null && currentPlaylist!.isNotEmpty;

  /// Progress as a fractional value between 0.0 and 1.0
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackState &&
          runtimeType == other.runtimeType &&
          currentSong == other.currentSong &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          isShuffling == other.isShuffling &&
          isRepeating == other.isRepeating &&
          isEqualizerEnabled == other.isEqualizerEnabled &&
          queue.length == other.queue.length &&
          currentPlaylist == other.currentPlaylist &&
          playbackSpeed == other.playbackSpeed &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    currentSong,
    status,
    position,
    duration,
    isShuffling,
    isRepeating,
    isEqualizerEnabled,
    queue.length,
    currentPlaylist,
    playbackSpeed,
    lastError,
  );

  @override
  String toString() {
    return 'PlaybackState(song: ${currentSong?.title ?? "none"}, status: $status, pos: $position, dur: $duration, queue: ${queue.length} songs)';
  }
}

/// Enumerations for playback state
enum PlaybackStatus {
  none,       // No song loaded
  loading,    // Loading/buffering
  playing,    // Actively playing
  paused,     // Paused
  stopped,    // Stopped
  error       // Error state
}

/// Error representation
@immutable
class PlaybackError {
  final String message;
  final PlaybackErrorType type;
  final DateTime timestamp;

  PlaybackError(
    this.message,
    this.type, [
    DateTime? timestamp,
  ]) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'PlaybackError[$type]: $message';
}

enum PlaybackErrorType {
  file,
  network,
  platform,
  unknown,
}
