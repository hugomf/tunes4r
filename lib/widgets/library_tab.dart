import 'dart:async';

import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/playback_manager.dart';
import '../utils/theme_colors.dart';

class LibraryTab extends StatefulWidget {
  final List<Song> library;
  final List<Song> favorites;
  final Function(Song song, [String? showSnackbarMessage]) onPlayNext;
  final Function(Song) onPlaySong;
  final Function(Song) onToggleFavorite;
  final VoidCallback onPickFiles;
  final VoidCallback onClearLibrary;

  const LibraryTab({
    super.key,
    required this.library,
    required this.favorites,
    required this.onPlaySong,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onPickFiles,
    required this.onClearLibrary,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final Set<Song> _selectedSongs = {};

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return widget.library.isEmpty
        ? Center(
            child: Text(
              '📁 Add some music to get started!\nClick "Add Music" above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeColorsUtil.textColorSecondary,
                fontSize: 16,
              ),
            ),
          )
        : ListView.builder(
            itemCount: widget.library.length,
            itemBuilder: (context, index) {
              final song = widget.library[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ThemeColorsUtil.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: song.albumArt != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              song.albumArt!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.music_note,
                                  size: 20,
                                  color: ThemeColorsUtil.primaryColor,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            size: 20,
                            color: ThemeColorsUtil.primaryColor,
                          ),
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.favorites.contains(song)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.favorites.contains(song)
                              ? ThemeColorsUtil.error
                              : ThemeColorsUtil.textColorSecondary,
                          size: 20,
                        ),
                        onPressed: () => widget.onToggleFavorite(song),
                        tooltip: 'Toggle Favorite',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow,
                          color: ThemeColorsUtil.secondary,
                          size: 20,
                        ),
                        onPressed: () => widget.onPlaySong(song),
                        tooltip: 'Play Song',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          color: ThemeColorsUtil.primaryColor,
                          size: 20,
                        ),
                        onPressed: () => widget.onPlayNext(song),
                        tooltip: 'Play Next',
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: ThemeColorsUtil.textColorSecondary,
                          size: 20,
                        ),
                        tooltip: 'More Options',
                        onSelected: (String value) {
                          switch (value) {
                            case 'queue':
                              widget.onPlayNext(song, 'Added to queue');
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'queue',
                            child: Row(
                              children: [
                                Icon(Icons.queue_music, size: 18),
                                const SizedBox(width: 8),
                                Text('Add to Queue'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // Need to keep this for now - would get this from parent in refactored version
  PlaybackManager? _playbackManager;

  // This method would be replaced with a proper callback from parent widget
  void _playSong(Song song) {
    if (_playbackManager != null) {
      _playbackManager!.playSong(song);
    }
  }

  void _addToQueue(Song song) {
    if (_playbackManager != null) {
      _playbackManager!.addToQueue(song);
    }
  }
}
