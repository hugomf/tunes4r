// Tunes4R Color Scheme (Gruvbox Inspired)
import 'dart:ui';

const Color scaffoldBackgroundColor = Color(0xFFFBF1C7); // Gruvbox light bg
const Color primaryColor = Color(0xFFB57614); // Gruvbox yellow
const Color secondaryColor = Color(0xFF79740E); // Gruvbox green
const Color surfaceColor = Color(0xFFEBDBB2); // Gruvbox light bg1

const Color accentColor = Color(0xFFFBF1C7); // Light color for highlights
const Color textColorPrimary = Color(0xFF3C3836); // Dark text
const Color textColorSecondary = Color(0xFF7C6F64); // Medium gray
const Color appBarBackgroundColor = Color(0xFFEBDBB2);

// Music Player Constants
const Duration equalizerDialogWidth = Duration(milliseconds: 550);
const Duration equalizerDialogHeight = Duration(milliseconds: 350);
const double maxEqGain = 20.0;
const double minEqGain = -20.0;
const int eqDivisions = 40;

// Volume and Speed Constants
const double defaultVolume = 1.0;
const double defaultSpeed = 1.0;
const double minVolume = 0.0;
const double maxVolume = 1.0;
const double minSpeed = 0.5;
const double maxSpeed = 2.0;

// Spectrum Visualizer
const int spectrumDataPoints = 32;
const int spectrumBars = 20;

// Database Constants
const String databaseName = 'tunes4r.db';
const int databaseVersion = 3;

// Playlist Position Limits
const int minPlaylistPosition = 0;

// UI Sizing
const double sidebarWidth = 250.0;
const double navItemPadding = 12.0;
const double navItemMargin = 8.0;
const double navItemBorderRadius = 8.0;

// Animation Durations
const Duration spectrumAnimationDuration = Duration(milliseconds: 50);
const Duration playerTransitionDuration = Duration(milliseconds: 300);
