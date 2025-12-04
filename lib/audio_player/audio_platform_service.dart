import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'logger.dart';

/// Abstract interface for audio platform operations
/// This allows us to mock platform operations for testing
abstract class AudioPlatformService {
  /// Initialize the audio platform
  Future<void> initialize();

  /// Dispose of platform resources
  Future<void> dispose();

  /// Load a song for playback
  Future<void> loadSong(String filePath);

  /// Start playback
  Future<void> play();

  /// Pause playback
  Future<void> pause();

  /// Stop playback
  Future<void> stop();

  /// Seek to position
  Future<void> seekTo(Duration position);

  /// Get current playback position
  Duration get currentPosition;

  /// Get total duration
  Duration get duration;

  /// Get playing state
  bool get isPlaying;

  /// Stream of position updates
  Stream<Duration> get positionStream;

  /// Stream of duration updates
  Stream<Duration?> get durationStream;

  /// Stream of playing state changes
  Stream<bool> get playingStream;

  /// Stream of processing state changes
  Stream<ProcessingState> get processingStateStream;

  /// Apply equalizer bands
  Future<void> applyEqualizerBands(List<double> bands);

  /// Enable equalizer
  Future<void> enableEqualizer();

  /// Disable equalizer
  Future<void> disableEqualizer();

  /// Set shuffle mode
  Future<void> setShuffleMode(bool enabled);

  /// Set loop mode
  Future<void> setLoopMode(bool enabled);

  /// Set playback speed
  Future<void> setSpeed(double speed);
}

/// Implementation for Android/Windows/iOS using just_audio
class JustAudioPlatformService implements AudioPlatformService {
  late final AudioPlayer _audioPlayer;
  final MethodChannel? _equalizerChannel;

  JustAudioPlatformService()
      : _equalizerChannel = Platform.isAndroid  // Only Android has native equalizer support
            ? const MethodChannel('com.example.tunes4r/audio')
            : null {  // macOS/Windows/iOS rely on just_audio's software equalizer
    _audioPlayer = AudioPlayer();
  }

  @override
  Future<void> initialize() async {
    // Set up Android equalizer when audio session is ready
    if (Platform.isAndroid) {
      _audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          _setupAndroidEqualizer();
        }
      });
    }
  }

  Future<void> _setupAndroidEqualizer() async {
    try {
      final audioSessionId = _audioPlayer.androidAudioSessionId;
      if (audioSessionId != null) {
        await _equalizerChannel?.invokeMethod('setAudioSessionId', {
          'sessionId': audioSessionId,
        });
        AudioPlayerLogger.info('Android equalizer session attached: $audioSessionId');
      }
    } catch (e) {
        AudioPlayerLogger.warning('Android equalizer setup failed', error: e);
    }
  }

  @override
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  @override
  Future<void> loadSong(String filePath) async {
    final audioSource = AudioSource.uri(Uri.file(filePath));
    await _audioPlayer.setAudioSource(audioSource);
  }

  @override
  Future<void> play() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Duration get currentPosition => _audioPlayer.position;

  @override
  Duration get duration => _audioPlayer.duration ?? Duration.zero;

  @override
  bool get isPlaying => _audioPlayer.playing;

  @override
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  @override
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  @override
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  @override
  Stream<ProcessingState> get processingStateStream => _audioPlayer.processingStateStream;

  @override
  Future<void> applyEqualizerBands(List<double> bands) async {
    if (_equalizerChannel != null) {
      try {
        await _equalizerChannel.invokeMethod('applyEqualizer', {'bands': bands});
        AudioPlayerLogger.info('Equalizer bands applied: $bands');
      } catch (e) {
        AudioPlayerLogger.warning('Failed to apply equalizer bands', error: e);
        rethrow;
      }
    }
  }

  @override
  Future<void> enableEqualizer() async {
    if (_equalizerChannel != null) {
      try {
        await _equalizerChannel.invokeMethod('enableEqualizer');
        AudioPlayerLogger.info('Platform equalizer enabled');
      } catch (e) {
        AudioPlayerLogger.warning('Failed to enable equalizer', error: e);
        rethrow;
      }
    }
  }

  @override
  Future<void> disableEqualizer() async {
    if (_equalizerChannel != null) {
      try {
        await _equalizerChannel.invokeMethod('disableEqualizer');
        AudioPlayerLogger.info('Platform equalizer disabled');
      } catch (e) {
        AudioPlayerLogger.warning('Failed to disable equalizer', error: e);
        rethrow;
      }
    }
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    // just_audio doesn't have shuffle in the same way, but this could be handled at the domain level
    await _audioPlayer.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setLoopMode(bool enabled) async {
    await _audioPlayer.setLoopMode(enabled ? LoopMode.all : LoopMode.off);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }
}

