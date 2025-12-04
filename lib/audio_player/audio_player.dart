import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:just_audio/just_audio.dart' hide PlaybackEvent;
import 'package:logging/logging.dart';
import 'package:tunes4r/services/audio_equalizer_service.dart';
import 'package:tunes4r/services/media_control_service.dart';
import 'playback_state.dart';
import 'playback_commands.dart';
import 'playback_actions.dart';
import 'audio_platform_service.dart';
import 'logger.dart';
import '../../models/song.dart';

/// Main bounded context class for audio playback
/// Encapsulates all playback-related functionality in a single component
class AudioPlayer {
  // Core dependencies
  final AudioPlatformService _platformService;

  // State management
  PlaybackState _state = const PlaybackState();
  final StreamController<PlaybackState> _stateController = StreamController<PlaybackState>.broadcast();
  final StreamController<PlaybackEvent> _eventController = StreamController<PlaybackEvent>.broadcast();

  // Spectrum animation
  Timer? _spectrumTimer;

  AudioPlayer._(this._platformService);

  /// Factory constructor that chooses the appropriate platform service
  factory AudioPlayer() {
    // Use JustAudioPlatformService for all platforms - it's more robust and cross-platform
    // Future: Add native platform services when they have full feature implementations
    final platformService = JustAudioPlatformService();

    // Debug logging - remove in production
    AudioPlayerLogger.info('AudioPlayer factory: Created JustAudioPlatformService');

    return AudioPlayer._(platformService);
  }

// Core services - INTERNAL to the bounded context
  late final AudioEqualizerService _audioEqualizerService;
  late final MediaControlService _mediaControlService;

  /// Initialize the audio player
  Future<void> initialize() async {
    // Configure logger for this bounded context - INTERNAL concern
    AudioPlayerLogger.configure(
      level: Level.INFO, // INFO for playback events, WARNING for errors, SEVERE for critical issues
    );

    await _platformService.initialize();

    // Initialize services - encapsulated within the bounded context
    _audioEqualizerService = AudioEqualizerService(this);
    await _audioEqualizerService.initialize();

    _mediaControlService = MediaControlService(this);

    // Subscribe to our own events for media control updates
    _eventController.stream.listen((event) {
      if (event is SongStartedEvent) {
        _mediaControlService.updateMetadata();
        AudioPlayerLogger.info('Updated media control metadata for: ${event.song.title}');
      }
    });

    // Subscribe to platform streams for state synchronization
    _platformService.positionStream.listen((position) {
      _updateState(PlaybackActions.updatePosition(_state, position));
    });

    _platformService.durationStream.listen((duration) {
      if (duration != null) {
        _updateState(PlaybackActions.updateDuration(_state, duration));
      }
    });

    _platformService.playingStream.listen((isPlaying) {
      _updateState(PlaybackActions.setPlaying(_state, isPlaying));
    });

    _platformService.processingStateStream.listen((processingState) {
      switch (processingState) {
        case ProcessingState.completed:
          _handleSongCompletion();
          break;
        case ProcessingState.ready:
          if (_state.status == PlaybackStatus.loading) {
            _updateState(_state.copyWith(status: PlaybackStatus.playing));
          }
          break;
        case ProcessingState.idle:
          // Handle error states if needed
          break;
        default:
          break;
      }
    });

    // Start spectrum animation
    _startSpectrumAnimation();

    AudioPlayerLogger.info('Initializing bounded context');
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _spectrumTimer?.cancel();
    await _platformService.dispose();
    _mediaControlService.dispose();
    await _stateController.close();
    await _eventController.close();
  }

  /// Reactive state stream
  Stream<PlaybackState> get state => _stateController.stream;

  /// Event stream for inter-context communication
  Stream<PlaybackEvent> get events => _eventController.stream;

  /// Current state snapshot (for convenience)
  PlaybackState get currentState => _state;

  /// Legacy getters - kept for backward compatibility with existing widgets
  Song? get currentSong => _state.currentSong;
  bool get isPlaying => _state.isPlaying;
  Duration get duration => _state.duration;
  Duration get position => _state.position;
  bool get isShuffling => _state.isShuffling;
  bool get isRepeating => _state.isRepeating;
  bool get isEqualizerEnabled => _state.isEqualizerEnabled;
  bool get isPlaylistMode => _state.hasPlaylist;
  List<Song> get queue => _state.queue;
  List<Song>? get currentPlaylist => _state.currentPlaylist;
  List<double> get spectrumData => _state.spectrumData;

  /// Command interface - all playback operations go through here

  Future<void> playSong(Song song, {List<Song>? context}) async {
    try {
      AudioPlayerLogger.info('Playing song: ${song.title} (${song.path})');

      // Process command through pure actions
      final newState = PlaybackActions.playSong(_state, PlaySongCommand(song, context: context));

      // Update state
      _updateState(newState);

      // Execute platform operations
      await _platformService.loadSong(song.path);
      await _platformService.play();

      // Emit domain events
      _emitEvent(SongStartedEvent(song, playlist: context));

    } catch (e) {
      AudioPlayerLogger.warning('Error playing song: $e', error: e);
      _handleError('Error playing song: $e', PlaybackErrorType.file);
    }
  }

