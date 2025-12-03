import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/cupertino.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/services.dart';
import '../models/song.dart';

/// Service class that manages all audio playback functionality
/// Handles queue management, playback controls, and audio state
class PlaybackManager {
  // Audio player with equalizer support
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Method channel for equalizer (Android native implementation)
  static const MethodChannel _equalizerChannel = MethodChannel('com.example.tunes4r/audio');

  // Equalizer bands storage
  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  bool _isEqualizerEnabled = false; // Equalizer enable/disable state

  // Playback state
  Song? _currentSong;

  // Queue management
  final List<Song> _queue = [];

  // Playlist context (for looping functionality)
  List<Song>? _currentPlaylist; // The playlist currently being played
  bool _isPlaylistMode = false; // Whether we're in playlist playback mode

  // Playback history for previous song navigation
  final List<Song> _playbackHistory = []; // Stack of previously played songs

  // Prevent duplicate completion triggers
  bool _isHandlingCompletion = false;

  // Spectrum visualization
  final List<double> _spectrumData = List.generate(32, (index) => 0.0);
  Timer? _spectrumTimer;

  // Callbacks for UI updates
  VoidCallback? _onStateChanged;
  Function(Song)? _onSongChanged;

  // Callback for media control service updates
  VoidCallback? _onPlaybackStateChangedForMediaControls;

  // Callback for playback errors
  Function(String)? _onPlaybackError;

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _audioPlayer.playing;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  Duration get position => _audioPlayer.position;
  bool get isShuffling => _audioPlayer.shuffleModeEnabled;
  bool get isRepeating => _audioPlayer.loopMode != LoopMode.off;
  bool get isEqualizerEnabled => _isEqualizerEnabled;
  List<Song> get queue => List.unmodifiable(_queue);
  List<double> get spectrumData => List.unmodifiable(_spectrumData);
  ProcessingState get processingState => _audioPlayer.processingState;

  set isEqualizerEnabled(bool value) {
    if (_isEqualizerEnabled != value) {
      _isEqualizerEnabled = value;
      _onStateChanged?.call(); // Notify UI of state change
    }
  }

  void initialize({
    VoidCallback? onStateChanged,
    Function(Song)? onSongChanged,
    VoidCallback? onPlaybackStateChangedForMediaControls,
    Function(String)? onPlaybackError,
  }) async {
    _onStateChanged = onStateChanged;
    _onSongChanged = onSongChanged;
    _onPlaybackStateChangedForMediaControls = onPlaybackStateChangedForMediaControls;
    _onPlaybackError = onPlaybackError;

    print('🎵 PlaybackManager: Initializing with just_audio');

      // Configure audio session for proper platform behavior
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.configure(const AudioSessionConfiguration.music());

      // Initialize equalizer for Android
      if (Platform.isAndroid) {
        try {
          await _equalizerChannel.invokeMethod('initializeEqualizer');
          print('🎛️ Equalizer initialized');
        } catch (e) {
          print('Error initializing equalizer on app start: $e');
        }
      }
    } catch (e) {
      print('Error configuring audio session: $e');
    }

    // Listen to just_audio streams
    _audioPlayer.durationStream.listen((duration) {
      _onStateChanged?.call();
    });

    _audioPlayer.positionStream.listen((position) {
      _onStateChanged?.call();
    });

    _audioPlayer.playingStream.listen((playing) {
      _onStateChanged?.call();
      _onPlaybackStateChangedForMediaControls?.call();
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playNext();
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      // Handle errors
      if (playerState.processingState == ProcessingState.idle) return;

      if (playerState.processingState == ProcessingState.buffering) return;

      // This will show loading indicator but for now, just report errors
      if (playerState.processingState == ProcessingState.ready) return;
    });

