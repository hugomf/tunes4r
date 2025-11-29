import 'package:flutter/material.dart';

/// Represents a theme configuration loaded from TOML file
class ThemeConfig {
  final String name;
  final String author;
  final ThemeColors colors;

  const ThemeConfig({
    required this.name,
    required this.author,
    required this.colors,
  });

  factory ThemeConfig.fromMap(Map<String, dynamic> map) {
    return ThemeConfig(
      name: map['name'] as String? ?? 'Unknown Theme',
      author: map['author'] as String? ?? 'Unknown',
      colors: ThemeColors.fromMap(map['colors'] as Map<String, dynamic>? ?? {}),
    );
  }

  @override
  String toString() {
    return 'ThemeConfig(name: $name, author: $author, colors: $colors)';
  }
}

/// Color palette for a theme
class ThemeColors {
  // Background colors
  final Color scaffoldBackground;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color appBarBackground;

  // Primary colors
  final Color primary;
  final Color primaryPressed;
  final Color primaryDisabled;

  // Secondary colors
  final Color secondary;
  final Color secondaryPressed;
  final Color secondaryDisabled;

  // Text colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // Semantic colors
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  // UI elements
  final Color cardBackground;
  final Color cardBorder;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconDisabled;

  // Special elements
  final Color seekBarActive;
  final Color seekBarInactive;
  final Color spectrumPrimary;
  final Color spectrumSecondary;

  // Gradients for album art placeholders
  final Color gradientStart;
  final Color gradientEnd;

  const ThemeColors({
    required this.scaffoldBackground,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.appBarBackground,
    required this.primary,
    required this.primaryPressed,
    required this.primaryDisabled,
    required this.secondary,
    required this.secondaryPressed,
    required this.secondaryDisabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.cardBackground,
    required this.cardBorder,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    required this.seekBarActive,
    required this.seekBarInactive,
    required this.spectrumPrimary,
    required this.spectrumSecondary,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory ThemeColors.fromMap(Map<String, dynamic> map) {
    Color parseColor(dynamic value) {
      if (value is String) {
        return Color(int.parse(value.replaceFirst('#', '0xFF')));
      }
      return Colors.grey; // Fallback
    }

    return ThemeColors(
      scaffoldBackground: parseColor(map['scaffold_background']),
      surfacePrimary: parseColor(map['surface_primary']),
      surfaceSecondary: parseColor(map['surface_secondary']),
      appBarBackground: parseColor(map['app_bar_background']),
      primary: parseColor(map['primary']),
      primaryPressed: parseColor(map['primary_pressed']),
      primaryDisabled: parseColor(map['primary_disabled']),
      secondary: parseColor(map['secondary']),
      secondaryPressed: parseColor(map['secondary_pressed']),
      secondaryDisabled: parseColor(map['secondary_disabled']),
      textPrimary: parseColor(map['text_primary']),
      textSecondary: parseColor(map['text_secondary']),
      textDisabled: parseColor(map['text_disabled']),
      success: parseColor(map['success']),
      error: parseColor(map['error']),
      warning: parseColor(map['warning']),
      info: parseColor(map['info']),
      cardBackground: parseColor(map['card_background']),
      cardBorder: parseColor(map['card_border']),
      iconPrimary: parseColor(map['icon_primary']),
      iconSecondary: parseColor(map['icon_secondary']),
      iconDisabled: parseColor(map['icon_disabled']),
      seekBarActive: parseColor(map['seek_bar_active']),
      seekBarInactive: parseColor(map['seek_bar_inactive']),
      spectrumPrimary: parseColor(map['spectrum_primary']),
      spectrumSecondary: parseColor(map['spectrum_secondary']),
      gradientStart: parseColor(map['gradient_start']),
      gradientEnd: parseColor(map['gradient_end']),
    );
  }

  @override
  String toString() {
    return 'ThemeColors(scaffoldBackground: $scaffoldBackground, primary: $primary, ...)';
  }
}
