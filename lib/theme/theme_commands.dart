/// Domain events emitted by the Theme bounded context
abstract class ThemeEvent {
  const ThemeEvent();
}

/// Events emitted by the Theme bounded context
class ThemesLoadedEvent extends ThemeEvent {
  final Map<String, String> themeNames; // name -> displayName
  const ThemesLoadedEvent(this.themeNames);
}

class ThemeSwitchedEvent extends ThemeEvent {
  final String themeName;
  final String author;
  const ThemeSwitchedEvent(this.themeName, this.author);
}

class ThemeLoadErrorEvent extends ThemeEvent {
  final String error;
  const ThemeLoadErrorEvent(this.error);
}

/// Commands for theme operations
abstract class ThemeCommand {
  const ThemeCommand();
}

class InitializeThemesCommand extends ThemeCommand {}

class SwitchThemeCommand extends ThemeCommand {
  final String themeName;
  const SwitchThemeCommand(this.themeName);
}
