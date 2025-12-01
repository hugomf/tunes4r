import 'package:flutter/material.dart';
import '../../models/theme_config.dart';
import '../../utils/theme_colors.dart';
import '../../utils/theme_manager.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final availableThemes = themeManager.getThemes();

    return Container(
      color: ThemeColorsUtil.scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '🎨 Theme Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ThemeColorsUtil.textColorPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your favorite theme from our legendary collection!',
            style: TextStyle(
              fontSize: 16,
              color: ThemeColorsUtil.textColorSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: availableThemes.length,
            itemBuilder: (context, index) {
              final themeName = availableThemes.keys.elementAt(index);
              final theme = availableThemes[themeName]!;
              final currentTheme = ThemeManager().getCurrentTheme();
              final isSelected = currentTheme?.name == theme.name;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    ThemeManager().setTheme(themeName);
                  });
                  // Show feedback to user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎨 Switched to "${theme.name}" theme!',
                        style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                      ),
                      backgroundColor: ThemeColorsUtil.surfaceColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.colors.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: theme.colors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Color preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colors.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '💡 Pro Tip: Themes are automatically saved and applied immediately!',
            style: TextStyle(
              color: ThemeColorsUtil.secondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
