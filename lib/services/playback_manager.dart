import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:audio_session/audio_session.dart';
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

  // Playlist context (for looping functionality)
  List<Song>? _currentPlaylist;  // The playlist currently being played
  bool _isPlaylistMode = false;   // Whether we're in playlist playback mode

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
    VoidCallback? onPlaybackStateChangedForMediaControls,
  }) {
    _onStateChanged = onStateChanged;
    _onSongChanged = onSongChanged;
    _onPlaybackStateChangedForMediaControls = onPlaybackStateChangedForMediaControls;

    // Configure audio session for proper iOS behavior (this will complete asynchronously)
    AudioSession.instance.then((session) {
      session.configure(const AudioSessionConfiguration.music()).catchError((e) {
        print('Error configuring audio session: $e');
      });
    }).catchError((e) {
      print('Error getting audio session: $e');
    });

    // Setup audio player listeners
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      _onStateChanged?.call();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      _onStateChanged?.call();
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      // Prevent duplicate completion triggers that cause "duplicate response" errors
      if (!_isHandlingCompletion) {
        _isHandlingCompletion = true;
        // Add a small delay to ensure completion event is fully processed
        Future.delayed(const Duration(milliseconds: 50), () {
          playNext();
          _isHandlingCompletion = false;
        });
      }
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
  Future<void> playSong(Song song, {List<Song>? context = null}) async {
    try {
      // Reset position and duration before starting new playback
      _position = Duration.zero;
      _duration = Duration.zero;

      // Set up playlist context for next/previous functionality
      if (context != null && context.isNotEmpty) {
        // Use provided context (like full playlist or library)
        _currentPlaylist = List.from(context);
        _isPlaylistMode = true;
      } else if (_currentPlaylist == null || !_currentPlaylist!.contains(song)) {
        // No context or song not in current playlist - create single-song context
        _currentPlaylist = [song];
        _isPlaylistMode = true;
      }
      // If context is null but we already have a playlist with this song, keep existing context

      // Play directly - audioplayers handles stopping previous playback automatically
      await _audioPlayer.play(DeviceFileSource(song.path));
      _currentSong = song;
      _isPlaying = true;
      _isHandlingCompletion = false; // Reset completion flag for new song
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
    print('🎵 playNext() called - currentSong: ${_currentSong?.title ?? "none"}, playlist: ${_currentPlaylist?.length ?? 0} songs');

    // Add current song to history before moving forward (if in playlist mode)
    if (_isPlaylistMode && _currentSong != null && !_playbackHistory.contains(_currentSong)) {
      _playbackHistory.add(_currentSong!);
      // Limit history size to prevent memory issues
      if (_playbackHistory.length > 50) {
        _playbackHistory.removeAt(0);
      }
    }

    // First priority: if we have a current playlist and are in playlist mode, find next song in playlist
    if (_isPlaylistMode && _currentPlaylist != null && _currentPlaylist!.isNotEmpty && _currentSong != null) {
      final currentIndex = _currentPlaylist!.indexOf(_currentSong!);
      print('🎵 Current song index: $currentIndex in playlist of ${_currentPlaylist!.length} songs');
      if (currentIndex >= 0 && currentIndex < _currentPlaylist!.length - 1) {
        // Play the next song in the playlist
        final nextSong = _currentPlaylist![currentIndex + 1];
        print('🎵 Playing next song: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      } else if (_isRepeating && _currentPlaylist!.length > 1) {
        // Loop back to beginning if repeating enabled
        final nextSong = _currentPlaylist![0];
        print('🎵 Looping to start: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      } else {
        print('🎵 No next song available (end of playlist)');
        if (_isRepeating && _currentPlaylist!.length == 1) {
          print('🎵 Repeating single song');
          playSong(_currentSong!, context: _currentPlaylist);
          return;
        }
      }
    }

    // Second priority: check queue for next songs
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0);
      print('🎵 Playing from queue: ${nextSong.title}');
      playSong(nextSong);
      return;
    }

    // Legacy fallback: if we have a current playlist and are in playlist mode, find next song in playlist
    // (This handles edge cases where _currentPlaylist exists but _isPlaylistMode is false)
    if (!_isPlaylistMode && _currentPlaylist != null && _currentPlaylist!.isNotEmpty && _currentSong != null) {
      final currentIndex = _currentPlaylist!.indexOf(_currentSong!);
      print('🎵 Current song index: $currentIndex in playlist of ${_currentPlaylist!.length} songs');
      if (currentIndex >= 0 && currentIndex < _currentPlaylist!.length - 1) {
        // Play the next song in the playlist
        final nextSong = _currentPlaylist![currentIndex + 1];
        print('🎵 Playing next song: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      } else if (_isRepeating && _currentPlaylist!.length > 1) {
        // Loop back to beginning if repeating enabled
        final nextSong = _currentPlaylist![0];
        print('🎵 Looping to start: ${nextSong.title}');
        playSong(nextSong, context: _currentPlaylist);
        return;
      } else {
        print('🎵 No next song available (end of playlist)');
        if (_isRepeating && _currentPlaylist!.length == 1) {
          print('🎵 Repeating single song');
          playSong(_currentSong!, context: _currentPlaylist);
          return;
        }
      }
    }

    // Third priority: repeat current song if enabled and no playlist available
    if (_isRepeating && _currentSong != null) {
      print('🎵 Repeating current song (fallback)');
      playSong(_currentSong!);
      return;
    }

    // No more songs - stop playback and exit playlist mode
    print('🎵 No next song - stopping playback');
    endPlaylistPlayback();
    _playbackHistory.clear(); // Clear history when ending playlist
    _currentSong = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _onStateChanged?.call();
  }

  void playPrevious() {
    // For playlist mode, try to go to previous song from history
    if (_isPlaylistMode && _playbackHistory.isNotEmpty) {
      // Move current song back to the queue (so it can be played next again)
      if (_currentSong != null && !_queue.contains(_currentSong)) {
        _queue.insert(0, _currentSong!);
      }

      // Play the previous song from history
      final previousSong = _playbackHistory.removeLast();
      playSong(previousSong);
      return;
    }

    // For regular playback or when no history exists, restart current song
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
    // Insert at position 0 (will play immediately after current song)
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
    _playbackHistory.clear(); // Start with clean history for new playlist
  }

  void endPlaylistPlayback() {
    _currentPlaylist = null;
    _isPlaylistMode = false;
    _playbackHistory.clear(); // Clear history when ending playlist mode
  }

  bool get isPlaylistMode => _isPlaylistMode;
  List<Song>? get currentPlaylist => _currentPlaylist;

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
