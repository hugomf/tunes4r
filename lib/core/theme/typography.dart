import 'package:flutter/material.dart';

/// Consistent typography system for Tunes4R
/// Defines all text styles used throughout the app
class AppTypography {
  // ========================================================================
  // HEADLINE STYLES (Largest, most prominent)
  // ========================================================================

  /// H1: App titles, main headings (32px)
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// H2: Section headings (24px)
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// H3: Subsection headings (20px)
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  /// H4: Smaller section titles (18px)
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // ========================================================================
  // BODY TEXT STYLES
  // ========================================================================

  /// Body1: Primary body text (16px)
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Body2: Secondary body text (14px)
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ========================================================================
  // LABEL & CAPTION STYLES (Smallest)
  // ========================================================================

  /// Label: Button labels, form labels (14px, semibold)
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Caption: Small explanatory text (12px)
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.5,
  );

  /// Overline: Very small metadata text (12px, uppercase)
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.6,
    textBaseline: TextBaseline.alphabetic,
  );

  // ========================================================================
  // SPECIALIZED STYLES
  // ========================================================================

  /// Song title: For song names in lists (16px, medium weight)
  static const TextStyle songTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// Song title large: For detailed views (18px, semibold)
  static const TextStyle songTitleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
  );

  /// Artist name: For artist names (14px, regular)
  static const TextStyle artistName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.0,
  );

  /// Album name: For album names (16px, medium)
  static const TextStyle albumName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// Button text: For button content (14px, semibold)
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Menu item: For drawer/navigation items (15px, medium)
  static const TextStyle menuItem = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.0,
  );

  /// Status text: For playing/selected states (12px, semibold)
  static const TextStyle statusText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.1,
  );

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Creates a copy of a TextStyle with theme-aware text color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Creates a copy of a TextStyle with font weight override
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Creates a copy of a TextStyle with size override
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }
}
