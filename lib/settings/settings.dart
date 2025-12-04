import 'package:flutter/material.dart';
import 'settings_actions.dart';
import 'settings_commands.dart';
import 'settings_state.dart';
import 'widgets/settings_tab.dart';

import 'package:tunes4r/theme/theme.dart';

/// Settings Bounded Context
/// Manages settings-related functionality and state
class Settings {
  static ThemeManager? _sharedManager;
  SettingsState _state = SettingsState.initial();

  Settings();

  SettingsState get state => _state;

  /// Get the shared theme manager, creating it if necessary
  /// Uses static to survive hot reload of individual instances
  ThemeManager get _manager {
    _sharedManager ??= ThemeManager();
    return _sharedManager!;
  }

  /// Initialize the settings bounded context
  Future<void> initialize() async {
    // Initialize the theme manager
    await _manager.initialize();

    try {
      // Execute initialization command
      _state = SettingsActions.initializeSettings(
        _state,
        InitializeSettingsCommand(),
      );
    } catch (e) {
      print('Failed to initialize settings bounded context: $e');
      rethrow;
    }
  }

  /// Get the settings tab widget
  /// This is the only interface other parts of the app should use
  Widget getSettingsTab() => SettingsTab(themeManager: _manager);

  /// Public getter for shared theme manager across the app
  /// This ensures hot reload compatibility by using the same instance
  ThemeManager getSharedThemeManager() => _manager;

  /// Get navigation title for the settings tab
  String get navigationTitle => 'Settings';
}
