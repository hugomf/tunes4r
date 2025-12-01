import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tunes4r/models/playlist.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/playlist_import_service.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class PlaylistCallbacks {
  final Function(Song song) addToPlaylist;
  final Function(Song song, bool showSnackbar) addToPlayNext;
  final Function(Song song) playSong;
  final Function(String name) showSnackBar;

  PlaylistCallbacks({
    required this.addToPlaylist,
    required this.addToPlayNext,
    required this.playSong,
    required this.showSnackBar,
  });
}

class PlaylistState extends ChangeNotifier {
  // State variables
  List<Song> _currentPlaylistSongs = []; // Current playing list (renamed for clarity)
  List<Playlist> _userPlaylists = [];
  Playlist? _currentPlaylist;
  bool _isManagingPlaylists = true; // true = show playlist list, false = show current playlist

  Database? _database;
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

  // Set database reference
  void setDatabase(Database? database) {
    _database = database;
  }

  // Set callbacks
  void setCallbacks(PlaylistCallbacks callbacks) {
    _callbacks = callbacks;
  }

  // Load user playlists from database with song resolution
  Future<void> loadUserPlaylists(List<Song> library) async {
    if (_database == null) return;

    try {
      final userPlaylistsData = await _database!.query('user_playlists', orderBy: 'updated_at DESC');
      final userPlaylists = <Playlist>[];

      for (final playlistData in userPlaylistsData) {
        // Load songs for each playlist
        final playlistSongs = await _database!.query(
          'playlist_songs',
          where: 'playlist_id = ?',
          whereArgs: [playlistData['id']],
          orderBy: 'position ASC',
        );

        // Resolve songs from the library
        final playlistSongsList = playlistSongs.map((songData) {
          return library.firstWhere(
            (song) => song.path == songData['song_path'],
            orElse: () => Song(title: 'Unknown', path: songData['song_path'] as String),
          );
        }).toList();

        userPlaylists.add(Playlist.fromMap(playlistData, playlistSongsList));
      }

      _userPlaylists = userPlaylists;
      notifyListeners();
    } catch (e) {
      print('Error loading user playlists: $e');
    }
  }

