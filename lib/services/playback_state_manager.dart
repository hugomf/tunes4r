import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import '../models/song.dart';

/// Enum representing the various states of audio playback
enum PlaybackState {
  none, // No song loaded
  loading, // Loading/buffering
  playing, // Actively playing
  paused, // Paused
  stopped, // Stopped
  error, // Error state
}

/// Error types for better error handling
enum PlaybackErrorType { file, network, platform, unknown }

/// Error class for playback-related errors
class PlaybackError {
  final String message;
  final PlaybackErrorType type;

  const PlaybackError(this.message, this.type);

  @override
  String toString() => 'PlaybackError($type): $message';
}

/// Centralized playback state management to handle platform-specific differences
class PlaybackStateManager {
  static const MethodChannel _audioChannel = MethodChannel(
    'com.example.tunes4r/audio',
  );

  // Core state
  Song? _currentSong;
  PlaybackState _playbackState = PlaybackState.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffling = false;
  bool _isRepeating = false;
  bool _isEqualizerEnabled = false;

  // Playlist and queue state
  bool _isPlaylistMode = false;
  final List<Song> _queue = [];
  List<Song>? _currentPlaylist;
  final List<Song> _playbackHistory = [];

  PlaybackError? _lastError;

  // Platform-specific state tracking
  bool _isMacOSPlaying = false; // Track macOS native playback state

  // Audio playback infrastructure
  late AudioPlayer _audioPlayer;
  List<double> _equalizerBands = [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  ];

  // Callback system for state changes
  VoidCallback? _onStateChanged;
  Function(Song)? _onSongChanged;
  StreamController<PlaybackError?>? _errorController;

  void initialize({
    VoidCallback? onStateChanged,
    Function(Song)? onSongChanged,
  }) {
    _onStateChanged = onStateChanged;
    _onSongChanged = onSongChanged;
    _errorController = StreamController<PlaybackError?>.broadcast();

    // Initialize just_audio for Android/Windows/iOS playback
    _audioPlayer = AudioPlayer();

    // Set up just_audio listeners for unified state management
    _audioPlayer.durationStream.listen((duration) {
      updateDuration(duration);
      _onStateChanged?.call();
    });

    _audioPlayer.positionStream.listen((position) {
      updatePosition(position);
      _onStateChanged?.call();
    });

    _audioPlayer.playingStream.listen((playing) {
      // Update state manager with standardized state
      final newState = playing ? PlaybackState.playing : PlaybackState.paused;
      updatePlaybackState(newState, notify: false); // Don't notify again
      _onStateChanged?.call();
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Playback completed - this will be handled by PlaybackManager
      }
    });

