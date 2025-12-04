import '../../models/theme_config.dart';

/// State of the Theme bounded context
class ThemeState {
  final Map<String, ThemeConfig> availableThemes;
  final ThemeConfig? currentTheme;
  final bool isLoading;
  final String? errorMessage;

  const ThemeState({
    required this.availableThemes,
    required this.currentTheme,
    required this.isLoading,
    required this.errorMessage,
  });

  // Initial empty state
  const ThemeState.initial()
      : availableThemes = const {},
        currentTheme = null,
        isLoading = false,
        errorMessage = null;

  ThemeState copyWith({
    Map<String, ThemeConfig>? availableThemes,
    ThemeConfig? currentTheme,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ThemeState(
      availableThemes: availableThemes ?? this.availableThemes,
      currentTheme: currentTheme ?? this.currentTheme,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Computed properties
  ThemeColors? get colors => currentTheme?.colors;
  bool get isLoaded => availableThemes.isNotEmpty;
  bool get hasError => errorMessage != null;

  List<String> get themeNames => availableThemes.keys.toList()..sort();

  @override
  String toString() {
    return 'ThemeState(themes: ${availableThemes.length}, current: ${currentTheme?.name}, loading: $isLoading, error: $errorMessage)';
  }
}