  // Load playlist legacy songs (for backward compatibility)
  Future<void> loadLegacyPlaylists(List<Song> library) async {
    if (_database == null) return;

    try {
      final playlistSongs = await _database!.query('playlists', orderBy: 'position ASC');

      _currentPlaylistSongs = playlistSongs.map((map) {
        return library.firstWhere(
          (song) => song.path == map['song_path'],
          orElse: () => Song(title: 'Unknown', path: map['song_path'] as String),
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
    if (_database == null || name.trim().isEmpty || _callbacks == null) return;

    try {
      final now = DateTime.now();
      final id = await _database!.insert('user_playlists', {
        'name': name.trim(),
        'type': PlaylistType.userCreated.index,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final newPlaylist = Playlist(
        id: id,
        name: name.trim(),
        type: PlaylistType.userCreated,
        createdAt: now,
        updatedAt: now,
        songs: [],
      );

      _userPlaylists.add(newPlaylist);
      notifyListeners();

      _callbacks!.showSnackBar('✅ Playlist "${name.trim()}" created!');
    } catch (e) {
      print('Error creating playlist: $e');
      _callbacks!.showSnackBar('❌ Failed to create playlist: $e');
    }
  }

  Future<void> addSongToPlaylist(Playlist playlist, Song song, {bool showSnackbar = true}) async {
    if (_database == null || playlist.id == null) return;

    try {
      // Check if song is already in playlist
      final existing = await _database!.query(
        'playlist_songs',
        where: 'playlist_id = ? AND song_path = ?',
        whereArgs: [playlist.id, song.path],
      );

      if (existing.isNotEmpty) {
        // Song already exists - silently continue for bulk operations
        if (showSnackbar) {
          _callbacks?.showSnackBar('Song already in playlist');
        }
        return;
      }

      // Get the highest position in the playlist
      final positionResult = await _database!.rawQuery(
        'SELECT MAX(position) as max_pos FROM playlist_songs WHERE playlist_id = ?',
        [playlist.id],
      );

      final position = (positionResult.first['max_pos'] as int? ?? -1) + 1;

      await _database!.insert('playlist_songs', {
        'playlist_id': playlist.id,
        'song_path': song.path,
        'position': position,
      });

      // Update playlist in memory
      final updatedPlaylist = playlist.copyWith(
        songs: [...playlist.songs, song],
        updatedAt: DateTime.now(),
      );

      final index = _userPlaylists.indexOf(playlist);
      if (index != -1) {
        _userPlaylists[index] = updatedPlaylist;
      }

      // Update database
      await _database!.update(
        'user_playlists',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      if (showSnackbar) {
        _callbacks?.showSnackBar('Added to "${playlist.name}"');
      }
      notifyListeners();
    } catch (e) {
      print('Error adding song "${song.title}" to playlist: $e');
    }
  }

  Future<void> loadPlaylist(Playlist playlist) async {
    _currentPlaylistSongs = List.from(playlist.songs);
    _currentPlaylist = playlist;
    await _savePlaylist();
    // Note: playing song logic stays in main state
    notifyListeners();
  }

  Future<void> deletePlaylist(Playlist playlist, BuildContext context) async {
    print('🔍 Attempting to delete playlist: ${playlist.name}, id: ${playlist.id}');

    if (_database == null) {
      print('❌ Database is null');
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
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?\n\nThis action cannot be undone.',
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.textColorSecondary),
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
      print('🗃️ Deleting from database...');
      final deletedRows = await _database!.delete(
        'user_playlists',
        where: 'id = ?',
        whereArgs: [playlist.id],
      );
      print('🗃️ Deleted $deletedRows rows from user_playlists');

      // Also delete playlist songs
      final deletedSongs = await _database!.delete(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlist.id],
      );
      print('🗃️ Deleted $deletedSongs playlist songs');

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

  void removeFromPlaylist(Song song) {
    _currentPlaylistSongs.remove(song);
    notifyListeners();
    _savePlaylist();
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final song = _currentPlaylistSongs.removeAt(oldIndex);
    _currentPlaylistSongs.insert(newIndex, song);
    _savePlaylist();
    notifyListeners();
  }

  void setManagingPlaylists(bool value) {
    _isManagingPlaylists = value;
    notifyListeners();
  }

  // Bulk operations
  Future<void> addSelectedSongsToPlaylist(
    Set<Song> selectedSongs,
    BuildContext context,
    List<Song> library,
  ) async {
    if (selectedSongs.isEmpty || _userPlaylists.isEmpty) {
      print('❌ No songs selected or no playlists available');
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
          ..._userPlaylists.map((playlist) => SimpleDialogOption(
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
          )),
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

    if (selectedPlaylist == null) {
      print('❌ User cancelled playlist selection');
      return;
    }

    print('🎵 Starting bulk add of ${selectedSongs.length} songs to "${selectedPlaylist.name}"...');

    int added = 0;
    int skipped = 0;
    List<Song> songsToAdd = [];

    // First pass: collect songs that aren't already in playlist
    for (final song in selectedSongs) {
      try {
        final existing = await _database!.query(
          'playlist_songs',
          where: 'playlist_id = ? AND song_path = ?',
          whereArgs: [selectedPlaylist.id, song.path],
        );

        if (existing.isNotEmpty) {
          skipped++;
          print('  ⏭️ Skipped "${song.title}" (already exists)');
        } else {
          songsToAdd.add(song);
          print('  ➕ Will add: "${song.title}" by ${song.artist}');
        }
      } catch (e) {
        print('  ❌ Error during duplicate check: ${song.title}, $e');
      }
    }

    // Get the current max position for ordering
    int nextPosition = 0;
    try {
      final positionResult = await _database!.rawQuery(
        'SELECT MAX(position) as max_pos FROM playlist_songs WHERE playlist_id = ?',
        [selectedPlaylist.id],
      );
      nextPosition = (positionResult.first['max_pos'] as int? ?? -1) + 1;
      print('🎵 Next position will be: $nextPosition');
    } catch (e) {
      print('⚠️ Error getting max position: $e, using 0');
      nextPosition = 0;
    }

    // Second pass: bulk insert all valid songs
    for (int i = 0; i < songsToAdd.length; i++) {
      final song = songsToAdd[i];
      try {
        print('  📝 Inserting song ${i + 1}/${songsToAdd.length}: "${song.title}" at position $nextPosition');
        await _database!.insert('playlist_songs', {
          'playlist_id': selectedPlaylist.id,
          'song_path': song.path,
          'position': nextPosition,
        });
        nextPosition++;
        added++;
      } catch (e) {
        print('  ❌ Error inserting "${song.title}": $e');
      }
    }

    // Update in-memory playlist state with all the new songs at once
    if (added > 0) {
      final updatedPlaylist = selectedPlaylist.copyWith(
        songs: [...selectedPlaylist.songs, ...songsToAdd],
        updatedAt: DateTime.now(),
      );

      final index = _userPlaylists.indexOf(selectedPlaylist);
      if (index != -1) {
        _userPlaylists[index] = updatedPlaylist;
      }

      // Update the timestamp in database
      await _database!.update(
        'user_playlists',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [selectedPlaylist.id],
      );

      print('📝 Updated playlist in memory and database');
    }

    // Success message
    final totalProcessed = added + skipped;
    print('🎵 Bulk add complete: $added added, $skipped skipped, $totalProcessed total processed');

    _callbacks?.showSnackBar('Added $added ${added == 1 ? 'song' : 'songs'} to "${selectedPlaylist.name}"!${skipped > 0 ? ' ($skipped already existed)' : ''}');
  }

  // Playlist import functionality - moved from main.dart
  Future<void> showPlaylistImportDialog(BuildContext context, List<Song> library) async {
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
      final suggestedName = importService.suggestPlaylistName(importResult.playlistName);

      // Ask for playlist name
      final TextEditingController controller = TextEditingController(text: suggestedName);

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
                    hintStyle: TextStyle(color: ThemeColorsUtil.textColorSecondary),
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

              _callbacks?.showSnackBar('✅ Imported ${importedSongs.length} songs to "$playlistName"');
            } else {
              // Fallback: couldn't create playlist properly
              _callbacks?.showSnackBar('❌ Failed to create playlist with proper ID');
            }
          } else {
            // No songs to import
            _callbacks?.showSnackBar('No songs could be imported from this playlist');
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
