import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/playback_manager.dart';

/// Service for managing audio equalization
class AudioEqualizerService {
  final PlaybackManager playbackManager;

  AudioEqualizerService(this.playbackManager);

  // System equalizer presets and bands (simplified to match our UI)
  static const Map<String, List<double>> systemPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [5.0, 3.0, 2.0, 1.0, 0.0, -1.0, 2.0, 3.0, 4.0, 5.0],
    'Pop': [-1.0, 0.0, 3.0, 4.0, 2.0, 1.0, 2.0, 3.0, 0.0, -1.0],
    'Jazz': [4.0, 3.0, 1.0, 2.0, -1.0, -1.0, 0.0, 2.0, 3.0, 4.0],
    'Bass Boost': [8.0, 7.0, 5.0, 2.0, 0.0, -2.0, -2.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [0.0, 0.0, -2.0, -1.0, 3.0, 6.0, 6.0, 3.0, 0.0, 0.0],
  };

  bool _isEnabled = false; // Disabled by default - user must enable
  List<double> _bands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  String _currentPreset = 'Flat';

  // Getters
  bool get isEnabled => _isEnabled;
  List<double> get bands => List.unmodifiable(_bands);
  String get currentPreset => _currentPreset;
  List<String> get presetNames => systemPresets.keys.toList();

  /// Initialize the equalizer service
  Future<void> initialize() async {
    await _loadSettings();

    // CRITICAL FIX: If equalizer should be enabled, actually enable it
    if (_isEnabled) {
      await playbackManager.enableEqualizer();
      await playbackManager.applyEqualizerBands(_bands);
    } else {
      await playbackManager.disableEqualizer();
    }
  }

  /// Load equalizer settings from shared preferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('equalizer_enabled') ?? false;

    final bandsString = prefs.getStringList('equalizer_bands');
    if (bandsString != null && bandsString.length == 10) {
      _bands = bandsString.map((s) => double.tryParse(s) ?? 0.0).toList();
    }

    _currentPreset = prefs.getString('equalizer_preset') ?? 'Flat';
  }

  /// Save equalizer settings to shared preferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('equalizer_enabled', _isEnabled);
    await prefs.setStringList(
      'equalizer_bands',
      _bands.map((b) => b.toString()).toList(),
    );
    await prefs.setString('equalizer_preset', _currentPreset);
  }

  /// Enable or disable the equalizer (used for UI state, persists settings)
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _applyEqualizer();
    await _saveSettings();
  }

  /// Toggle equalizer immediately (used for UI switch, doesn't persist)
  Future<void> toggleEnabled(bool enabled) async {
    print('🎛️ Flutter: toggleEnabled called with: $enabled');
    if (enabled) {
      await playbackManager.enableEqualizer();
      print('🎛️ Flutter: enableEqualizer completed');
    } else {
      await playbackManager.disableEqualizer();
      print('🎛️ Flutter: disableEqualizer completed');
    }

    // Debug: Check EQ state after toggling
    if (Platform.isMacOS) {
      await _debugEQState();
    }
  }

  Future<void> setBandsRealtime(List<double> newBands) async {
    _bands = List<double>.from(newBands);
    _currentPreset = 'Custom';
    // Apply immediately but don't save to preferences
    if (_isEnabled) {
      await playbackManager.applyEqualizerBands(_bands);
    }
  }

  /// Set band gains (expects 10 bands from UI)
 Future<void> setBands(List<double> newBands) async {
    _bands = List<double>.from(newBands);
    _currentPreset = 'Custom';
    await _applyEqualizer();
    await _saveSettings();
  }

  /// Apply a preset equalizer setting
  Future<void> applyPreset(String presetName) async {
    print('🎛️ Flutter: applyPreset called with: $presetName');
    if (systemPresets.containsKey(presetName)) {
      _bands = List<double>.from(systemPresets[presetName]!);
      _currentPreset = presetName;
      await _applyEqualizer();
      await _saveSettings();

      // Debug: Check EQ state after applying preset
      if (Platform.isMacOS) {
        await _debugEQState();
      }
    }
  }

  Future<void> _debugEQState() async {
    try {
      const MethodChannel equalizerChannel = MethodChannel(
        'com.example.tunes4r/audio',
      );
      await equalizerChannel.invokeMethod('debugEQState');
    } catch (e) {
      print('Error calling debugEQState: $e');
    }
  }

  /// Apply the equalizer settings to the audio system
  Future<void> _applyEqualizer() async {
    if (_isEnabled) {
      await playbackManager.enableEqualizer();
      await playbackManager.applyEqualizerBands(_bands);
    } else {
      await playbackManager.disableEqualizer();
    }
  }

/// Test method - call this to verify EQ is working
Future<void> testExtremeEQ() async {
  if (Platform.isMacOS) {
    try {
      const MethodChannel equalizerChannel = MethodChannel('com.example.tunes4r/audio');
      await equalizerChannel.invokeMethod('testExtremeEQ');
      print('🎛️ Extreme EQ test triggered');
    } catch (e) {
      print('Error calling testExtremeEQ: $e');
    }
  }
}

/// Test method - massive bass boost
Future<void> testBassBoost() async {
  if (Platform.isMacOS) {
    try {
      const MethodChannel equalizerChannel = MethodChannel('com.example.tunes4r/audio');
      await equalizerChannel.invokeMethod('testBassBoost');
      print('🎛️ Bass boost test triggered');
    } catch (e) {
      print('Error calling testBassBoost: $e');
    }
  }
}


}
