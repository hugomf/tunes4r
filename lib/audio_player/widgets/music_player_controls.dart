import 'package:flutter/material.dart';
import 'package:tunes4r/services/audio_equalizer_service.dart';
import 'package:tunes4r/services/playback_manager.dart' show AudioPlayer, PlaybackManager;
import 'package:tunes4r/utils/theme_colors.dart';
import 'equalizer_dialog.dart';

class MusicPlayerControls extends StatefulWidget {
  final PlaybackManager playbackManager;
  final VoidCallback onSavePreferences;
  final Function()? onShowEqualizerDialog;
  final VoidCallback? onTogglePlayPause;

  const MusicPlayerControls({
    super.key,
    required this.playbackManager,
    required this.onSavePreferences,
    this.onShowEqualizerDialog,
    this.onTogglePlayPause,
  });

  @override
  State<MusicPlayerControls> createState() => _MusicPlayerControlsState();
}

class _MusicPlayerControlsState extends State<MusicPlayerControls> {
  // Equalizer bands synced with service through AudioPlayer
  List<double> get _eqBands => (widget.playbackManager as AudioPlayer).equalizerService.bands;
  bool get _isEqualizerEnabled => (widget.playbackManager as AudioPlayer).equalizerService.isEnabled;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showEqualizerDialog() {
    final equalizerService = (widget.playbackManager as AudioPlayer).equalizerService;
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EqualizerDialog(
        initialBands: _eqBands,
        initialEnabled: _isEqualizerEnabled,
        equalizerService: equalizerService,
      ),
    ).then((result) async {
      if (result != null) {
        final bands = List<double>.from(result['bands']);
        final enabled = result['enabled'] as bool;

        await equalizerService.setEnabled(enabled);
        if (enabled && bands.isNotEmpty) {
          await equalizerService.setBands(bands);
        }

        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
                _formatDuration(widget.playbackManager.position),
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
              Expanded(
                child: Slider(
                  value: widget.playbackManager.position.inSeconds.toDouble(),
                  max: widget.playbackManager.duration.inSeconds > 0
                       ? widget.playbackManager.duration.inSeconds.toDouble()
                       : 1.0,
                  activeColor: ThemeColorsUtil.seekBarActiveColor,
                  inactiveColor: ThemeColorsUtil.seekBarInactiveColor,
                  onChanged: widget.playbackManager.duration.inSeconds > 0
                      ? (value) async {
                          widget.playbackManager.seekTo(Duration(seconds: value.toInt()));
                        }
                      : null,
                ),
              ),
              Text(
                _formatDuration(widget.playbackManager.duration),
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
                        color: widget.playbackManager.isShuffling ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        widget.playbackManager.setShuffling(!widget.playbackManager.isShuffling);
                        widget.onSavePreferences();
                      },
                      tooltip: 'Shuffle',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.skip_previous, size: 20),
                      onPressed: widget.playbackManager.playPrevious,
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
                          widget.playbackManager.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                        ),
                        onPressed: widget.onTogglePlayPause ?? widget.playbackManager.togglePlayPause,
                        tooltip: 'Play/Pause',
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.skip_next, size: 20),
                      onPressed: widget.playbackManager.playNext,
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
                      onPressed: _showEqualizerDialog,
                      tooltip: 'Equalizer',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.repeat,
                        color: widget.playbackManager.isRepeating ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        widget.playbackManager.setRepeating(!widget.playbackManager.isRepeating);
                        widget.onSavePreferences();
                      },
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
                  color: widget.playbackManager.isShuffling ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () {
                  widget.playbackManager.setShuffling(!widget.playbackManager.isShuffling);
                  widget.onSavePreferences();
                },
                tooltip: 'Shuffle',
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: widget.playbackManager.playPrevious,
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
                    widget.playbackManager.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  onPressed: widget.onTogglePlayPause ?? widget.playbackManager.togglePlayPause,
                  tooltip: 'Play/Pause',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: widget.playbackManager.playNext,
                color: ThemeColorsUtil.textColorPrimary,
              ),
              IconButton(
                icon: Icon(
                  Icons.equalizer,
                  color: ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: _showEqualizerDialog,
                tooltip: 'Equalizer',
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  color: widget.playbackManager.isRepeating ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () {
                  widget.playbackManager.setRepeating(!widget.playbackManager.isRepeating);
                  widget.onSavePreferences();
                },
                tooltip: 'Repeat',
              ),
            ],
          ),

          // Current song info
          if (widget.playbackManager.currentSong != null) ...[
            const SizedBox(height: 16),
            Text(
              '${widget.playbackManager.currentSong?.title ?? ''} - ${widget.playbackManager.currentSong?.artist ?? ''}',
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
}
