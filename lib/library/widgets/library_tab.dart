import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/library/library.dart';
import 'package:tunes4r/library/library_commands.dart';

class LibraryTab extends StatefulWidget {
  final Library libraryContext;
  final PlaybackManager audioPlayer;
  final Function(Set<Song>)
  onSongsSelected; // Callback when songs are selected for playlist

  const LibraryTab({
    super.key,
    required this.libraryContext,
    required this.audioPlayer,
    required this.onSongsSelected,
  });

  // UI layer owns its actions completely - returns fully styled widgets
  static List<Widget> buildActions(BuildContext context, GlobalKey key) {
    return [
      IconButton(
        icon: Icon(
          Icons.add_circle_outline,
          color: ThemeColorsUtil.primaryColor,
        ),
        onPressed: () => (key.currentState as dynamic)?.triggerImport(),
        tooltip: 'Add Files',
      ),
      IconButton(
        icon: Icon(Icons.clear_all, color: ThemeColorsUtil.primaryColor),
        onPressed: () => (key.currentState as dynamic)?.triggerClear(),
        tooltip: 'Clear Library',
      ),
    ];
  }

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late StreamSubscription _stateSubscription;
  late StreamSubscription _eventSubscription;

  bool _isSelectionMode = false;
  Set<Song> _selectedSongs = {};
  List<Song> _library = [];
  List<Song> _favorites = [];

