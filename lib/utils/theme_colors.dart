import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// Utility functions to get theme colors dynamically
class ThemeColorsUtil {
  static Color get scaffoldBackgroundColor {
    return ThemeManager().getCurrentColors()?.scaffoldBackground ?? const Color(0xFFFBF1C7);
  }

  static Color get primaryColor {
    return ThemeManager().getCurrentColors()?.primary ?? const Color(0xFFB57614);
  }

  static Color get secondaryColor {
    return ThemeManager().getCurrentColors()?.secondary ?? const Color(0xFF79740E);
  }

  static Color get surfaceColor {
    return ThemeManager().getCurrentColors()?.surfacePrimary ?? const Color(0xFFEBDBB2);
  }

  static Color get textColorPrimary {
    return ThemeManager().getCurrentColors()?.textPrimary ?? const Color(0xFF3C3836);
  }

  static Color get textColorSecondary {
    return ThemeManager().getCurrentColors()?.textSecondary ?? const Color(0xFF7C6F64);
  }

  static Color get secondary {
    return ThemeManager().getCurrentColors()?.secondary ?? const Color(0xFF79740E);
  }

  static Color get error {
    return ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D);
  }

  static Color get appBarBackgroundColor {
    return ThemeManager().getCurrentColors()?.appBarBackground ?? const Color(0xFFEBDBB2);
  }

  static Color get iconPrimary {
    return ThemeManager().getCurrentColors()?.iconPrimary ?? const Color(0xFFFFFFFF);
  }

  static Color get iconSecondary {
    return ThemeManager().getCurrentColors()?.iconSecondary ?? const Color(0xFFFFFFFF);
  }

  static Color get iconDisabled {
    return ThemeManager().getCurrentColors()?.iconDisabled ?? const Color(0xFF7C6F64);
  }

  static Color get seekBarActiveColor {
    return ThemeManager().getCurrentColors()?.seekBarActive ?? const Color(0xFFB57614);
  }

  static Color get seekBarInactiveColor {
    return ThemeManager().getCurrentColors()?.seekBarInactive ?? const Color(0xFFEBDBB2);
  }

  static List<Color> get spectrumColors {
    final colors = ThemeManager().getCurrentColors();
    if (colors != null) {
      return [colors.spectrumPrimary, colors.spectrumSecondary];
    }
    return [const Color(0xFFB57614), const Color(0xFF79740E)];
  }

  static List<Color> get albumGradient {
    final colors = ThemeManager().getCurrentColors();
    if (colors != null) {
      return [colors.gradientStart, colors.gradientEnd];
    }
    return [const Color(0xFFB57614), const Color(0xFF79740E)];
  }
}
