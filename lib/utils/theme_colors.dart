import 'package:flutter/material.dart';
import '../settings/settings.dart';
import '../theme/theme.dart';

// Cache the shared theme manager to avoid creating Settings instances repeatedly
ThemeManager? _cachedThemeManager;

ThemeManager _getThemeManager() {
  // Use cached instance if available
  _cachedThemeManager ??= Settings().getSharedThemeManager();
  return _cachedThemeManager!;
}

/// Utility functions to get theme colors dynamically
/// Now uses shared ThemeManager from Settings for hot reload compatibility
class ThemeColorsUtil {
  static Color get scaffoldBackgroundColor {
    return _getThemeManager().currentColors?.scaffoldBackground ??
        const Color(0xFFFBF1C7);
  }

  static Color get primaryColor {
    return _getThemeManager().currentColors?.primary ?? const Color(0xFFB57614);
  }

  static Color get secondaryColor {
    return _getThemeManager().currentColors?.secondary ??
        const Color(0xFF79740E);
  }

  static Color get surfaceColor {
    return _getThemeManager().currentColors?.surfacePrimary ??
        const Color(0xFFEBDBB2);
  }

  static Color get textColorPrimary {
    return _getThemeManager().currentColors?.textPrimary ??
        const Color(0xFF3C3836);
  }

  static Color get textColorSecondary {
    return _getThemeManager().currentColors?.textSecondary ??
        const Color(0xFF7C6F64);
  }

  static Color get secondary {
    return _getThemeManager().currentColors?.secondary ??
        const Color(0xFF79740E);
  }

  static Color get error {
    return _getThemeManager().currentColors?.error ?? const Color(0xFFCC241D);
  }

  static Color get appBarBackgroundColor {
    return _getThemeManager().currentColors?.appBarBackground ??
        const Color(0xFFEBDBB2);
  }

  static Color get iconPrimary {
    return _getThemeManager().currentColors?.iconPrimary ??
        const Color(0xFFFFFFFF);
  }

  static Color get iconSecondary {
    return _getThemeManager().currentColors?.iconSecondary ??
        const Color(0xFFFFFFFF);
  }

  static Color get iconDisabled {
    return _getThemeManager().currentColors?.iconDisabled ??
        const Color(0xFF7C6F64);
  }

  static Color get seekBarActiveColor {
    return _getThemeManager().currentColors?.seekBarActive ??
        const Color(0xFFB57614);
  }

  static Color get seekBarInactiveColor {
    return _getThemeManager().currentColors?.seekBarInactive ??
        const Color(0xFFEBDBB2);
  }

  static List<Color> get spectrumColors {
    final colors = _getThemeManager().currentColors;
    if (colors != null) {
      return [colors.spectrumPrimary, colors.spectrumSecondary];
    }
    return [const Color(0xFFB57614), const Color(0xFF79740E)];
  }

  static List<Color> get albumGradient {
    final colors = _getThemeManager().currentColors;
    if (colors != null) {
      return [colors.gradientStart, colors.gradientEnd];
    }
    return [const Color(0xFFB57614), const Color(0xFF79740E)];
  }
}
