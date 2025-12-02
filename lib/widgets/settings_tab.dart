import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme_colors.dart';
import '../../utils/theme_manager.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const platform = MethodChannel('com.example.tunes4r/media_controls');

  Future<void> _requestMediaPermissions() async {
    try {
      // This only works on macOS; other platforms will ignore
      final result = await platform.invokeMethod('requestMediaPermissions');
      print('Media permissions request result: $result');
    } on PlatformException catch (e) {
      print('Error requesting media permissions: ${e.message}');
      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Media permission setup requires macOS. Other platforms may work automatically.',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final availableThemes = themeManager.getThemes();
    final currentTheme = ThemeManager().getCurrentTheme();

    return Container(
      color: ThemeColorsUtil.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Logic: Calculate columns based on width
          const double minCardWidth = 220.0;
          
          // Calculate how many columns can fit, ensuring each column is at least minCardWidth.
          int gridColumns = (constraints.maxWidth / (minCardWidth + 16.0)).floor();
          
          // Enforce minimum of 1 column and maximum of 5.
          if (gridColumns < 1) gridColumns = 1;
          if (gridColumns > 5) gridColumns = 5;
          
          // If the screen width is very small, we constrain the ListView
          double maxListWidth = constraints.maxWidth > 1400 ? 1400 : constraints.maxWidth;
          
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxListWidth),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                children: [
                  // --- Header Section: Media Controls ---
                  _buildSectionHeader(
                    '🎵 Media Controls', 
                    'Manage permissions for external devices'
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Media Controls Card ---
                  // Pass constraints down to decide padding
                  _buildMediaControlCard(constraints.maxWidth), 
                  
                  const SizedBox(height: 40),

                  // --- Theme Header ---
                  _buildSectionHeader(
                    '🎨 Appearance', 
                    'Choose a theme that fits your vibe'
                  ),
                  const SizedBox(height: 24),

                  // --- Responsive Grid ---
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85, 
                    ),
                    itemCount: availableThemes.length,
                    itemBuilder: (context, index) {
                      final themeName = availableThemes.keys.elementAt(index);
                      final theme = availableThemes[themeName]!;
                      final isSelected = currentTheme?.name == theme.name;

                      return _buildThemeCard(themeName, theme, isSelected, constraints.maxWidth); // Pass screen width
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // --- Footer ---
                  Center(
                    child: Opacity(
                      opacity: 0.6,
                      child: Text(
                        '💡 Pro Tip: Themes apply instantly and save automatically.',
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a standardized header for a settings section.
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: ThemeColorsUtil.textColorPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: ThemeColorsUtil.textColorSecondary,
          ),
        ),
      ],
    );
  }

  /// Builds the macOS-specific media control card.
  Widget _buildMediaControlCard(double screenWidth) {
    // Define breakpoints and padding
    const double breakpoint = 500;
    final bool isSmallScreen = screenWidth < breakpoint;

    // Use generous padding for large screens, minimal for small screens
    final double cardPadding = isSmallScreen ? 16.0 : 24.0;
    final double contentSpacing = isSmallScreen ? 12.0 : 16.0;
    final double buttonVerticalPadding = isSmallScreen ? 12.0 : 16.0;
    
    // Content of the card, structured for responsiveness
    Widget icon = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.headphones, color: ThemeColorsUtil.primaryColor, size: 28),
    );

    Widget textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, 
      children: [
        Text(
          'macOS Media Keys',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16, // Smaller font on small screens
            fontWeight: FontWeight.bold,
            color: ThemeColorsUtil.textColorPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enable support for keyboard media keys & bluetooth headsets.',
          style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: ThemeColorsUtil.textColorSecondary),
          maxLines: 2, 
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: ElevatedButton(
        onPressed: _requestMediaPermissions,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeColorsUtil.primaryColor,
          foregroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: buttonVerticalPadding),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Grant Access'),
      ),
    );

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeColorsUtil.primaryColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isSmallScreen 
          // Small Screen Layout (Vertical)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    icon,
                    SizedBox(width: contentSpacing),
                    Expanded(child: textContent),
                  ],
                ),
                SizedBox(height: contentSpacing),
                Center(child: button), // Center button in the vertical layout
              ],
            )
          // Large Screen Layout (Horizontal)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                SizedBox(width: contentSpacing),
                Expanded(child: textContent),
                SizedBox(width: contentSpacing),
                button,
              ],
            ),
    );
  }

  /// Builds the theme card with the "Mini-UI" preview.
  Widget _buildThemeCard(String themeName, dynamic theme, bool isSelected, double screenWidth) {
    const double cardBreakpoint = 300;
    final bool isVerySmallCard = screenWidth < cardBreakpoint;

    return GestureDetector(
      onTap: () {
        setState(() {
          ThemeManager().setTheme(themeName);
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎨 Switched to ${theme.name}',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
            behavior: SnackBarBehavior.floating,
            width: 400,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary, // The card background matches the theme's surface
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ThemeColorsUtil.primaryColor : Colors.transparent,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (isSelected)
              BoxShadow(
                color: ThemeColorsUtil.primaryColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Mini UI Preview Area ---
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Mini App Bar (Surface Secondary or Primary)
                        Container(
                          height: 32,
                          color: theme.colors.surfaceSecondary ?? theme.colors.primary.withOpacity(0.8), 
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8, 
                                decoration: BoxDecoration(color: theme.colors.primary, shape: BoxShape.circle)
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 8, height: 8, 
                                decoration: BoxDecoration(color: theme.colors.secondary, shape: BoxShape.circle)
                              ),
                            ],
                          ),
                        ),
                        // Mini Body Content (Main background of the simulated app)
                        Expanded(
                          child: Container(
                            color: theme.colors.surfacePrimary, 
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Skeleton Title
                                Container(
                                  height: 8, width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colors.textPrimary.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                ),
                                const SizedBox(height: 8.0), 
                                
                                Expanded( 
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Skeleton Lines
                                      Container(
                                        height: 6, width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme.colors.textSecondary.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 6, width: 80,
                                        decoration: BoxDecoration(
                                          color: theme.colors.textSecondary.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                      ),
                                      const Spacer(),
                                      // Mini FAB (Primary color accent)
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Container(
                                          height: 24, width: 24,
                                          decoration: BoxDecoration(
                                            color: theme.colors.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
                                          ),
                                          child: Icon(Icons.play_arrow, size: 14, color: theme.colors.surfacePrimary),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Selected Checkmark Overlay
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: ThemeColorsUtil.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: ThemeColorsUtil.scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // --- Theme Details Footer ---
              Container(
                color: ThemeColorsUtil.surfaceColor, // Keep footer neutral to read text easily
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        // NEW FIX: Scale font size down for very small card widths
                        fontSize: isVerySmallCard ? 12 : 14, 
                        color: ThemeColorsUtil.textColorPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 12, color: ThemeColorsUtil.textColorSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            theme.author,
                            style: TextStyle(
                              // NEW FIX: Scale font size down for very small card widths
                              fontSize: isVerySmallCard ? 10 : 11, 
                              color: ThemeColorsUtil.textColorSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}