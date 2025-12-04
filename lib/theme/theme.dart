// Now using ChangeNotifier for hot reload compatibility - this is safe because
// we use a shared instance managed by Settings bounded context
import 'package:flutter/material.dart';
import 'package:tunes4r/models/theme_config.dart';
import 'theme_actions.dart';

/// Theme manager with ChangeNotifier for MaterialApp theme rebuilding on hot reload
class ThemeManager with ChangeNotifier {
  // Just data, no streams to avoid hot reload issues
  Map<String, ThemeConfig> _themes = {};
  ThemeConfig? _currentTheme;
  bool _isLoaded = false;

  // Simple change counter for UI rebuilds
  int _changeCounter = 0;

  ThemeManager();

  /// Simple async initialization - no complex state management
  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final themes = await ThemeActions.loadThemeAssets();

      _themes = themes;
      // Default to gruvbox_light
      _currentTheme = themes['gruvbox_light'] ?? themes.values.first;
      _isLoaded = true;

      print('Simple theme manager loaded ${_themes.length} themes');
    } catch (e) {
      print('Theme initialization failed: $e');
      throw e;
    }
  }

  /// Simple synchronous theme switching - no async complexity
  void switchTheme(String themeName) {
    final theme = _themes[themeName];
    if (theme != null && theme != _currentTheme) {
      _currentTheme = theme;
      _changeCounter++; // Increment for UI rebuilds
      notifyListeners(); // Notify MaterialApp to rebuild theme
      print('Theme switched to: ${theme.name}');
    } else if (theme == null) {
      print('Theme not found: $themeName');
    }
  }

  /// Getters - simple, synchronous, no state complications
  Map<String, ThemeConfig> get availableThemes => _themes;
  ThemeConfig? get currentTheme => _currentTheme;
  ThemeColors? get currentColors => _currentTheme?.colors;
  bool get isLoaded => _isLoaded;
  List<String> get themeNames => _themes.keys.toList();
  int get changeCounter => _changeCounter;
}