    // Set up method channel handler for native state updates
    _audioChannel.setMethodCallHandler(_handleNativeStateUpdate);
  }

  Future<dynamic> _handleNativeStateUpdate(MethodCall call) async {
    if (call.method == 'playbackStateChanged') {
      final stateArg = call.arguments as Map?;
      if (stateArg != null && stateArg['state'] is String) {
        final stateStr = stateArg['state'] as String;
        _updatePlaybackStateFromNative(stateStr);
      }
    }
  }

  void _updatePlaybackStateFromNative(String nativeState) {
    final wasPlaying = isPlaying;

    switch (nativeState.toLowerCase()) {
      case 'playing':
        _isMacOSPlaying = true;
        if (_currentSong != null) {
          _playbackState = PlaybackState.playing;
        }
        break;
      case 'paused':
      case 'stopped':
        _isMacOSPlaying = false;
        _playbackState = PlaybackState.paused;
        break;
      case 'loading':
        _playbackState = PlaybackState.loading;
        break;
      case 'error':
        _playbackState = PlaybackState.error;
        _isMacOSPlaying = false;
        break;
      default:
        // Unknown state, maintain current
        break;
    }

    // Notify if playback state actually changed
    final isPlayingNow = isPlaying;
    if (wasPlaying != isPlayingNow) {
      _onStateChanged?.call();
    }
  }

  // Public getters that normalize state across platforms
  Song? get currentSong => _currentSong;
  PlaybackState get playbackState => _playbackState;
  bool get isEqualizerEnabled => _isEqualizerEnabled;
  bool get isShuffling => _isShuffling;
  bool get isRepeating => _isRepeating;
  bool get isPlaylistMode => _isPlaylistMode;
  List<Song> get queue => List.unmodifiable(_queue);
  List<double> get spectrumData => List.unmodifiable(_spectrumData);
  Duration get position => _position;
  Duration get duration => _duration;
  PlaybackError? get lastError => _lastError;

  /// Normalized playing state across all platforms
  bool get isPlaying {
    if (Platform.isMacOS) {
      return _isMacOSPlaying;
    }
    return _playbackState == PlaybackState.playing;
  }

  // State setters (called by PlaybackManager)
  void updateCurrentSong(Song? song) {
    final changed = _currentSong != song;
    _currentSong = song;
    if (changed && song != null) {
      _onSongChanged?.call(song);
    }
    _onStateChanged?.call();
  }

  void updatePlaybackState(PlaybackState state, {bool notify = true}) {
    _playbackState = state;
    if (notify) {
      _onStateChanged?.call();
    }
  }

  void updatePosition(Duration position) {
    _position = position;
  }

  void updateDuration(Duration? duration) {
    _duration = duration ?? Duration.zero;
  }

  void updateShuffling(bool shuffling) {
    _isShuffling = shuffling;
    _onStateChanged?.call();
  }

  void updateRepeating(bool repeating) {
    _isRepeating = repeating;
    _onStateChanged?.call();
  }

  void updateEqualizerEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    _onStateChanged?.call();
  }

  void setError(PlaybackError error) {
    _lastError = error;
    _errorController?.add(error);
    updatePlaybackState(PlaybackState.error);
  }

  void clearError() {
    _lastError = null;
    _errorController?.add(null);
  }

  // Stream access for reactive UI
  Stream<PlaybackError?> get errorStream =>
      _errorController?.stream ?? Stream.empty();

  void dispose() {
    _audioPlayer.dispose();
    _errorController?.close();
  }

  // Queue management methods
  void addToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      _onStateChanged?.call();
    }
  }

  void addToPlayNext(Song song) {
    _queue.insert(0, song);
    _onStateChanged?.call();
  }

  void clearQueue() {
    _queue.clear();
    _onStateChanged?.call();
  }

  // Playlist management methods
  void startPlaylistPlayback(List<Song> playlist) {
    _currentPlaylist = List.from(playlist);
    _isPlaylistMode = true;
    _playbackHistory.clear();
  }

  void endPlaylistPlayback() {
    _currentPlaylist = null;
    _isPlaylistMode = false;
    _playbackHistory.clear();
  }

  // Additional getters
  List<Song>? get currentPlaylist => _currentPlaylist;

  // Spectrum data
  final List<double> _spectrumData = List.generate(32, (i) => 0.0);

  // Platform-specific audio playback methods
  Future<void> loadSong(Song song) async {
    if (Platform.isMacOS) {
      // macOS loading handled by playSong call
    } else {
      // Android/Windows/iOS: use just_audio
      final audioSource = AudioSource.uri(Uri.file(song.path));
      await _audioPlayer.setAudioSource(audioSource);

      // Handle Android equalizer setup
      if (Platform.isAndroid) {
        try {
          final audioSessionId = _audioPlayer.androidAudioSessionId;
          if (audioSessionId != null) {
            await _audioChannel.invokeMethod('setAudioSessionId', {
              'sessionId': audioSessionId,
            });
            print('🎛️ Android equalizer attached to session: $audioSessionId');

            // Re-apply equalizer state
            if (_isEqualizerEnabled) {
              await _audioChannel.invokeMethod('enableEqualizer');
              await _audioChannel.invokeMethod('applyEqualizer', {
                'bands': _equalizerBands,
              });
            }
          }
        } catch (e) {
          print('Error setting up Android equalizer: $e');
        }
      }
    }
  }

  Future<void> playSong() async {
    if (Platform.isMacOS) {
      if (_currentSong != null) {
        await _audioChannel.invokeMethod('playSong', {
          'filePath': _currentSong!.path,
        });
        _isMacOSPlaying = true; // Immediately update state
      }
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> pauseSong() async {
    if (Platform.isMacOS) {
      await _audioChannel.invokeMethod('pauseSong');
      _isMacOSPlaying = false;
    } else {
      await _audioPlayer.pause();
    }
  }

  Future<void> togglePlayPause() async {
    if (Platform.isMacOS) {
      await _audioChannel.invokeMethod('togglePlayPause');
    } else {
      await _audioPlayer.playing ? _audioPlayer.pause() : _audioPlayer.play();
    }
  }

  // Equalizer methods
  Future<void> applyEqualizerBands(List<double> bands) async {
    _equalizerBands = List.from(bands);
    if (Platform.isAndroid || Platform.isMacOS) {
      try {
        await _audioChannel.invokeMethod('applyEqualizer', {
          'bands': _equalizerBands,
        });
        print('🎛️ Platform equalizer bands applied: $_equalizerBands');
      } catch (e) {
        print('Error applying equalizer bands: $e');
      }
    }
  }

  Future<void> resetEqualizer() async {
    _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    if (Platform.isAndroid || Platform.isMacOS) {
      try {
        await _audioChannel.invokeMethod('resetEqualizer');
        print('🎛️ Platform equalizer reset');
      } catch (e) {
        print('Error resetting equalizer: $e');
      }
    }
  }

  Future<void> enableEqualizer() async {
    if (Platform.isAndroid || Platform.isMacOS) {
      try {
        await _audioChannel.invokeMethod('enableEqualizer');
        _isEqualizerEnabled = true;
        _onStateChanged?.call();
        print('🎛️ Platform equalizer enabled');
      } catch (e) {
        print('Error enabling equalizer: $e');
      }
    }
  }

  Future<void> disableEqualizer() async {
    if (Platform.isAndroid || Platform.isMacOS) {
      try {
        await _audioChannel.invokeMethod('disableEqualizer');
        _isEqualizerEnabled = false;
        _onStateChanged?.call();
        print('🎛️ Platform equalizer disabled');
      } catch (e) {
        print('Error disabling equalizer: $e');
      }
    }
  }

  // Playback preferences
  void setShuffleMode(bool shuffling) {
    if (Platform.isMacOS) {
      // macOS shuffle handled natively
    } else {
      _audioPlayer.setShuffleModeEnabled(shuffling);
    }
    _isShuffling = shuffling;
    _onStateChanged?.call();
  }

  void setLoopMode(bool repeating) {
    if (Platform.isMacOS) {
      // macOS loop handled natively
    } else {
      _audioPlayer.setLoopMode(repeating ? LoopMode.all : LoopMode.off);
    }
    _isRepeating = repeating;
    _onStateChanged?.call();
  }

  // Seeking
  Future<void> seekTo(Duration position) async {
    if (Platform.isMacOS) {
      await _audioChannel.invokeMethod('seekTo', {
        'position': position.inMilliseconds,
      });
    } else {
      await _audioPlayer.seek(position);
    }
  }

  // Spectrum animation logic
  void updateSpectrum() {
    if (isPlaying) {
      final random = Random();
      for (int i = 0; i < _spectrumData.length; i++) {
        double target = random.nextDouble() * (0.3 + random.nextDouble() * 0.7);
        _spectrumData[i] = _spectrumData[i] * 0.7 + target * 0.3;
      }
    } else {
      for (int i = 0; i < _spectrumData.length; i++) {
        _spectrumData[i] *= 0.85;
      }
    }
  }
}
