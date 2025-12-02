import 'dart:async';
import 'package:flutter/services.dart';
import 'playback_manager.dart';

/// Service class that handles media control events from external sources
/// like Bluetooth headphones and Android Auto
class MediaControlService {
  static const MethodChannel _channel = MethodChannel('com.example.tunes4r/media_controls');
  static const String _methodUpdatePlaybackState = 'updatePlaybackState';
  static const String _methodUpdateMetadata = 'updateMetadata';

  final PlaybackManager _playbackManager;
  StreamSubscription<String>? _mediaEventSubscription;

  MediaControlService(this._playbackManager) {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMediaControl':
        _handleMediaControl(call.arguments as String);
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  void _handleMediaControl(String action) {
    switch (action) {
      case 'play':
        _playbackManager.togglePlayPause();
        break;
      case 'pause':
        _playbackManager.togglePlayPause();
        break;
      case 'playPause':
        _playbackManager.togglePlayPause();
        break;
      case 'next':
        _playbackManager.playNext();
        break;
      case 'previous':
        _playbackManager.playPrevious();
        break;
      case 'stop':
        // For stop, we'll pause since audioplayers doesn't have explicit stop
        _playbackManager.togglePlayPause();
        break;
    }
  }

  /// Update the system with current playback state
  /// Call this whenever playback state changes
  Future<void> updatePlaybackState() async {
    try {
      String state = 'stopped';
      if (_playbackManager.isPlaying) {
        state = 'playing';
      } else if (_playbackManager.currentSong != null) {
        state = 'paused';
      }

      await _channel.invokeMethod(_methodUpdatePlaybackState, {'state': state});
    } catch (e) {
      // Silently ignore MissingPluginException - platform not ready yet
      if (!e.toString().contains('MissingPluginException')) {
        print('Error updating playback state: $e');
      }
    }
  }

  /// Update the system with current track metadata
  /// Call this whenever the current song changes
  Future<void> updateMetadata() async {
    try {
      final song = _playbackManager.currentSong;
      if (song != null) {
        final metadata = {
          'title': song.title,
          'artist': song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
          'album': song.album?.isNotEmpty == true ? song.album : 'Unknown Album',
        };
        await _channel.invokeMethod(_methodUpdateMetadata, metadata);
      }
    } catch (e) {
      // Silently ignore MissingPluginException - platform not ready yet
      if (!e.toString().contains('MissingPluginException')) {
        print('Error updating metadata: $e');
      }
    }
  }

  void dispose() {
    _mediaEventSubscription?.cancel();
    _channel.setMethodCallHandler(null);
  }
}
