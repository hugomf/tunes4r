import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/playlist/models/playlist.dart';
import 'package:tunes4r/playlist/models/playlist_import.dart';
import 'package:tunes4r/playlist/services/playlist_import_service.dart';
import 'package:tunes4r/playlist/services/playlist_repository.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class PlaylistCallbacks {
  final Function(Song song) addToPlaylist;
  final Function(Song song, bool showSnackbar) addToPlayNext;
  final Function(Song song) playSong;
  final Function(String name) showSnackBar;
  final Function() clearQueue;
  final Function(List<Song> songs) addSongsToQueue;

  PlaylistCallbacks({
    required this.addToPlaylist,
    required this.addToPlayNext,
    required this.playSong,
    required this.showSnackBar,
    required this.clearQueue,
    required this.addSongsToQueue,
  });
}

class PlaylistState extends ChangeNotifier {
  // State variables
  List<Song> _currentPlaylistSongs =
      []; // Current playing list (renamed for clarity)
  List<Playlist> _userPlaylists = [];
  Playlist? _currentPlaylist;
  bool _isManagingPlaylists =
      true; // true = show playlist list, false = show current playlist

  Database? _database;
  PlaylistRepository? _repository;
  PlaylistCallbacks? _callbacks;

  // Getters
  List<Song> get playlist => _currentPlaylistSongs;
  List<Playlist> get userPlaylists => _userPlaylists;
  Playlist? get currentPlaylist => _currentPlaylist;
  bool get isManagingPlaylists => _isManagingPlaylists;

  // Setters
  set playlist(List<Song> songs) {
    _currentPlaylistSongs = List.from(songs);
    notifyListeners();
  }

  set currentPlaylist(Playlist? playlist) {
    _currentPlaylist = playlist;
    notifyListeners();
  }

  set isManagingPlaylists(bool value) {
    _isManagingPlaylists = value;
    notifyListeners();
  }

  // Set database reference and initialize repository
  void setDatabase(Database? database) {
    _database = database;
    if (database != null) {
      _repository = PlaylistRepository();
      _repository!.setDatabase(database);
    }
  }

  // Set callbacks
  void setCallbacks(PlaylistCallbacks callbacks) {
    _callbacks = callbacks;
  }

  // Load user playlists from repository
  Future<void> loadUserPlaylists(List<Song> library) async {
    if (_repository == null) return;

    try {
      _userPlaylists = await _repository!.getAllPlaylists(library);
      notifyListeners();
    } catch (e) {
      print('Error loading user playlists: $e');
    }
  }

