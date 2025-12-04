import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:toml/toml.dart';

import '../../models/theme_config.dart';
import 'theme_commands.dart';
import 'theme_state.dart';

/// Pure functions that transform ThemeState based on commands
/// No side effects, just state transformations
class ThemeActions {

  /// Set loading state when starting theme initialization
  static ThemeState initializeThemes(ThemeState state, InitializeThemesCommand command) {
    return state.copyWith(
      isLoading: true,
      errorMessage: null,
    );
  }

  /// Load all themes and set default
  static ThemeState themesLoaded(ThemeState state, Map<String, ThemeConfig> themes) {
    // Set default theme (gruvbox_light if available, otherwise first theme)
    var defaultTheme = themes['gruvbox_light'];
    if (defaultTheme == null && themes.isNotEmpty) {
      defaultTheme = themes.values.first;
    }

    return state.copyWith(
      availableThemes: themes,
      currentTheme: defaultTheme,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// Handle theme loading error
  static ThemeState themesLoadFailed(ThemeState state, String error) {
    return state.copyWith(
      isLoading: false,
      errorMessage: error,
    );
  }

  /// Switch to a different theme
  static ThemeState switchTheme(ThemeState state, SwitchThemeCommand command) {
    final theme = state.availableThemes[command.themeName];
    if (theme != null) {
      return state.copyWith(
        currentTheme: theme,
        errorMessage: null,
      );
    }
    return state.copyWith(
      errorMessage: 'Theme "${command.themeName}" not found',
    );
  }

  /// Helper: Load all theme assets dynamically - copied from working ThemeManager
  /// Note: This method has side effects, should be called from the context
  static Future<Map<String, ThemeConfig>> loadThemeAssets() async {
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
      final Map<String, ThemeConfig> themes = {};
      for (final themeName in themeNames) {
        final themeConfig = await _loadTheme(themeName);
        if (themeConfig != null) {
          themes[themeName] = themeConfig;
        }
      }

      print('Successfully loaded ${themes.length} themes: ${themes.keys.join(', ')}');
      return themes;
    } catch (e) {
      print('Error loading themes: $e'.toString());
      throw Exception('Failed to load theme assets: $e');
    }
  }

  /// Helper: Load a single theme from TOML file
  static Future<ThemeConfig?> _loadTheme(String themeName) async {
    try {
      final tomlContent = await rootBundle.loadString('assets/themes/$themeName.toml');
      final tomlData = TomlDocument.parse(tomlContent).toMap();

      return ThemeConfig.fromMap(tomlData);
    } catch (e) {
      return null; // Silently skip failed theme loads
    }
  }
}