  @override
  void initState() {
    super.initState();

    // Initial state snapshot (for immediate UI)
    final initialState = widget.libraryContext.currentState;
    _library = initialState.displaySongs;
    _favorites = initialState.favorites;
    _isSelectionMode = initialState.isSelectingMode;
    _selectedSongs = initialState.selectedSongs;

    // Subscribe to reactive state updates
    _stateSubscription = widget.libraryContext.state.listen((state) {
      if (mounted) {
        setState(() {
          _library = state.displaySongs;
          _favorites = state.favorites;
          _isSelectionMode = state.isSelectingMode;
          _selectedSongs = state.selectedSongs;
        });
      }
    });

    // Subscribe to events for user feedback
    _eventSubscription = widget.libraryContext.events.listen((event) {
      if (!mounted) return;

      switch (event) {
        case SongSavedEvent songEvent: // Single song import
          _showSnackbar('Added "${songEvent.song.title}" to library');
          break;
        case SongRemovedEvent songEvent:
          _showSnackbar('Removed "${songEvent.song.title}" from library');
          break;
        case FilesImportedEvent filesEvent: // Bulk import
          _showSnackbar('Added ${filesEvent.importedCount} songs to library');
          break;
        case FavoriteToggledEvent toggleEvent:
          final action = toggleEvent.isFavorite ? 'added to' : 'removed from';
          _showSnackbar('"${toggleEvent.song.title}" $action favorites');
          break;
        case LibraryErrorEvent errorEvent:
          _showSnackbar(errorEvent.userMessage, isError: true);
          break;
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    _eventSubscription.cancel();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        backgroundColor: isError
            ? ThemeColorsUtil.error
            : ThemeColorsUtil.surfaceColor,
      ),
    );
  }

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
            icon: Icon(Icons.close, color: ThemeColorsUtil.textColorPrimary),
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
            // Select All button
            TextButton(
              onPressed: _selectAllSongs,
              child: Text(
                'Select All',
                style: TextStyle(
                  color: ThemeColorsUtil.primaryColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Deselect All button
            if (_selectedSongs.isNotEmpty) ...[
              TextButton(
                onPressed: _deselectAllSongs,
                child: Text(
                  'Deselect All',
                  style: TextStyle(
                    color: ThemeColorsUtil.textColorSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  Icons.playlist_add,
                  color: ThemeColorsUtil.primaryColor,
                ),
                onPressed: () => _addSelectedSongsToPlaylist(),
                tooltip: 'Add to Playlist',
              ),
            ],
          ],
        ),
        body: ListView.builder(
          itemCount: _library.length,
          itemBuilder: (context, index) => _buildSelectionItem(context, index),
        ),
      );
    }

    return _library.isEmpty
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
            itemCount: _library.length,
            itemBuilder: (context, index) {
              final song = _library[index];
              final bool isCurrent =
                  widget.audioPlayer.currentSong != null &&
                  song.path == widget.audioPlayer.currentSong!.path;
              return GestureDetector(
                onDoubleTap: () =>
                    _playSong(song), // Double tap to play immediately
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
                        : ThemeColorsUtil.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(
                      left: 16,
                      right: 8,
                      top: 8,
                      bottom: 8,
                    ),
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
                            ? Border.all(
                                color: ThemeColorsUtil.primaryColor,
                                width: 2,
                              )
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
                                        color: ThemeColorsUtil.primaryColor
                                            .withOpacity(0.7),
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
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                      width:
                          160, // Increased width to accommodate volume icon + proper spacing
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
                                _favorites.contains(song)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _favorites.contains(song)
                                    ? ThemeColorsUtil.error
                                    : ThemeColorsUtil.textColorSecondary,
                                size: 18,
                              ),
                              onPressed: () => _toggleFavorite(song),
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
                              onPressed: () => _playSong(song),
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
                              onPressed: () => _addToPlayNext(song),
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
                                    _addToQueue(song);
                                    break;
                                  case 'remove':
                                    _showRemoveDialog(song);
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
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
                                          Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: ThemeColorsUtil.error,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Remove from Library',
                                            style: TextStyle(
                                              color: ThemeColorsUtil.error,
                                            ),
                                          ),
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
                ),
              );
            },
          );
  }

  // Selection mode methods (now delegated to bounded context)
  void _startSelection(Song song) {
    widget.libraryContext.startSelection(song);
  }

  void _cancelSelection() {
    widget.libraryContext.finishSelection();
  }

  void _addSelectedSongsToPlaylist() {
    final selectedSongs = widget.libraryContext.finishSelection();
    if (selectedSongs.isNotEmpty) {
      widget.onSongsSelected(selectedSongs);
    }
  }

  void _selectAllSongs() {
    widget.libraryContext.selectAllSongs();
  }

  void _deselectAllSongs() {
    widget.libraryContext.deselectAllSongs();
  }

  /// Pick audio files from UI (shows dialogs, file picker, etc.)
  /// UI layer concern - domain layer gets pure file paths
  Future<List<String>?> _pickAudioFilesFromUI() async {
    try {
      // Step 1: Check permissions
      final hasPermission = await widget.libraryContext.checkPermissions();
      if (!hasPermission) {
        await _showPermissionRequiredDialog();
        return null;
      }

      // Step 2: Let user choose between files or folder
      final importChoice = await _showImportChoiceDialog();
      if (importChoice == null) return null;

      // Step 3: Pick files based on user choice
      if (importChoice == 'files') {
        return await _pickIndividualFilesFromUI();
      } else {
        return await _pickFolderFromUI();
      }
    } catch (e) {
      // Show error dialog
      await _showImportErrorDialog('Error selecting files: $e');
      return null;
    }
  }

  /// Show dialog for user to choose between files or folder
  Future<String?> _showImportChoiceDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Select Music',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: Text(
          'Would you like to select individual files or a folder?',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('files'),
            style: TextButton.styleFrom(
              foregroundColor: ThemeColorsUtil.primaryColor,
            ),
            child: const Text('Files'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('folder'),
            style: TextButton.styleFrom(
              foregroundColor: ThemeColorsUtil.secondary,
            ),
            child: const Text('Folder'),
          ),
        ],
      ),
    );
  }

  /// Pick individual audio files using FilePicker
  Future<List<String>> _pickIndividualFilesFromUI() async {
    // Use file_picker package which handles UI
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      return result.files
          .map((f) => f.path)
          .where((path) => path != null)
          .cast<String>()
          .toList();
    }

    return [];
  }

  /// Pick a folder using FilePicker
  Future<List<String>> _pickFolderFromUI() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();

    if (folderPath != null) {
      // Use domain service for folder scanning
      return await widget.libraryContext.scanDirectoryForAudio(folderPath);
    }

    return [];
  }

  /// Show permission required dialog
  Future<void> _showPermissionRequiredDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Permission Required',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: Text(
          'Storage access is required to import music files.',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show import error dialog
  Future<void> _showImportErrorDialog(String error) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Import Error',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: Text(
          error,
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Library operations - UI layer handles presentation, domain handles business logic
  Future<void> _pickFiles() async {
    final filePaths = await _pickAudioFilesFromUI();
    if (filePaths != null && filePaths.isNotEmpty) {
      await _importMusicFiles(filePaths);
    }
  }

  /// Handle the complete music import flow (UI concerns)
  Future<void> _importMusicFiles(List<String> filePaths) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeColorsUtil.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Importing ${filePaths.length} ${filePaths.length == 1 ? 'music file' : 'music files'}...',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    try {
      // Call domain logic to import files
      final importedCount = await widget.libraryContext.importMusicFiles(
        filePaths,
      );

      // Close the progress dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $importedCount ${importedCount == 1 ? 'song' : 'songs'} to library!',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
      }
    } catch (e) {
      // Close the progress dialog on error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error importing music: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Song song) async {
    await widget.libraryContext.toggleFavorite(song);
  }

  Future<void> _removeSong(Song song) async {
    await widget.libraryContext.removeSong(song);
  }

  Future<void> _clearLibrary() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Clear Library',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: Text(
          'Are you sure you want to delete all songs from your library?\n\nThis action cannot be undone.',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: ThemeColorsUtil.textColorPrimary,
            ),
            child: const Text('Clear Library'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await widget.libraryContext.clearLibrary();
        _showSnackbar('Library cleared successfully!');
      } catch (e) {
        _showSnackbar('Error clearing library: $e', isError: true);
      }
    }
  }

  // Audio player operations (delegate to PlaybackManager)
  void _playSong(Song song) {
    final context = _library.isNotEmpty ? _library : null;
    widget.audioPlayer.playSong(song, context: context);
  }

  void _addToQueue(Song song) {
    widget.audioPlayer.addToQueue(song);
  }

  void _addToPlayNext(Song song) {
    widget.audioPlayer.addToPlayNext(song);
  }

  Widget _buildSelectionItem(BuildContext context, int index) {
    final song = _library[index];
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
        onTap: () => widget.libraryContext.toggleSongSelection(song),
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
              onChanged: (bool? value) =>
                  widget.libraryContext.toggleSongSelection(song),
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
            style: TextButton.styleFrom(
              foregroundColor: ThemeColorsUtil.textColorSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              _removeSong(song);
            },
            style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Make methods public for AppBar access from main.dart
  /// This allows clean separation while enabling AppBar functionality

  /// Public playback methods - each UI context knows its own playlist
  void contextPlaySong(Song song) => _playSong(song);

  Future<void> contextTogglePlayPause() async =>
      await _togglePlayPauseInLibrary();

  void triggerImport() => _pickFiles();
  void triggerClear() => _clearLibrary();

  /// Toggle play/pause with library context (start playing if nothing is playing)
  Future<void> _togglePlayPauseInLibrary() async {
    if (widget.audioPlayer.currentSong != null) {
      // If there's a current song playing, just toggle
      widget.audioPlayer.togglePlayPause();
      return;
    }

    // If nothing is playing, start from the beginning of the library
    if (_library.isNotEmpty) {
      await widget.audioPlayer.startPlaylist(_library, startIndex: 0);
    }
  }
}