  // Load playlist legacy songs (for backward compatibility)
  Future<void> loadLegacyPlaylists(List<Song> library) async {
    if (_database == null) return;

    try {
      final playlistSongs = await _database!.query(
        'playlists',
        orderBy: 'position ASC',
      );

      _currentPlaylistSongs = playlistSongs.map((map) {
        return library.firstWhere(
          (song) => song.path == map['song_path'],
          orElse: () =>
              Song(title: 'Unknown', path: map['song_path'] as String),
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading legacy playlist: $e');
    }
  }

  Future<void> _savePlaylist() async {
    if (_database == null) return;
    try {
      await _database!.delete('playlists');
      for (int i = 0; i < _currentPlaylistSongs.length; i++) {
        await _database!.insert('playlists', {
          'song_path': _currentPlaylistSongs[i].path,
          'position': i,
        });
      }
    } catch (e) {
      print('Error saving playlist: $e');
    }
  }

  Future<void> createPlaylist(String name) async {
    if (_repository == null || name.trim().isEmpty || _callbacks == null)
      return;

    try {
      final newPlaylist = await _repository!.createPlaylist(
        name.trim(),
        PlaylistType.userCreated,
      );
      _userPlaylists.add(newPlaylist);
      notifyListeners();

      _callbacks!.showSnackBar('✅ Playlist "${name.trim()}" created!');
    } catch (e) {
      print('Error creating playlist: $e');
      _callbacks!.showSnackBar('❌ Failed to create playlist: $e');
    }
  }

Future<void> addSongToPlaylist(
  Playlist playlist,
  Song song, {
  bool showSnackbar = true,
}) async {
  if (_repository == null || playlist.id == null) return;

  try {
    debugPrint('🔍 addSongToPlaylist called for: ${song.title}');
    debugPrint('   Playlist: ${playlist.name} (ID: ${playlist.id})');
    
    // IMPORTANT: Check database state, not just memory
    // The in-memory state might be out of sync with database
    final existingInDb = await _database!.query(
      'playlist_songs',
      where: 'playlist_id = ? AND song_path = ?',
      whereArgs: [playlist.id, song.path],
    );
    
    if (existingInDb.isNotEmpty) {
      debugPrint('   ⚠️ Song already in database, syncing memory state...');
      
      // Sync memory state with database
      if (_currentPlaylist?.id == playlist.id && 
          !_currentPlaylistSongs.any((s) => s.path == song.path)) {
        _currentPlaylistSongs.add(song);
        notifyListeners();
      }
      
      throw Exception('Song already exists in playlist');
    }

    debugPrint('   📝 Calling repository to add song...');
    await _repository!.addSongToPlaylist(playlist.id!, song);
    debugPrint('   ✅ Repository add successful');

    // Update playlist in _userPlaylists using fresh reference
    final playlistIndex = _userPlaylists.indexWhere((p) => p.id == playlist.id);
    if (playlistIndex == -1) {
      debugPrint('   ⚠️ Playlist not found in _userPlaylists!');
      return;
    }
    
    final currentPlaylistFromList = _userPlaylists[playlistIndex];
    final updatedPlaylist = currentPlaylistFromList.copyWith(
      songs: [...currentPlaylistFromList.songs, song],
      updatedAt: DateTime.now(),
    );

    _userPlaylists[playlistIndex] = updatedPlaylist;
    debugPrint('   📋 Updated _userPlaylists[$playlistIndex], new song count: ${updatedPlaylist.songs.length}');

    // CRITICAL: Also update _currentPlaylistSongs if this is the active playlist
    if (_currentPlaylist?.id == playlist.id) {
      _currentPlaylistSongs.add(song);
      _currentPlaylist = updatedPlaylist;
      debugPrint('   📋 Updated _currentPlaylistSongs, new count: ${_currentPlaylistSongs.length}');
    }

    if (showSnackbar) {
      _callbacks?.showSnackBar('Added to "${playlist.name}"');
    }
    notifyListeners();
    debugPrint('   🔔 notifyListeners() called');
  } catch (e) {
    debugPrint('   💥 Exception caught: $e');
    if (e.toString().contains('already exists')) {
      throw Exception('Song already exists in playlist');
    } else {
      print('Error adding song "${song.title}" to playlist: $e');
      if (showSnackbar) {
        _callbacks?.showSnackBar('❌ Failed to add song: $e');
      }
      rethrow;
    }
  }
}


  Future<void> loadPlaylist(Playlist playlist, {bool autoPlay = false}) async {
    _currentPlaylistSongs = List.from(playlist.songs);
    _currentPlaylist = playlist;

    // Setup playlist for sequential playback
    if (_callbacks != null) {
      // Clear current queue and add all playlist songs
      _callbacks!.clearQueue();
      _callbacks!.addSongsToQueue(_currentPlaylistSongs);

      // Optionally start playing the first song
      if (autoPlay && _currentPlaylistSongs.isNotEmpty) {
        _callbacks!.playSong(_currentPlaylistSongs.first);
      }
    }

    await _savePlaylist();
    notifyListeners();
  }

  Future<void> deletePlaylist(Playlist playlist, BuildContext context) async {
    print(
      '🔍 Attempting to delete playlist: ${playlist.name}, id: ${playlist.id}',
    );

    if (_repository == null) {
      print('❌ Repository is null');
      return;
    }

    if (playlist.id == null) {
      print('❌ Playlist ID is null');
      _callbacks?.showSnackBar('Cannot delete playlist: Invalid ID');
      return;
    }

    print('📝 Showing confirmation dialog...');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Delete Playlist',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to delete "${playlist.name.length > 30 ? "${playlist.name.substring(0, 27)}..." : playlist.name}"?\n\nThis action cannot be undone.',
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
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    print('🎯 User confirmed: $confirm');
    if (confirm != true) {
      print('❌ User cancelled deletion');
      return;
    }

    try {
      print('🗃️ Deleting from repository...');
      await _repository!.deletePlaylist(playlist.id!);

      print('🔄 Updating UI state...');
      _userPlaylists.remove(playlist);
      if (_currentPlaylist == playlist) {
        _currentPlaylist = null;
        print('🎵 Cleared current playlist');
      }

      print('✅ Playlist deleted successfully');
      _callbacks?.showSnackBar('✅ Playlist deleted');
      notifyListeners();
    } catch (e) {
      print('❌ Error deleting playlist: $e');
      _callbacks?.showSnackBar('❌ Failed to delete playlist: $e');
    }
  }

  void removeFromPlaylist(Song song, {Song? currentSong}) {
    // If removing the currently playing song, skip to next song
    if (currentSong != null &&
        song.path == currentSong.path &&
        _callbacks != null) {
      final currentIndex = _currentPlaylistSongs.indexOf(song);
      if (currentIndex >= 0 &&
          currentIndex < _currentPlaylistSongs.length - 1) {
        // There's a next song - play it
        final nextSong = _currentPlaylistSongs[currentIndex + 1];
        _callbacks!.playSong(nextSong);
      } else {
        // This was the last song or no more songs - playNext will handle stopping
        _callbacks!.clearQueue(); // Clear any remaining queue
      }
    }

    _currentPlaylistSongs.remove(song);
    notifyListeners();
    _savePlaylist();
  }

  void reorderPlaylist(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final song = _currentPlaylistSongs.removeAt(oldIndex);
    _currentPlaylistSongs.insert(newIndex, song);
    notifyListeners();

    final currentPlaylist = _currentPlaylist;
    if (currentPlaylist?.id != null && _repository != null) {
      try {
        await _repository!.reorderSongsInPlaylist(
          currentPlaylist!.id!,
          _currentPlaylistSongs,
        );
      } catch (e) {
        print('Error reordering playlist: $e');
      }
    }
  }

  void setManagingPlaylists(bool value) {
    _isManagingPlaylists = value;
    notifyListeners();
  }

  Future<void> clearCurrentPlaylist() async {
    _currentPlaylistSongs.clear();

    // For user playlists, delete songs from database and update the playlist in memory
    if (_currentPlaylist != null && _currentPlaylist!.id != null && _database != null) {
      try {
        // Delete all songs for this playlist from playlist_songs table
        await _database!.delete(
          'playlist_songs',
          where: 'playlist_id = ?',
          whereArgs: [_currentPlaylist!.id],
        );

        // Update playlist's updated_at timestamp
        await _database!.update(
          'user_playlists',
          {'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [_currentPlaylist!.id],
        );

        // Update the playlist in the userPlaylists list to show 0 songs
        final updatedPlaylist = _currentPlaylist!.copyWith(
          songs: [],
          updatedAt: DateTime.now(),
        );
        final index = _userPlaylists.indexOf(_currentPlaylist!);
        if (index != -1) {
          _userPlaylists[index] = updatedPlaylist;
        }
      } catch (e) {
        print('Error clearing user playlist: $e');
      }
    } else {
      // Legacy playlist - save empty playlist (for backward compatibility)
      if (_database != null) {
        await _savePlaylist();
      }
    }

    _currentPlaylist = null;
    notifyListeners();
  }

  // Bulk operations
  Future<void> addSelectedSongsToPlaylist(
    Set<Song> selectedSongs,
    BuildContext context,
    List<Song> library,
  ) async {
    print(
      '🔍 addSelectedSongsToPlaylist: Method called with ${selectedSongs.length} songs',
    );
    if (selectedSongs.isEmpty ||
        _userPlaylists.isEmpty ||
        _repository == null) {
      print(
        '❌ No songs selected, no playlists available, or repository not initialized',
      );
      print('   - selectedSongs.isEmpty: ${selectedSongs.isEmpty}');
      print('   - _userPlaylists.isEmpty: ${_userPlaylists.isEmpty}');
      print('   - _repository == null: ${_repository == null}');
      return;
    }

    print('🎯 Opening playlist selection dialog...');

    final selectedPlaylist = await showDialog<Playlist>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Add ${selectedSongs.length} ${selectedSongs.length == 1 ? 'song' : 'songs'} to Playlist',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        children: [
          ..._userPlaylists.map(
            (playlist) => SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(playlist),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      color: ThemeColorsUtil.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${playlist.songs.length} ${playlist.songs.length == 1 ? 'song' : 'songs'}',
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorSecondary,
                              fontSize: 12,
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
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                Icon(
                  Icons.cancel,
                  color: ThemeColorsUtil.textColorSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cancel',
                  style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (selectedPlaylist == null || selectedPlaylist.id == null) {
      print('❌ User cancelled playlist selection or playlist has no ID');
      print('   - selectedPlaylist == null: ${selectedPlaylist == null}');
      print(
        '   - selectedPlaylist.id == null: ${selectedPlaylist?.id == null}',
      );
      return;
    }

    print(
      '🎵 Starting bulk add of ${selectedSongs.length} songs to "${selectedPlaylist.name}" (ID: ${selectedPlaylist.id})...',
    );

    try {
      // Use repository's bulk method for all database operations
      print('🔧 Calling addSongsToPlaylistBulk...');
      await _repository!.addSongsToPlaylistBulk(
        selectedPlaylist.id!,
        selectedSongs.toList(),
      );
      print('🔧 Bulk add completed, reloading playlists...');

      // Reload playlists to get updated state (simpler than manual state management)
      await loadUserPlaylists(library);
      print('🔧 Playlists reloaded, showing success message');

      print('🎵 Bulk add completed successfully');
      _callbacks?.showSnackBar(
        'Added ${selectedSongs.length} ${selectedSongs.length == 1 ? 'song' : 'songs'} to "${selectedPlaylist.name}"!',
      );
    } catch (e) {
      print('  ❌ Error during bulk add: $e');
      _callbacks?.showSnackBar('❌ Failed to add songs: $e');
    }
  }

  // Playlist import functionality - moved from main.dart
  Future<void> showPlaylistImportDialog(
    BuildContext context,
    List<Song> library,
  ) async {
    try {
      // Select file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'pls'],
        dialogTitle: 'Select Playlist File',
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);

      if (!PlaylistImportValidator.isValidFileForImport(file)) {
        _callbacks?.showSnackBar('Invalid playlist file format');
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          content: Row(
            children: [
              CircularProgressIndicator(color: ThemeColorsUtil.primaryColor),
              const SizedBox(width: 16),
              Text(
                'Parsing playlist...',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
            ],
          ),
        ),
      );

      // Parse and match tracks
      final importService = PlaylistImportService(
        library: library,
        existingPlaylists: _userPlaylists,
      );

      final importResult = await importService.importPlaylist(file);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show import preview dialog and handle everything in one async flow

      // Get suggested playlist name
      final suggestedName = importService.suggestPlaylistName(
        importResult.playlistName,
      );

      // Ask for playlist name
      final TextEditingController controller = TextEditingController(
        text: suggestedName,
      );

      final playlistName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ThemeColorsUtil.surfaceColor,
          title: Text(
            'Import Playlist: ${importResult.playlistName}',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Summary:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeColorsUtil.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${importResult.totalTracks} total tracks',
                  style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                ),
                Text(
                  '• ${importResult.autoImported} will be auto-imported',
                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                ),
                if (importResult.needsConfirmation > 0)
                  Text(
                    '• ${importResult.needsConfirmation} need confirmation',
                    style: TextStyle(color: ThemeColorsUtil.secondary),
                  ),
                if (importResult.notFound > 0)
                  Text(
                    '• ${importResult.notFound} not found in library',
                    style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Enter playlist name',
                    hintStyle: TextStyle(
                      color: ThemeColorsUtil.textColorSecondary,
                    ),
                  ),
                  autofocus: true,
                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                ),
              ],
            ),
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
                'Import',
                style: TextStyle(color: ThemeColorsUtil.primaryColor),
              ),
            ),
          ],
        ),
      );

      if (playlistName != null) {
        // Show import progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: ThemeColorsUtil.surfaceColor,
            content: Row(
              children: [
                CircularProgressIndicator(color: ThemeColorsUtil.primaryColor),
                const SizedBox(width: 16),
                Text(
                  'Creating playlist...',
                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                ),
              ],
            ),
          ),
        );

        try {
          // Get imported songs (auto-matched ones)
          final importedSongs = await importService.importConfirmedTracks(
            importResult,
            importResult.trackResults.where((r) => r.willBeImported).toList(),
          );

          // Close progress dialog temporarily to create playlist
          Navigator.of(context).pop();

          if (importedSongs.isNotEmpty) {
            // Create the playlist in database (this gives us the ID)
            await createPlaylist(playlistName);

            // Find the newly created playlist (it should be the last one)
            final newPlaylist = _userPlaylists.lastWhere(
              (p) => p.name == playlistName,
              orElse: () => Playlist(
                id: null,
                name: '',
                type: PlaylistType.userCreated,
                songs: [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            if (newPlaylist.id != null) {
              // Add all imported songs to the playlist
              for (final song in importedSongs) {
                await addSongToPlaylist(newPlaylist, song, showSnackbar: false);
              }

              // Load the playlist to switch to playlist view
              await loadPlaylist(newPlaylist);
              setManagingPlaylists(false);

              _callbacks?.showSnackBar(
                '✅ Imported ${importedSongs.length} songs to "$playlistName"',
              );
            } else {
              // Fallback: couldn't create playlist properly
              _callbacks?.showSnackBar(
                '❌ Failed to create playlist with proper ID',
              );
            }
          } else {
            // No songs to import
            _callbacks?.showSnackBar(
              'No songs could be imported from this playlist',
            );
          }
        } catch (e) {
          // Close progress dialog on error if still open
          Navigator.of(context).popUntil((route) => route.isFirst);
          _callbacks?.showSnackBar('Import failed: $e');
        }
      }
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).popUntil((route) => route.isFirst);

      _callbacks?.showSnackBar('Import failed: $e');
    }
  }
}
