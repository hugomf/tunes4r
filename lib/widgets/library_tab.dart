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
  final Function(Song) onRemoveSong;
  final VoidCallback onPickFiles;
  final VoidCallback onClearLibrary;
  final Function(Set<Song>) onSongsSelected; // Callback when songs are selected for playlist
  final Song? currentSong; // Currently playing song for visual feedback

  const LibraryTab({
    super.key,
    required this.library,
    required this.favorites,
    required this.onPlaySong,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onRemoveSong,
    required this.onPickFiles,
    required this.onClearLibrary,
    required this.onSongsSelected,
    required this.currentSong,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final Set<Song> _selectedSongs = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // Show app bar in selection mode
    if (_isSelectionMode) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: ThemeColorsUtil.textColorPrimary,
            ),
            onPressed: _cancelSelection,
            tooltip: 'Cancel Selection',
          ),
          title: Text(
            '${_selectedSongs.length} songs selected',
            style: TextStyle(
              color: ThemeColorsUtil.textColorPrimary,
              fontSize: 16,
            ),
          ),
          actions: [
            if (_selectedSongs.isNotEmpty) ...[
              IconButton(
                icon: Icon(
                  Icons.playlist_add,
                  color: ThemeColorsUtil.primaryColor,
                ),
                onPressed: () {
                  print('🔥 BUTTON PRESSED: About to call _addSelectedSongsToPlaylist');
                  _addSelectedSongsToPlaylist();
                },
                tooltip: 'Add to Playlist',
              ),
            ],
          ],
        ),
        body: ListView.builder(
          itemCount: widget.library.length,
          itemBuilder: _buildSelectionItem,
        ),
      );
    }

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
              final bool isCurrent = widget.currentSong != null && song.path == widget.currentSong!.path;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCurrent
                    ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
                    : ThemeColorsUtil.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                  onLongPress: () => _startSelection(song),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                        ? ThemeColorsUtil.primaryColor.withOpacity(0.2)
                        : ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent
                        ? Border.all(color: ThemeColorsUtil.primaryColor, width: 2)
                        : null,
                    ),
                    child: song.albumArt != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                Image.memory(
                                  song.albumArt!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      size: 20,
                                      color: isCurrent
                                        ? ThemeColorsUtil.surfaceColor
                                        : ThemeColorsUtil.primaryColor,
                                    );
                                  },
                                ),
                                if (isCurrent)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: ThemeColorsUtil.primaryColor.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.volume_up,
                                      color: ThemeColorsUtil.surfaceColor,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            size: 20,
                            color: isCurrent
                              ? ThemeColorsUtil.surfaceColor
                              : ThemeColorsUtil.primaryColor,
                          ),
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: isCurrent
                        ? ThemeColorsUtil.primaryColor
                        : ThemeColorsUtil.textColorPrimary,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: TextStyle(
                      color: isCurrent
                        ? ThemeColorsUtil.primaryColor.withOpacity(0.8)
                        : ThemeColorsUtil.textColorSecondary,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                  trailing: SizedBox(
                    width: 160, // Increased width to accommodate volume icon + proper spacing
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isCurrent) ...[
                          Icon(
                            Icons.volume_up,
                            color: ThemeColorsUtil.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              widget.favorites.contains(song)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: widget.favorites.contains(song)
                                  ? ThemeColorsUtil.error
                                  : ThemeColorsUtil.textColorSecondary,
                              size: 18,
                            ),
                            onPressed: () => widget.onToggleFavorite(song),
                            tooltip: 'Toggle Favorite',
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.play_arrow,
                              color: ThemeColorsUtil.secondary,
                              size: 18,
                            ),
                            onPressed: () => widget.onPlaySong(song),
                            tooltip: 'Play Song',
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.skip_next,
                              color: ThemeColorsUtil.primaryColor,
                              size: 18,
                            ),
                            onPressed: () => widget.onPlayNext(song),
                            tooltip: 'Play Next',
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              color: ThemeColorsUtil.textColorSecondary,
                              size: 18,
                            ),
                            tooltip: 'More Options',
                            onSelected: (String value) {
                              switch (value) {
                                case 'queue':
                                  widget.onPlayNext(song, 'Added to queue');
                                  break;
                                case 'remove':
                                  _showRemoveDialog(song);
                                  break;
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'queue',
                                child: Row(
                                  children: [
                                    Icon(Icons.queue_music, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Add to Queue'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: ThemeColorsUtil.error),
                                    const SizedBox(width: 6),
                                    Text('Remove from Library', style: TextStyle(color: ThemeColorsUtil.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  void _startSelection(Song song) {
    setState(() {
      _isSelectionMode = true;
      _selectedSongs.add(song);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedSongs.clear();
    });
  }

  void _addSelectedSongsToPlaylist() {
    print('🔍 LibraryTab _addSelectedSongsToPlaylist: Selected ${_selectedSongs.length} songs, calling onSongsSelected');
    if (_selectedSongs.isNotEmpty) {
      widget.onSongsSelected(_selectedSongs);
      // Don't cancel selection immediately - let the async operation complete first
    } else {
      print('❌ LibraryTab _addSelectedSongsToPlaylist: No songs selected');
    }
  }

  void _toggleSongSelection(Song song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
        if (_selectedSongs.isEmpty) {
          _isSelectionMode = false; // Auto-exit if no songs selected
        }
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  Widget _buildSelectionItem(BuildContext context, int index) {
    final song = widget.library[index];
    final isSelected = _selectedSongs.contains(song);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
            : ThemeColorsUtil.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? ThemeColorsUtil.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: () => _toggleSongSelection(song),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
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
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) => _toggleSongSelection(song),
              activeColor: ThemeColorsUtil.primaryColor,
              shape: const CircleBorder(),
            ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: ThemeColorsUtil.textColorPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
      ),
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

  void _showRemoveDialog(Song song) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Remove Song',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: SingleChildScrollView(
          child: Text(
            // Shorten or truncate long titles to prevent overflow
            'Are you sure you want to remove "${song.title.length > 30 ? "${song.title.substring(0, 27)}..." : song.title}" from your library?\n\n'
            'This action cannot be undone.',
            style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.textColorSecondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              widget.onRemoveSong(song);
            },
            style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