/// Implementation for macOS using native AVFoundation through method channels
class MacOSAudioPlatformService implements AudioPlatformService {
  final MethodChannel _audioChannel = const MethodChannel('com.example.tunes4r/audio');
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<ProcessingState> _processingController = StreamController<ProcessingState>.broadcast();

  Timer? _updateTimer;
  Duration _currentPosition = Duration.zero;
  Duration? _currentDuration;
  bool _isPlaying = false;

  MacOSAudioPlatformService() {
    _setupMethodChannelHandler();
  }

  void _setupMethodChannelHandler() {
    _audioChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'playbackStateChanged':
          final state = call.arguments as Map?;
          if (state != null && state['state'] is String) {
            final stateStr = state['state'] as String;
            _handleNativeStateUpdate(stateStr);
          }
          break;
        case 'positionUpdate':
          final positionMs = call.arguments?['position'] as int?;
          if (positionMs != null) {
            _currentPosition = Duration(milliseconds: positionMs);
            _positionController.add(_currentPosition);
          }
          break;
        case 'durationUpdate':
          final durationMs = call.arguments?['duration'] as int?;
          if (durationMs != null) {
            _currentDuration = Duration(milliseconds: durationMs);
            _durationController.add(_currentDuration);
          }
          break;
      }
    });
  }

  void _handleNativeStateUpdate(String state) {
    switch (state.toLowerCase()) {
      case 'playing':
        _isPlaying = true;
        _playingController.add(true);
        _startPositionUpdates();
        break;
      case 'paused':
      case 'stopped':
        _isPlaying = false;
        _playingController.add(false);
        _stopPositionUpdates();
        break;
      case 'loading':
        _processingController.add(ProcessingState.loading);
        break;
      case 'ready':
        _processingController.add(ProcessingState.ready);
        break;
      case 'completed':
        _processingController.add(ProcessingState.completed);
        _isPlaying = false;
        _playingController.add(false);
        _stopPositionUpdates();
        break;
      case 'error':
        _processingController.add(ProcessingState.idle);
        _isPlaying = false;
        _playingController.add(false);
        _stopPositionUpdates();
        break;
    }
  }

  void _startPositionUpdates() {
    _stopPositionUpdates(); // Clean up any existing timer
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying) {
        _audioChannel.invokeMethod('getCurrentPosition');
      }
    });
  }

  void _stopPositionUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  @override
  Future<void> initialize() async {
    // macOS initialization handled in platform code
  }

  @override
  Future<void> dispose() async {
    _stopPositionUpdates();
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _processingController.close();
  }

  @override
  Future<void> loadSong(String filePath) async {
    AudioPlayerLogger.info('Loading song: $filePath');
    try {
      await _audioChannel.invokeMethod('loadSong', {'filePath': filePath});
      AudioPlayerLogger.info('Song loaded: $filePath');
    } catch (e) {
      AudioPlayerLogger.warning('Failed to load song: $filePath', error: e);
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    AudioPlayerLogger.info('Starting playback');
    try {
      await _audioChannel.invokeMethod('playSong');
      AudioPlayerLogger.info('Playback started');
    } catch (e) {
      AudioPlayerLogger.warning('Failed to start playback', error: e);
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    await _audioChannel.invokeMethod('pauseSong');
  }

  @override
  Future<void> stop() async {
    await _audioChannel.invokeMethod('stopSong');
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _audioChannel.invokeMethod('seekTo', {
      'position': position.inMilliseconds,
    });
  }

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get duration => _currentDuration ?? Duration.zero;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<ProcessingState> get processingStateStream => _processingController.stream;

  @override
  Future<void> applyEqualizerBands(List<double> bands) async {
    await _audioChannel.invokeMethod('applyEqualizer', {'bands': bands});
  }

  @override
  Future<void> enableEqualizer() async {
    await _audioChannel.invokeMethod('enableEqualizer');
  }

  @override
  Future<void> disableEqualizer() async {
    await _audioChannel.invokeMethod('disableEqualizer');
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    // Shuffle handled at domain level for macOS
  }

  @override
  Future<void> setLoopMode(bool enabled) async {
    try {
      await _audioChannel.invokeMethod('setLoopMode', {'enabled': enabled});
      AudioPlayerLogger.info('macOS loop mode set to: $enabled');
    } on MissingPluginException catch (e) {
      // macOS loop mode not implemented yet - log the error but handle gracefully
      // Loop logic is implemented at the domain level in playback_actions.dart
      AudioPlayerLogger.warning('macOS loop mode not implemented yet - using domain logic', error: e);
    } catch (e) {
      AudioPlayerLogger.error('macOS loop mode error', error: e);
      rethrow;
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _audioChannel.invokeMethod('setPlaybackSpeed', {'speed': speed});
  }
}
