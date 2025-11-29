import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:toml/toml.dart';

import '../models/theme_config.dart';

/// Manages theme loading and switching
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  final Map<String, ThemeConfig> _themes = {};
  ThemeConfig? _currentTheme;

  /// Initialize theme manager by loading all available themes
  Future<void> initialize() async {
    await _loadAllThemes();
    // Set default theme
    if (_themes.containsKey('gruvbox_light')) {
      _currentTheme = _themes['gruvbox_light'];
    } else if (_themes.isNotEmpty) {
      // Fallback to first available theme if gruvbox_light is not found
      _currentTheme = _themes.values.first;
    }
  }

  /// Dynamically discover and load all theme TOML files from assets/themes/
  Future<void> _loadAllThemes() async {
    try {
      // Load the Flutter asset manifest to discover all theme files
      final String manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);

      // Find all .toml files in assets/themes/
      final List<String> themeAssetPaths = manifest.keys
          .where((String key) => key.startsWith('assets/themes/') && key.endsWith('.toml'))
          .toList();

      // Extract theme names from the asset paths
      final List<String> themeNames = themeAssetPaths
          .map((path) => path.split('/').last.replaceAll('.toml', ''))
          .toSet() // Remove duplicates
          .toList()
        ..sort(); // Sort for consistent ordering

      print('Found ${themeNames.length} theme files: ${themeNames.join(', ')}');

      // Load each discovered theme
      for (final themeName in themeNames) {
        final themeConfig = await _loadTheme(themeName);
        if (themeConfig != null) {
          _themes[themeName] = themeConfig;
        }
      }

      print('Successfully loaded ${_themes.length} themes: ${_themes.keys.join(', ')}');
    } catch (e) {
      print('Error loading themes: $e'.toString());
      // Fallback to hardcoded list if dynamic loading fails
      await _loadThemesFallback();
    }
  }

  /// Fallback method to load themes when dynamic discovery fails
  Future<void> _loadThemesFallback() async {
    print('Falling back to hardcoded theme list...');
    final themeNames = [
      'gruvbox_light',
      'gruvbox_dark',
      'batman',
      'superman',
      'solarized_dark',
      'neon',
      'monokai',
      'dracula',
      'solarized_light',
      'minimal_light',
      'pastel_light',
      'nord',
      'one_dark_pro',
      'catppuccin_mocha',
      'tokyo_night',
      'material_dark'
    ];

    for (final themeName in themeNames) {
      final themeConfig = await _loadTheme(themeName);
      if (themeConfig != null) {
        _themes[themeName] = themeConfig;
      }
    }

    print('Loaded ${_themes.length} themes via fallback: ${_themes.keys.join(', ')}');
  }

  /// Load a single theme from TOML file
  Future<ThemeConfig?> _loadTheme(String themeName) async {
    try {
      final tomlContent = await rootBundle.loadString('assets/themes/$themeName.toml');
      final tomlData = TomlDocument.parse(tomlContent).toMap();

      return ThemeConfig.fromMap(tomlData);
    } catch (e) {
      print('Error loading theme $themeName: $e');
      return null;
    }
  }

  /// Get all available themes
  Map<String, ThemeConfig> getThemes() => Map.unmodifiable(_themes);

  /// Get current theme
  ThemeConfig? getCurrentTheme() => _currentTheme;

  /// Set current theme by name
  void setTheme(String themeName) {
    if (_themes.containsKey(themeName)) {
      _currentTheme = _themes[themeName];
      print('Switched to theme: ${_currentTheme?.name}');
    } else {
      print('Theme not found: $themeName');
    }
  }

  /// Get theme by name
  ThemeConfig? getTheme(String themeName) => _themes[themeName];

  /// Get list of theme names
  List<String> getThemeNames() => _themes.keys.toList()..sort();

  /// Get current theme colors
  ThemeColors? getCurrentColors() => _currentTheme?.colors;
}