  Future<void> pause() async {
    try {
      final newState = PlaybackActions.pause(_state, PauseCommand());
      _updateState(newState);

      await _platformService.pause();
      _emitEvent(PlaybackStateChangedEvent(_state.status, PlaybackStatus.paused));
    } catch (e) {
      _handleError('Error pausing playback: $e', PlaybackErrorType.platform);
    }
  }

  Future<void> resume() async {
    try {
      final newState = PlaybackActions.resume(_state, ResumeCommand());
      _updateState(newState);

      await _platformService.play();
      _emitEvent(PlaybackStateChangedEvent(_state.status, PlaybackStatus.playing));
    } catch (e) {
      _handleError('Error resuming playback: $e', PlaybackErrorType.platform);
    }
  }

  Future<void> togglePlayPause() async {
    final newState = PlaybackActions.togglePlayPause(_state, TogglePlayPauseCommand());
    if (newState.status == PlaybackStatus.playing) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> stop() async {
    try {
      final newState = PlaybackActions.stop(_state, StopCommand());
      _updateState(newState);

      await _platformService.stop();
      _emitEvent(PlaybackStateChangedEvent(_state.status, PlaybackStatus.stopped));
    } catch (e) {
      _handleError('Error stopping playback: $e', PlaybackErrorType.platform);
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      final newState = PlaybackActions.seekTo(_state, SeekToCommand(position));
      _updateState(newState);

      await _platformService.seekTo(position);
    } catch (e) {
      _handleError('Error seeking: $e', PlaybackErrorType.platform);
    }
  }

  Future<void> next() async {
    if (_state.queue.isNotEmpty || (_state.currentPlaylist != null && _state.currentSong != null)) {
      final newState = PlaybackActions.nextSong(_state, NextSongCommand());
      if (!identical(newState.currentSong, _state.currentSong) && newState.currentSong != null) {
        await playSong(newState.currentSong!);
      }
    }
  }

  Future<void> previous() async {
    final newState = PlaybackActions.previousSong(_state, PreviousSongCommand());
    if (!identical(newState.position, _state.position) && newState.position == Duration.zero) {
      // Just seeking to start of current song
      await seekTo(Duration.zero);
    } else if (newState.currentSong != null && newState.currentSong != _state.currentSong) {
      await playSong(newState.currentSong!);
    }
  }

  Future<void> addToQueue(Song song) async {
    final newState = PlaybackActions.addToQueue(_state, AddToQueueCommand(song));
    _updateState(newState);

    _emitEvent(QueueChangedEvent(newState.queue, QueueChangeType.added, affectedSong: song));
  }

  Future<void> addToPlayNext(Song song) async {
    final newState = PlaybackActions.addToPlayNext(_state, AddToPlayNextCommand(song));
    _updateState(newState);

    _emitEvent(QueueChangedEvent(newState.queue, QueueChangeType.added, affectedSong: song));
  }

  Future<void> clearQueue() async {
    final newState = PlaybackActions.clearQueue(_state, ClearQueueCommand());
    _updateState(newState);

    _emitEvent(QueueChangedEvent(newState.queue, QueueChangeType.cleared));
  }

  Future<void> removeFromQueue(Song song) async {
    final newState = PlaybackActions.removeFromQueue(_state, RemoveFromQueueCommand(song));
    _updateState(newState);

    _emitEvent(QueueChangedEvent(newState.queue, QueueChangeType.removed, affectedSong: song));
  }

  Future<void> startPlaylist(List<Song> playlist, {int startIndex = 0}) async {
    final newState = PlaybackActions.startPlaylist(_state, StartPlaylistCommand(playlist, startIndex: startIndex));
    _updateState(newState);

    _emitEvent(PlaylistChangedEvent(playlist, hasEnded: false));

    if (newState.currentSong != null) {
      await playSong(newState.currentSong!, context: playlist);
    }
  }

  Future<void> endPlaylist() async {
    final newState = PlaybackActions.endPlaylist(_state, EndPlaylistCommand());
    _updateState(newState);

    _emitEvent(PlaylistChangedEvent(null, hasEnded: true));
  }

  Future<void> toggleShuffle() async {
    final newState = PlaybackActions.toggleShuffle(_state, ToggleShuffleCommand());
    _updateState(newState);

    await _platformService.setShuffleMode(newState.isShuffling);
    _emitEvent(PlaybackModeChangedEvent(newState.isShuffling, newState.isRepeating));
  }

  Future<void> toggleRepeat() async {
    final newState = PlaybackActions.toggleRepeat(_state, ToggleRepeatCommand());
    _updateState(newState);

    try {
      await _platformService.setLoopMode(newState.isRepeating);
    } catch (e) {
      // Platform may not implement loop mode (e.g., macOS) - this is okay
      // The domain logic in PlaybackActions handles repeat behavior for song transitions
      AudioPlayerLogger.warning('Platform loop mode not implemented, using domain logic');
    }

    _emitEvent(PlaybackModeChangedEvent(newState.isShuffling, newState.isRepeating));
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    final newState = PlaybackActions.setEqualizerEnabled(_state, SetEqualizerEnabledCommand(enabled));
    _updateState(newState);

    if (enabled) {
      await _platformService.enableEqualizer();
    } else {
      await _platformService.disableEqualizer();
    }

    _emitEvent(EqualizerChangedEvent(enabled));
  }

  Future<void> applyEqualizerBands(List<double> bands) async {
    final newState = PlaybackActions.applyEqualizerBands(_state, ApplyEqualizerBandsCommand(bands));
    _updateState(newState);

    await _platformService.applyEqualizerBands(bands);
    _emitEvent(EqualizerChangedEvent(_state.isEqualizerEnabled, bands: bands));
  }

  Future<void> resetEqualizer() async {
    final newState = PlaybackActions.resetEqualizer(_state, ResetEqualizerCommand());
    _updateState(newState);

    await _platformService.applyEqualizerBands([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
    _emitEvent(EqualizerChangedEvent(_state.isEqualizerEnabled));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final newState = PlaybackActions.setPlaybackSpeed(_state, SetPlaybackSpeedCommand(speed));
    _updateState(newState);

    await _platformService.setSpeed(speed);
  }

  /// Legacy methods for backward compatibility with PlaybackManager interface
  Future<void> setShuffling(bool shuffling) async {
    if ((shuffling && !_state.isShuffling) || (!shuffling && _state.isShuffling)) {
      await toggleShuffle();
    }
  }
  Future<void> setRepeating(bool repeating) async {
    if ((repeating && !_state.isRepeating) || (!repeating && _state.isRepeating)) {
      await toggleRepeat();
    }
  }
  Future<void> pauseSong() async => await pause();
  Future<void> enableEqualizer() async => await setEqualizerEnabled(true);
  Future<void> disableEqualizer() async => await setEqualizerEnabled(false);
  Future<void> playNext() async => await next();
  Future<void> playPrevious() async => await previous();
  void startPlaylistPlayback(List<Song> playlist) => startPlaylist(playlist);
  void endPlaylistPlayback() => endPlaylist();

  /// Equalizer access - exposed through bounded context interface
  AudioEqualizerService get equalizerService => _audioEqualizerService;

  // Equalizer delegate methods for cleaner interface (optional)
  List<double> get equalizerBands => _audioEqualizerService.bands;
  Future<void> setEqualizerBands(List<double> bands) => _audioEqualizerService.setBands(bands);
  Future<void> setEqualizerBandsRealtime(List<double> bands) => _audioEqualizerService.setBandsRealtime(bands);
  Future<void> toggleEqualizerEnabled(bool enabled) => _audioEqualizerService.toggleEnabled(enabled);

  /// Private methods

  void _updateState(PlaybackState newState) {
    final oldStatus = _state.status;
    _state = newState;
    _stateController.add(_state);

    // Emit state change events for significant transitions
    if (oldStatus != newState.status) {
      _emitEvent(PlaybackStateChangedEvent(oldStatus, newState.status));
    }
  }

  void _emitEvent(PlaybackEvent event) {
    _eventController.add(event);
  }

  void _handleSongCompletion() {
    AudioPlayerLogger.info('Song completed, moving to next');
    _emitEvent(SongCompletedEvent(
      _state.currentSong!,
      // nextSong will be determined by the next() method when called
    ));

    // Handle next song automatically
    next();
  }

  void _handleError(String message, PlaybackErrorType type) {
    final newState = PlaybackActions.setError(_state, message, type);
    _updateState(newState);

    _emitEvent(PlaybackErrorEvent(message, type));
  }

  void _startSpectrumAnimation() {
    _spectrumTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_state.isPlaying) {
        // Generate fake spectrum data for visualization
        final spectrumData = _generateSpectrumData();
        final newState = PlaybackActions.updateSpectrum(_state, spectrumData);
        _updateState(newState);
      } else {
        // Fade out spectrum when not playing
        final fadedData = _state.spectrumData.map((value) => value * 0.85).toList();
        if (fadedData.any((value) => value > 0.01)) {
          final newState = PlaybackActions.updateSpectrum(_state, fadedData);
          _updateState(newState);
        }
      }
    });
  }

  List<double> _generateSpectrumData() {
    // Simple algorithm to generate realistic looking spectrum data
    final random = Random();
    return List.generate(32, (i) {
      final target = random.nextDouble() * (0.3 + random.nextDouble() * 0.7);
      return _state.spectrumData.isNotEmpty
          ? _state.spectrumData[i] * 0.7 + target * 0.3
          : target;
    });
  }
}
