import 'package:flutter/material.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/playlist/models/playlist.dart';
import 'package:tunes4r/playlist/widgets/playlist_state.dart';

class PlaylistWidget extends StatefulWidget {
  final PlaylistState playlistState;
  final List<Song> library;
  final Function(Song song) addToPlaylist;
  final Function(Song song, bool showSnackbar) addToPlayNext;
  final Function(Song song) playSong;
  final Function(List<Song> songs, int startIndex) playFromIndex;
  final Function(String message) showSnackBar;
  final Song? currentSong;

  const PlaylistWidget({
    super.key,
    required this.playlistState,
    required this.library,
    required this.addToPlaylist,
    required this.addToPlayNext,
    required this.playSong,
    required this.playFromIndex,
    required this.showSnackBar,
    required this.currentSong,
  });

  @override
  State<PlaylistWidget> createState() => _PlaylistWidgetState();
}

class _PlaylistWidgetState extends State<PlaylistWidget> {
  Set<Song> _availableSongs = {};
  Set<Song> _selectedSongs = {};

  @override
  void initState() {
    super.initState();
    _updateAvailableSongs();
  }

  @override
  void didUpdateWidget(PlaylistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the playlist or library actually changed
    if (oldWidget.playlistState.playlist != widget.playlistState.playlist ||
        oldWidget.library != widget.library) {
      _updateAvailableSongs();
    }
  }

  /// Updates the list of songs available for selection
  /// Filters out songs already in the current playlist
  void _updateAvailableSongs() {
    final currentPlaylistPaths = widget.playlistState.playlist
        .map((s) => s.path)
        .toSet();
    
    final newAvailableSongs = widget.library
        .where((song) => !currentPlaylistPaths.contains(song.path))
        .toSet();

    // Clear invalid selections (songs no longer available)
    // but keep valid ones to preserve user intent
    if (mounted) {
      setState(() {
        _selectedSongs = _selectedSongs.intersection(newAvailableSongs);
        _availableSongs = newAvailableSongs;
      });
    }
  }

