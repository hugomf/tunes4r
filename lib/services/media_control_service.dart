import 'dart:async';
import 'package:flutter/services.dart';
import 'playback_manager.dart';

/// Service class that handles media control events from external sources
/// like Bluetooth headphones and Android Auto
class MediaControlService {
  static const MethodChannel _channel = MethodChannel(
    'com.ocelot.tunes4r/media_controls',
  );
  static const String _methodUpdatePlaybackState = 'updatePlaybackState';
  static const String _methodUpdateMetadata = 'updateMetadata';

  final PlaybackManager _playbackManager;
  StreamSubscription<String>? _mediaEventSubscription;

  MediaControlService(this._playbackManager) {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    print('📱 MediaControlService: Setting up method channel handler');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📱 MediaControlService: Received method call: ${call.method}');
    switch (call.method) {
      case 'onMediaControl':
        final action = call.arguments as String;
        print('📱 MediaControlService: Handling media control action: $action');
        _handleMediaControl(action);
        break;
      default:
        print('⚠️ MediaControlService: Unimplemented method: ${call.method}');
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  void _handleMediaControl(String action) {
    print('🎵 MediaControlService: Processing action: $action');
    switch (action) {
      case 'play':
        print('▶️ Play action received');
        if (!_playbackManager.isPlaying) {
          _playbackManager.togglePlayPause();
        }
        break;
      case 'pause':
        print('⏸️ Pause action received');
        if (_playbackManager.isPlaying) {
          _playbackManager.togglePlayPause();
        }
        break;
      case 'playPause':
        print('⏯️ PlayPause action received');
        _playbackManager.togglePlayPause();
        break;
      case 'next':
        print('⏭️ Next action received');
        _playbackManager.playNext();
        break;
      case 'previous':
        print('⏮️ Previous action received');
        _playbackManager.playPrevious();
        break;
      case 'stop':
        print('⏹️ Stop action received');
        // For stop, we'll pause since audioplayers doesn't have explicit stop
        if (_playbackManager.isPlaying) {
          _playbackManager.togglePlayPause();
        }
        break;
      default:
        print('❓ Unknown action: $action');
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

      print('📤 MediaControlService: Updating playback state to: $state');
      await _channel.invokeMethod(_methodUpdatePlaybackState, {'state': state});
      print('✅ MediaControlService: Playback state updated successfully');
    } catch (e) {
      // Silently ignore MissingPluginException - platform not ready yet
      if (!e.toString().contains('MissingPluginException')) {
        print('❌ Error updating playback state: $e');
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
          'album': song.album?.isNotEmpty == true
              ? song.album
              : 'Unknown Album',
        };
        print(
          '📤 MediaControlService: Updating metadata: ${metadata['title']} - ${metadata['artist']}',
        );
        await _channel.invokeMethod(_methodUpdateMetadata, metadata);
        print('✅ MediaControlService: Metadata updated successfully');
      } else {
        print('⚠️ MediaControlService: No current song to update metadata');
      }
    } catch (e) {
      // Silently ignore MissingPluginException - platform not ready yet
      if (!e.toString().contains('MissingPluginException')) {
        print('❌ Error updating metadata: $e');
      }
    }
  }

  void dispose() {
    print('🔌 MediaControlService: Disposing');
    _mediaEventSubscription?.cancel();
    _channel.setMethodCallHandler(null);
  }
}
