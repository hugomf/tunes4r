import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import '../models/song.dart';

/// Service class that manages all audio playback functionality
/// Handles queue management, playback controls, and audio state
class PlaybackManager {
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Playback state
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isShuffling = false;
  bool _isRepeating = false;

  // Queue management
  final List<Song> _queue = [];

  // Spectrum visualization
  final List<double> _spectrumData = List.generate(32, (index) => 0.0);
  Timer? _spectrumTimer;

  // Callbacks for UI updates
  VoidCallback? _onStateChanged;
  Function(Song)? _onSongChanged;

  // Getters
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isShuffling => _isShuffling;
  bool get isRepeating => _isRepeating;
  List<Song> get queue => List.unmodifiable(_queue);
  List<double> get spectrumData => List.unmodifiable(_spectrumData);

  void initialize({
    VoidCallback? onStateChanged,
    Function(Song)? onSongChanged,
  }) {
    _onStateChanged = onStateChanged;
    _onSongChanged = onSongChanged;

    // Setup audio player listeners
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      _onStateChanged?.call();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      _onStateChanged?.call();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      playNext();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _onStateChanged?.call();
    });

    // Start spectrum animation
    _startSpectrumAnimation();
  }

  void dispose() {
    _audioPlayer.dispose();
    _spectrumTimer?.cancel();
  }

  // Playback controls
  Future<void> playSong(Song song) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(song.path));
      _currentSong = song;
      _isPlaying = true;
      _onSongChanged?.call(song);
      _onStateChanged?.call();
    } catch (e) {
      print('Error playing song: $e');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentSong != null) {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  void playNext() {
    // First priority: check queue for next songs
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0); // Remove and get first song from queue
      playSong(nextSong);
      return;
    }

    // Second priority: repeat current song if enabled
    if (_isRepeating && _currentSong != null) {
      playSong(_currentSong!);
      return;
    }

    // No more songs - stop playback
    _currentSong = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _onStateChanged?.call();
  }

  void playPrevious() {
    // Previous functionality removed with playlist state
    // Only repeat current song if enabled
    if (_isRepeating && _currentSong != null) {
      playSong(_currentSong!);
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
    // Insert at position 0 (will play immediately after current song)
    _queue.insert(0, song);
    _onStateChanged?.call();
  }

  // Playback preferences
  void setShuffling(bool shuffling) {
    _isShuffling = shuffling;
    _onStateChanged?.call();
  }

  void setRepeating(bool repeating) {
    _isRepeating = repeating;
    _onStateChanged?.call();
  }

  // Spectrum animation
  void _startSpectrumAnimation() {
    _spectrumTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isPlaying) {
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
