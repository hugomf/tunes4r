import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/playback_manager.dart';
import '../utils/theme_colors.dart';

class NowPlayingTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Album art display
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildAlbumArt(),
              ),

              const SizedBox(height: 20),

              // Current song info - shows title and artist on same line like player controls
              _buildSongInfo(),

              const SizedBox(height: 20),

              // Play controls
              _buildMiniControls(),

              const SizedBox(height: 20),

              // Spectrum visualizer - only shown when needed
              _buildSpectrumVisualizer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt() {
    final currentSong = playbackManager.currentSong;

    if (currentSong?.albumArt != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.memory(
          currentSong!.albumArt!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeColorsUtil.albumGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.music_note,
                size: 80,
                color: ThemeColorsUtil.scaffoldBackgroundColor,
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ThemeColorsUtil.albumGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          Icons.music_note,
          size: 80,
          color: ThemeColorsUtil.scaffoldBackgroundColor,
        ),
      );
    }
  }

  Widget _buildSongInfo() {
    final currentSong = playbackManager.currentSong;
    if (currentSong != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          '${currentSong.title} - ${currentSong.artist.isNotEmpty ? currentSong.artist : 'Unknown Artist'}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ThemeColorsUtil.textColorPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      return Column(
        children: [
          Text(
            'No song is currently playing',
            style: TextStyle(
              fontSize: 18,
              color: ThemeColorsUtil.textColorSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Play a song from your Library or Playlist',
            style: TextStyle(
              fontSize: 14,
              color: ThemeColorsUtil.textColorSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _buildMiniControls() {
    if (playbackManager.currentSong == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPlayPrevious,
          icon: Icon(
            Icons.skip_previous,
            color: ThemeColorsUtil.primaryColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onTogglePlayPause,
          icon: Icon(
            playbackManager.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: ThemeColorsUtil.primaryColor,
            size: 64,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onPlayNext,
          icon: Icon(
            Icons.skip_next,
            color: ThemeColorsUtil.primaryColor,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildSpectrumVisualizer() {
    if (!playbackManager.isPlaying || playbackManager.currentSong == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 35,
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(20, (index) {
          final height = (_playbackManager.spectrumData[index % _playbackManager.spectrumData.length] * 25 + 5).clamp(5.0, 25.0);
          return Container(
            width: 4,
            height: height,
            margin: EdgeInsets.only(right: index < 19 ? 2 : 0), // Small gap between bars
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeColorsUtil.spectrumColors,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // Access playback manager for spectrum data
  PlaybackManager get _playbackManager => playbackManager;
}
