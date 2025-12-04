import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../services/playback_manager.dart';
import '../../utils/theme_colors.dart';
import 'dart:math' as math;

class NowPlayingTab extends StatefulWidget {
  final PlaybackManager playbackManager;
  final Function()? onTogglePlayPause;
  final Function()? onPlayNext;
  final Function()? onPlayPrevious;

  const NowPlayingTab({
    super.key,
    required this.playbackManager,
    this.onTogglePlayPause,
    this.onPlayNext,
    this.onPlayPrevious,
  });

  @override
  State<NowPlayingTab> createState() => _NowPlayingTabState();
}

class _NowPlayingTabState extends State<NowPlayingTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  /// Public playback methods - NowPlayingTab handles current song playback
  void contextPlaySong(Song song) => widget.playbackManager.playSong(song);

  Future<void> contextTogglePlayPause() async => await widget.playbackManager.togglePlayPause();

  @override
  Widget build(BuildContext context) {
    // Get current playback state
    final bool isPlaying = widget.playbackManager.isPlaying;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate responsive sizes
    final availableHeight = screenHeight - MediaQuery.of(context).padding.top - 100;
    final maxVinylSize = (screenWidth * 0.65).clamp(180.0, 280.0);
    final vinylSize = (availableHeight * 0.45).clamp(180.0, maxVinylSize);
    
    // Calculate responsive font sizes based on vinyl size
    final titleFontSize = (vinylSize * 0.12).clamp(20.0, 28.0);
    final artistFontSize = (vinylSize * 0.07).clamp(14.0, 18.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Album art with animated glow and rotation
                    Flexible(
                      flex: 3,
                      child: Center(child: _buildAlbumArtWithGlow(vinylSize)),
                    ),

                    const SizedBox(height: 20),

                    // Current song info with fade animation
                    Flexible(
                      flex: 1,
                      child: _buildSongInfo(titleFontSize, artistFontSize),
                    ),

                    const SizedBox(height: 20),

                    // Spectrum visualizer
                    Flexible(
                      flex: 1,
                      child: _buildSpectrumVisualizer(),
                    ),
                    
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArtWithGlow(double size) {
    final currentSong = widget.playbackManager.currentSong;
    final bool isPlaying = widget.playbackManager.isPlaying;
    final glowSize = size + 20;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated glow effect when playing
        if (isPlaying)
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (math.sin(_rotationController.value * 2 * math.pi) * 0.05),
                child: Container(
                  width: glowSize,
                  height: glowSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ThemeColorsUtil.primaryColor.withOpacity(0.4),
                        ThemeColorsUtil.primaryColor.withOpacity(0.0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

        // Rotating vinyl effect
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: isPlaying ? _rotationController.value * 2 * math.pi : 0,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vinyl record grooves effect
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColorsUtil.textColorPrimary.withOpacity(0.8),
                ),
                child: _buildAlbumArt(size),
              ),
              // Center label (vinyl center like real vinyl records)
              Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColorsUtil.textColorPrimary,
                  border: Border.all(
                    color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColorsUtil.textColorPrimary.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: size * 0.055,
                    height: size * 0.055,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(double size) {
    final currentSong = widget.playbackManager.currentSong;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: ThemeColorsUtil.textColorPrimary.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: currentSong?.albumArt != null
            ? Image.memory(
                currentSong!.albumArt!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAlbumArt();
                },
              )
            : _buildDefaultAlbumArt(),
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ThemeColorsUtil.albumGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.music_note,
        size: 90,
        color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.9),
      ),
    );
  }

  Widget _buildSongInfo(double titleFontSize, double artistFontSize) {
    final currentSong = widget.playbackManager.currentSong;
    if (currentSong != null) {
      return Column(
        children: [
          // Song title
          Text(
            currentSong.title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: ThemeColorsUtil.textColorPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Artist name
          Text(
            currentSong.artist.isNotEmpty ? currentSong.artist : 'Unknown Artist',
            style: TextStyle(
              fontSize: artistFontSize,
              color: ThemeColorsUtil.textColorSecondary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Icon(
            Icons.music_off,
            size: titleFontSize * 2,
            color: ThemeColorsUtil.textColorSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No song is currently playing',
            style: TextStyle(
              fontSize: artistFontSize + 2,
              fontWeight: FontWeight.w500,
              color: ThemeColorsUtil.textColorSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Play a song from your Library or Playlist',
            style: TextStyle(
              fontSize: artistFontSize - 2,
              color: ThemeColorsUtil.textColorSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _buildSpectrumVisualizer() {
    if (!widget.playbackManager.isPlaying || widget.playbackManager.currentSong == null) {
      return const SizedBox(height: 60);
    }

    return Container(
      height: 60,
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(30, (index) {
          final spectrumIndex = index % widget.playbackManager.spectrumData.length;
          final height = (widget.playbackManager.spectrumData[spectrumIndex] * 45 + 8)
              .clamp(8.0, 50.0);
          
          return Expanded(
            child: Container(
              height: height,
              margin: EdgeInsets.only(right: index < 29 ? 3 : 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeColorsUtil.spectrumColors,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEnhancedControls() {
    if (widget.playbackManager.currentSong == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: ThemeColorsUtil.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: Icons.skip_previous_rounded,
            onPressed: widget.onPlayPrevious,
            size: 36,
          ),
          const SizedBox(width: 24),
          _buildPlayPauseButton(),
          const SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            onPressed: widget.onPlayNext,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Function()? onPressed,
    required double size,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            ThemeColorsUtil.primaryColor.withOpacity(0.2),
            ThemeColorsUtil.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: ThemeColorsUtil.primaryColor,
        iconSize: size,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    final isPlaying = widget.playbackManager.isPlaying;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: ThemeColorsUtil.albumGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColorsUtil.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTogglePlayPause,
          borderRadius: BorderRadius.circular(36),
          child: Icon(
            isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: ThemeColorsUtil.iconPrimary,
            size: 40,
          ),
        ),
      ),
    );
  }
}