    // Start spectrum animation
    _startSpectrumAnimation();
  }



  void dispose() {
    _audioPlayer.dispose();
    _spectrumTimer?.cancel();
  }

  // Playback controls
  Future<void> playSong(Song song, {List<Song>? context = null}) async {
    try {
      print('🎵 PlaybackManager: Playing song: ${song.title}');

      // Set up playlist context for next/previous functionality
      if (context != null && context.isNotEmpty) {
        _currentPlaylist = List.from(context);
        _isPlaylistMode = true;
      } else if (_currentPlaylist == null || !_currentPlaylist!.contains(song)) {
        _currentPlaylist = [song];
        _isPlaylistMode = true;
      }

      _currentSong = song;
      _isHandlingCompletion = false;

      if (Platform.isMacOS) {
        // Use native macOS AVAudioEngine implementation with working equalizer
        await _macOSPlaySong(song);
      } else {
        // Use just_audio for Android and other platforms
        await _standardPlaySong(song);
      }

      _onSongChanged?.call(song);
      _onStateChanged?.call();
      _onPlaybackStateChangedForMediaControls?.call();

    } catch (e) {
      print('❌ Error playing song: $e');
      _onPlaybackError?.call('Error playing song: $e');
    }
  }

Future<void> _standardPlaySong(Song song) async {
  // Create audio source
  final audioSource = AudioSource.uri(Uri.file(song.path));
  await _audioPlayer.setAudioSource(audioSource);

  if (Platform.isAndroid) {
    try {
      // CRITICAL: Get just_audio's audio session ID and attach equalizer to it
      final audioSessionId = _audioPlayer.androidAudioSessionId;
      if (audioSessionId != null) {
        await _equalizerChannel.invokeMethod('setAudioSessionId', {'sessionId': audioSessionId});
        print('🎛️ Android equalizer attached to session: $audioSessionId');
        
        // Re-apply current equalizer state after attaching
        if (_isEqualizerEnabled) {
          await _equalizerChannel.invokeMethod('enableEqualizer');
          await _equalizerChannel.invokeMethod('applyEqualizer', {'bands': _equalizerBands});
          print('🎛️ Android equalizer state restored');
        }
      } else {
        print('⚠️ Android audio session ID is null');
      }
    } catch (e) {
      print('Error setting up Android equalizer: $e');
    }
  }

  await _audioPlayer.play();
  print('✅ PlaybackManager: Song started successfully via just_audio');
}

  Future<void> _macOSPlaySong(Song song) async {
    // Use native macOS AVAudioEngine via method channel
    await _equalizerChannel.invokeMethod('playSong', {'filePath': song.path});
    print('✅ PlaybackManager: Song started successfully via macOS AVAudioEngine');
  }

  Future<void> togglePlayPause() async {
    try {
      if (Platform.isMacOS) {
        // Use macOS AVAudioEngine play/pause
        await _equalizerChannel.invokeMethod('togglePlayPause');
      } else {
        // Use just_audio for Android and other platforms
        await _audioPlayer.playing ? _audioPlayer.pause() : _audioPlayer.play();
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  Future<void> applyEqualizerBands(List<double> bands) async {
    _equalizerBands = List.from(bands);

    try {
      // Platform-specific equalizer implementation
      if (Platform.isAndroid) {
        await _equalizerChannel.invokeMethod('applyEqualizer', {'bands': _equalizerBands});
        print('🎛️ Android equalizer bands applied: $_equalizerBands');
      } else if (Platform.isMacOS) {
        await _equalizerChannel.invokeMethod('applyEqualizer', {'bands': _equalizerBands});
        print('🎛️ macOS equalizer bands applied: $_equalizerBands');
      } else {
        // iOS/Windows/Linux: UI only (equalizer effects not implemented)
        print('🎛️ Equalizer bands changed (effects supported on macOS/Android): $_equalizerBands');
      }
    } catch (e) {
      print('Error applying equalizer bands: $e');
    }
  }

  Future<void> resetEqualizer() async {
    _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    if (Platform.isAndroid) {
      await _equalizerChannel.invokeMethod('resetEqualizer');
    } else if (Platform.isMacOS) {
      await _equalizerChannel.invokeMethod('resetEqualizer');
    } else {
      // iOS/Windows/Linux: UI only
      print('🎛️ Reset equalizer to flat: $_equalizerBands');
    }
    print('🎛️ Reset equalizer to flat: $_equalizerBands');
  }

  Future<void> enableEqualizer() async {
    try {
      if (Platform.isAndroid || Platform.isMacOS) {
        await _equalizerChannel.invokeMethod('enableEqualizer');
      }
      isEqualizerEnabled = true;
      print('🎛️ Equalizer ENABLED');
    } catch (e) {
      print('Error enabling equalizer: $e');
    }
  }

  Future<void> disableEqualizer() async {
    try {
      if (Platform.isAndroid || Platform.isMacOS) {
        await _equalizerChannel.invokeMethod('disableEqualizer');
      }
      isEqualizerEnabled = false;
      print('🎛️ Equalizer DISABLED');
    } catch (e) {
      print('Error disabling equalizer: $e');
    }
  }

  void playNext() {
    print('🎵 playNext() called - currentSong: ${_currentSong?.title ?? "none"}');

    // Add current song to history before moving forward
    if (_isPlaylistMode && _currentSong != null && !_playbackHistory.contains(_currentSong)) {
      _playbackHistory.add(_currentSong!);
      if (_playbackHistory.length > 50) {
        _playbackHistory.removeAt(0);
      }
    }

    // Handle playlist/queue logic
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0);
      print('🎵 Playing from queue: ${nextSong.title}');
      playSong(nextSong);
      return;
    }

    if (_isPlaylistMode && _currentPlaylist != null && _currentSong != null) {
      final currentIndex = _currentPlaylist!.indexOf(_currentSong!);
      if (currentIndex >= 0 && currentIndex < _currentPlaylist!.length - 1) {
        final nextSong = _currentPlaylist![currentIndex + 1];
        print('🎵 Playing next in playlist: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      } else if (_audioPlayer.loopMode != LoopMode.off) {
        // Loop to beginning if repeating
        final nextSong = _currentPlaylist![0];
        print('🎵 Looping to start: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      }
    }

    // Restart current song if repeating single
    if (_audioPlayer.loopMode != LoopMode.off && _currentSong != null) {
      print('🎵 Repeating current song');
      playSong(_currentSong!);
      return;
    }

    // No more songs - stop playback
    print('🎵 No next song - stopping playback');
    endPlaylistPlayback();
  }

  void playPrevious() {
    if (_isPlaylistMode && _playbackHistory.isNotEmpty) {
      if (_currentSong != null && !_queue.contains(_currentSong)) {
        _queue.insert(0, _currentSong!);
      }
      final previousSong = _playbackHistory.removeLast();
      playSong(previousSong);
      return;
    }

    if (_currentSong != null) {
      playSong(_currentSong!); // Restart current song
    }
  }

  // Queue management
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

  // Playlist playback methods
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

  bool get isPlaylistMode => _isPlaylistMode;
  List<Song>? get currentPlaylist => _currentPlaylist;

  // Playback preferences
  void setShuffling(bool shuffling) {
    _audioPlayer.setShuffleModeEnabled(shuffling);
    _onStateChanged?.call();
  }

  void setRepeating(bool repeating) {
    _audioPlayer.setLoopMode(repeating ? LoopMode.all : LoopMode.off);
    _onStateChanged?.call();
  }

  // Spectrum animation
  void _startSpectrumAnimation() {
    _spectrumTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_audioPlayer.playing) {
        final random = Random();
        for (int i = 0; i < _spectrumData.length; i++) {
          double target = random.nextDouble() * (0.3 + random.nextDouble() * 0.7);
          _spectrumData[i] = _spectrumData[i] * 0.7 + target * 0.3;
        }
        _onStateChanged?.call();
      } else {
        for (int i = 0; i < _spectrumData.length; i++) {
          _spectrumData[i] *= 0.85;
        }
        _onStateChanged?.call();
      }
    });
  }

  // Seeking
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }
}
