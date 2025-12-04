import 'settings_commands.dart';
import 'settings_state.dart';

/// Pure functions for Settings state transformations
class SettingsActions {
  static SettingsState initializeSettings(
    SettingsState state,
    InitializeSettingsCommand command,
  ) {
    return state.copyWith(isInitialized: true);
  }
}
