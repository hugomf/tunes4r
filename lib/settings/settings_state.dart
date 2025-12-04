/// Immutable Settings state
/// Only contains data that affects the settings UI
class SettingsState {
  final bool isInitialized;

  const SettingsState({
    this.isInitialized = false,
  });

  SettingsState copyWith({
    bool? isInitialized,
  }) {
    return SettingsState(
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  static SettingsState initial() => const SettingsState();
}
