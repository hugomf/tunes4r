import 'package:flutter/material.dart';
import '../models/song.dart';
import '../utils/theme_colors.dart';
import 'equalizer_dialog.dart';

typedef PlayPauseCallback = void Function();
typedef SkipNextCallback = void Function();
typedef SkipPreviousCallback = void Function();
typedef ShuffleToggleCallback = void Function();
typedef RepeatToggleCallback = void Function();
typedef SeekCallback = void Function(double seconds);

class MusicPlayerWidget extends StatelessWidget {
  final bool isMobile;
  final bool isPlaying;
  final bool isShuffling;
  final bool isRepeating;
  final Duration position;
  final Duration duration;
  final Song? currentSong;
  final PlayPauseCallback onPlayPause;
  final SkipNextCallback onSkipNext;
  final SkipPreviousCallback onSkipPrevious;
  final ShuffleToggleCallback onShuffleToggle;
  final RepeatToggleCallback onRepeatToggle;
  final SeekCallback onSeek;

  const MusicPlayerWidget({
    Key? key,
    required this.isMobile,
    required this.isPlaying,
    required this.isShuffling,
    required this.isRepeating,
    required this.position,
    required this.duration,
    required this.currentSong,
    required this.onPlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onShuffleToggle,
    required this.onRepeatToggle,
    required this.onSeek,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: ThemeColorsUtil.appBarBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress and time
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
              Expanded(
                child: Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  activeColor: ThemeColorsUtil.seekBarActiveColor,
                  inactiveColor: ThemeColorsUtil.seekBarInactiveColor,
                  onChanged: (value) => onSeek(value),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
            ],
          ),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isMobile ? [
              // Mobile: Compact controls - all icons visible with tight spacing
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.shuffle,
                        color: isShuffling ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                        size: 20,
                      ),
                      onPressed: onShuffleToggle,
                      tooltip: 'Shuffle',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.skip_previous, size: 20),
                      onPressed: onSkipPrevious,
                      color: ThemeColorsUtil.textColorPrimary,
                      tooltip: 'Previous',
                    ),
                    const SizedBox(width: 2),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ThemeColorsUtil.primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                        ),
                        onPressed: onPlayPause,
                        tooltip: 'Play/Pause',
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.skip_next, size: 20),
                      onPressed: onSkipNext,
                      color: ThemeColorsUtil.textColorPrimary,
                      tooltip: 'Next',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.equalizer,
                        color: ThemeColorsUtil.textColorSecondary,
                        size: 20,
                      ),
                      onPressed: () => _showEqualizerDialog(context),
                      tooltip: 'Equalizer',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.repeat,
                        color: isRepeating ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                        size: 20,
                      ),
                      onPressed: onRepeatToggle,
                      tooltip: 'Repeat',
                    ),
                  ],
                ),
              ),
            ] : [
              // Desktop: All controls
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: isShuffling ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: onShuffleToggle,
                tooltip: 'Shuffle',
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: onSkipPrevious,
                color: ThemeColorsUtil.textColorPrimary,
                tooltip: 'Previous',
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColorsUtil.primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColorsUtil.primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(16),
                  iconSize: 32,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  onPressed: onPlayPause,
                  tooltip: 'Play/Pause',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: onSkipNext,
                color: ThemeColorsUtil.textColorPrimary,
              ),
              IconButton(
                icon: Icon(
                  Icons.equalizer,
                  color: ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () => _showEqualizerDialog(context),
                tooltip: 'Equalizer',
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  color: isRepeating ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: onRepeatToggle,
                tooltip: 'Repeat',
              ),
            ],
          ),

          // Current song info
          if (currentSong != null) ...[
            const SizedBox(height: 16),
            Text(
              '${currentSong?.title ?? ''} - ${currentSong?.artist ?? ''}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeColorsUtil.textColorPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showEqualizerDialog(BuildContext context) {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const EqualizerDialog(
        initialBands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        initialEnabled: false,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