  /// Shows dialog for selecting multiple songs to add to playlist
  Future<void> _showSongSelectionDialog() async {
    if (_availableSongs.isEmpty) {
      widget.showSnackBar('All songs from your library are already in this playlist');
      return;
    }

    final result = await showDialog<Set<Song>?>(
      context: context,
      builder: (context) => _SongSelectionDialog(
        availableSongs: _availableSongs,
        initialSelection: _selectedSongs,
      ),
    );

    // Only update parent state when dialog returns with a selection
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _selectedSongs = result;
      });
      await _addSelectedSongsToPlaylist();
    }
  }

  /// Adds selected songs to the current playlist
  /// Handles both direct playlist editing and playlist management views
  Future<void> _addSelectedSongsToPlaylist() async {
    final currentPlaylist = widget.playlistState.currentPlaylist;
    
    if (currentPlaylist == null) {
      widget.showSnackBar('❌ No playlist selected');
      return;
    }

    // Show loading indicator for bulk operations
    if (_selectedSongs.length > 10) {
      widget.showSnackBar('Adding ${_selectedSongs.length} songs...');
    }

    // Don't modify the playlist directly - let the state management handle it
    final songsToAdd = _selectedSongs.toList();
    int successCount = 0;
    int duplicateCount = 0;
    final errors = <String>[];

    try {
      for (final song in songsToAdd) {
        try {
          // Attempt to add song to database
          await widget.playlistState.addSongToPlaylist(
            currentPlaylist,
            song,
            showSnackbar: false,
          );
          successCount++;
        } catch (e) {
          final errorMsg = e.toString().toLowerCase();
          // Check if error is due to duplicate
          if (errorMsg.contains('already') || 
              errorMsg.contains('duplicate') || 
              errorMsg.contains('exists')) {
            duplicateCount++;
          } else {
            // Real error - collect it
            errors.add('${song.title}: ${e.toString()}');
          }
        }
      }

      // Clear selection after operation completes
      if (mounted) {
        setState(() {
          _selectedSongs.clear();
        });
      }

      // Show comprehensive feedback
      _showAddResultFeedback(successCount, duplicateCount, errors);

    } catch (e) {
      widget.showSnackBar('❌ Failed to add songs: $e');
    }
  }

  /// Displays appropriate feedback based on add operation results
  void _showAddResultFeedback(int successCount, int duplicateCount, List<String> errors) {
    if (successCount == 0 && duplicateCount == 0 && errors.isEmpty) {
      widget.showSnackBar('No songs were added');
      return;
    }

    final messages = <String>[];

    if (successCount > 0) {
      messages.add('✅ $successCount song${successCount == 1 ? '' : 's'} added');
    }

    if (duplicateCount > 0) {
      messages.add('$duplicateCount already in playlist');
    }

    if (errors.isNotEmpty) {
      messages.add('${errors.length} failed');
      // Log detailed errors for debugging
      debugPrint('Playlist add errors: ${errors.join(', ')}');
    }

    widget.showSnackBar(messages.join(' • '));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.playlistState,
      builder: (context, child) {
        if (widget.playlistState.isManagingPlaylists) {
          return _buildPlaylistManagementView();
        } else {
          return _buildPlaylistEditingView();
        }
      },
    );
  }

  /// Builds the playlist management view (list of all playlists)
  Widget _buildPlaylistManagementView() {
    return Scaffold(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
        elevation: 0,
        actions: [
          _buildCreatePlaylistButton(),
          _buildImportPlaylistButton(),
        ],
      ),
      body: Container(
        color: ThemeColorsUtil.scaffoldBackgroundColor,
        child: widget.playlistState.userPlaylists.isEmpty
            ? _buildEmptyPlaylistsView()
            : _buildPlaylistsList(),
      ),
    );
  }

  Widget _buildCreatePlaylistButton() {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Icon(
        Icons.add,
        color: ThemeColorsUtil.primaryColor,
        size: 24,
      ),
      onPressed: () => _showCreatePlaylistDialog(),
      tooltip: 'New Playlist',
    );
  }

  Widget _buildImportPlaylistButton() {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Icon(
        Icons.file_upload,
        color: ThemeColorsUtil.secondary,
        size: 24,
      ),
      onPressed: () => widget.playlistState.showPlaylistImportDialog(context, []),
      tooltip: 'Import',
    );
  }

  Widget _buildEmptyPlaylistsView() {
    return Center(
      child: Text(
        '🎵 No playlists yet.\nCreate your first playlist above!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ThemeColorsUtil.textColorSecondary,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildPlaylistsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.playlistState.userPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = widget.playlistState.userPlaylists[index];
        final isActive = widget.playlistState.currentPlaylist == playlist;
        
        return _PlaylistListItem(
          playlist: playlist,
          isActive: isActive,
          onTap: () => _loadPlaylist(playlist),
          onEdit: () => _loadPlaylist(playlist),
          onDelete: () => widget.playlistState.deletePlaylist(playlist, context),
        );
      },
    );
  }

  Future<void> _loadPlaylist(Playlist playlist) async {
    await widget.playlistState.loadPlaylist(playlist);
    widget.playlistState.setManagingPlaylists(false);
  }

  Future<void> _showCreatePlaylistDialog() async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          title: Text(
            'Create Playlist',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter playlist name',
              hintStyle: TextStyle(color: ThemeColorsUtil.textColorSecondary),
            ),
            autofocus: true,
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(name);
                }
              },
              child: Text(
                'Create',
                style: TextStyle(color: ThemeColorsUtil.primaryColor),
              ),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        await widget.playlistState.createPlaylist(result);
      }
    } finally {
      controller.dispose();
    }
  }

  /// Builds the individual playlist editing view
  Widget _buildPlaylistEditingView() {
    return Scaffold(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      appBar: _buildEditingAppBar(),
      body: Container(
        color: ThemeColorsUtil.scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildPlaylistHeader(),
            Expanded(child: _buildPlaylistContent()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildEditingAppBar() {
    return AppBar(
      backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: ThemeColorsUtil.textColorPrimary),
        onPressed: () => widget.playlistState.setManagingPlaylists(true),
        tooltip: 'Back to Playlists',
      ),
      title: Text(
        '${widget.playlistState.playlist.length} ${widget.playlistState.playlist.length == 1 ? 'song' : 'songs'}',
        style: TextStyle(
          fontSize: 14,
          color: ThemeColorsUtil.textColorSecondary,
        ),
      ),
      actions: [
        SizedBox(
          width: 130,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildImportButton(),
              _buildAddSongsButton(),
              _buildMoreOptionsMenu(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: Icon(
        Icons.add_circle_outline,
        color: ThemeColorsUtil.primaryColor,
        size: 18,
      ),
      onPressed: () => widget.playlistState.showPlaylistImportDialog(context, []),
      tooltip: 'Import Playlist',
    );
  }

  Widget _buildAddSongsButton() {
    return Semantics(
      label: 'Add songs to playlist',
      button: true,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: Icon(
          Icons.playlist_add,
          color: ThemeColorsUtil.secondary,
          size: 18,
        ),
        onPressed: _showSongSelectionDialog,
        tooltip: 'Add Songs',
      ),
    );
  }

  Widget _buildMoreOptionsMenu() {
    return SizedBox(
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
        onSelected: _handleMoreOptionsSelection,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.clear_all, size: 16),
                SizedBox(width: 6),
                Text('Clear Playlist'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 16),
                SizedBox(width: 6),
                Text('Delete Playlist'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMoreOptionsSelection(String value) async {
    switch (value) {
      case 'clear':
        await _handleClearPlaylist();
        break;
      case 'delete':
        await _handleDeletePlaylist();
        break;
    }
  }

  Future<void> _handleClearPlaylist() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Clear Playlist',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: Text(
          'Are you sure you want to remove all songs from this playlist? This action cannot be undone.',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: ThemeColorsUtil.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.playlistState.clearCurrentPlaylist();
    }
  }

  Future<void> _handleDeletePlaylist() async {
    final currentPlaylist = widget.playlistState.currentPlaylist;
    if (currentPlaylist != null) {
      await widget.playlistState.deletePlaylist(currentPlaylist, context);
    }
  }

  Widget _buildPlaylistHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: ThemeColorsUtil.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.playlistState.currentPlaylist?.name ?? 'Current Playlist',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeColorsUtil.textColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistContent() {
    if (widget.playlistState.playlist.isEmpty) {
      return _buildEmptyPlaylistView();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.playlistState.playlist.length,
      onReorder: (oldIndex, newIndex) {
        widget.playlistState.reorderPlaylist(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final song = widget.playlistState.playlist[index];
        final isCurrent = widget.currentSong?.path == song.path;
        
        return _PlaylistSongItem(
          key: ValueKey(song.path),
          song: song,
          isCurrent: isCurrent,
          onDoubleTap: () => widget.playFromIndex(
            widget.playlistState.playlist,
            index,
          ),
          onRemove: () => widget.playlistState.removeFromPlaylist(
            song,
            currentSong: widget.currentSong,
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaylistView() {
    return Center(
      child: Text(
        '🎵 This playlist is empty.\nAdd songs from the Library.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ThemeColorsUtil.textColorSecondary,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Dialog for selecting songs to add to playlist
class _SongSelectionDialog extends StatefulWidget {
  final Set<Song> availableSongs;
  final Set<Song> initialSelection;

  const _SongSelectionDialog({
    required this.availableSongs,
    required this.initialSelection,
  });

  @override
  State<_SongSelectionDialog> createState() => _SongSelectionDialogState();
}

class _SongSelectionDialogState extends State<_SongSelectionDialog> {
  late Set<Song> _localSelection;
  late List<Song> _sortedSongs;

  @override
  void initState() {
    super.initState();
    // Make a copy of initial selection to work with locally
    _localSelection = Set.from(widget.initialSelection);
    // Cache sorted list to avoid sorting on every build
    _sortedSongs = widget.availableSongs.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  void _toggleSelection(Song song) {
    setState(() {
      if (_localSelection.contains(song)) {
        _localSelection.remove(song);
      } else {
        _localSelection.add(song);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _localSelection = widget.availableSongs.toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _localSelection.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ThemeColorsUtil.surfaceColor,
      title: Text(
        'Add Songs to Playlist',
        style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            _buildSelectionHeader(),
            const Divider(),
            Expanded(child: _buildSongList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          ),
        ),
        TextButton(
          onPressed: _localSelection.isNotEmpty
              ? () => Navigator.of(context).pop(_localSelection)
              : null,
          child: Text(
            'Add (${_localSelection.length})',
            style: TextStyle(
              color: _localSelection.isNotEmpty
                  ? ThemeColorsUtil.primaryColor
                  : ThemeColorsUtil.textColorSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      children: [
        Text(
          '${_localSelection.length} selected',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        const Spacer(),
        TextButton(
          onPressed: _selectAll,
          child: Text(
            'Select All',
            style: TextStyle(color: ThemeColorsUtil.primaryColor),
          ),
        ),
        TextButton(
          onPressed: _deselectAll,
          child: Text(
            'Deselect All',
            style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildSongList() {
    return ListView.builder(
      itemCount: _sortedSongs.length,
      itemBuilder: (context, index) {
        final song = _sortedSongs[index];
        final isSelected = _localSelection.contains(song);

        return _SongSelectionItem(
          song: song,
          isSelected: isSelected,
          onToggle: () => _toggleSelection(song),
        );
      },
    );
  }
}

/// Individual song item in selection dialog
class _SongSelectionItem extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final VoidCallback onToggle;

  const _SongSelectionItem({
    required this.song,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAlbumArt(),
            const SizedBox(width: 12),
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
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

  Widget _buildAlbumArt() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: song.albumArt != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(song.albumArt!, fit: BoxFit.cover),
            )
          : Icon(
              Icons.music_note,
              size: 20,
              color: ThemeColorsUtil.primaryColor,
            ),
    );
  }
}

/// Individual playlist item in management view
class _PlaylistListItem extends StatelessWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistListItem({
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
            : ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? ThemeColorsUtil.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      color: isActive
                          ? ThemeColorsUtil.primaryColor
                          : ThemeColorsUtil.textColorSecondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive
                                  ? ThemeColorsUtil.primaryColor
                                  : ThemeColorsUtil.textColorPrimary,
                            ),
                          ),
                          Text(
                            '${playlist.songs.length} ${playlist.songs.length == 1 ? 'song' : 'songs'}',
                            style: TextStyle(
                              color: isActive
                                  ? ThemeColorsUtil.primaryColor.withOpacity(0.8)
                                  : ThemeColorsUtil.textColorSecondary,
                            ),
                          ),
                          if (isActive)
                            Text(
                              'Currently loaded',
                              style: TextStyle(
                                fontSize: 12,
                                color: ThemeColorsUtil.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Playlist'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Playlist'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.more_vert,
                color: ThemeColorsUtil.textColorSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual song item in playlist editing view
class _PlaylistSongItem extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onDoubleTap;
  final VoidCallback onRemove;

  const _PlaylistSongItem({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onDoubleTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isCurrent
              ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: _buildLeadingWidget(),
          title: Text(
            song.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? ThemeColorsUtil.primaryColor
                  : ThemeColorsUtil.textColorPrimary,
            ),
          ),
          subtitle: Text(
            song.artist,
            style: TextStyle(
              color: isCurrent
                  ? ThemeColorsUtil.primaryColor.withOpacity(0.8)
                  : ThemeColorsUtil.textColorSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrent) ...[
                Icon(
                  Icons.volume_up,
                  color: ThemeColorsUtil.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: ThemeColorsUtil.error,
                ),
                onPressed: onRemove,
                tooltip: 'Remove from playlist',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget() {
    return Container(
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
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  if (isCurrent)
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeColorsUtil.primaryColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.volume_up,
                          color: ThemeColorsUtil.surfaceColor,
                          size: 20,
                        ),
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
    );
  }
}