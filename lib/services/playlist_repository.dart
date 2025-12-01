import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:tunes4r/models/playlist.dart';
import 'package:tunes4r/models/song.dart';

class PlaylistRepository {
  Database? _database;

  Future<void> setDatabase(Database database) async {
    _database = database;
    await _ensurePlaylistTablesExist();
  }

  Future<void> _ensurePlaylistTablesExist() async {
    if (_database == null) throw Exception('Database not initialized');

    // Create user_playlists table if it doesn't exist
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS user_playlists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create playlist_songs table if it doesn't exist
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS playlist_songs (
        playlist_id INTEGER,
        song_path TEXT,
        position INTEGER,
        PRIMARY KEY (playlist_id, song_path),
        FOREIGN KEY (playlist_id) REFERENCES user_playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_path) REFERENCES songs(path) ON DELETE CASCADE
      )
    ''');
  }

  // Playlist CRUD operations
  Future<Playlist> createPlaylist(String name, PlaylistType type) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now();
    final id = await _database!.insert('user_playlists', {
      'name': name,
      'type': PlaylistType.userCreated.index,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    return Playlist(
      id: id,
      name: name,
      type: type,
      createdAt: now,
      updatedAt: now,
      songs: [],
    );
  }

  Future<List<Playlist>> getAllPlaylists(List<Song> library) async {
    if (_database == null) throw Exception('Database not initialized');

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

    return userPlaylists;
  }

  Future<Playlist> getPlaylistById(int id, List<Song> library) async {
    if (_database == null) throw Exception('Database not initialized');

    final playlistData = await _database!.query('user_playlists', where: 'id = ?', whereArgs: [id]);
    if (playlistData.isEmpty) throw Exception('Playlist not found');

    // Load songs for the playlist
    final playlistSongs = await _database!.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );

    final playlistSongsList = playlistSongs.map((songData) {
      return library.firstWhere(
        (song) => song.path == songData['song_path'],
        orElse: () => Song(title: 'Unknown', path: songData['song_path'] as String),
      );
    }).toList();

    return Playlist.fromMap(playlistData.first, playlistSongsList);
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    if (_database == null) throw Exception('Database not initialized');
    if (playlist.id == null) throw Exception('Playlist ID cannot be null');

    await _database!.update(
      'user_playlists',
      {
        'name': playlist.name,
        'updated_at': playlist.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  }

  Future<void> deletePlaylist(int playlistId) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.delete('user_playlists', where: 'id = ?', whereArgs: [playlistId]);
    // Foreign key constraint will automatically delete playlist_songs
  }

  // Playlist Song operations
  Future<void> addSongToPlaylist(int playlistId, Song song, {int? position}) async {
    if (_database == null) throw Exception('Database not initialized');

    // Check if song is already in playlist
    final existing = await _database!.query(
      'playlist_songs',
      where: 'playlist_id = ? AND song_path = ?',
      whereArgs: [playlistId, song.path],
    );

    if (existing.isNotEmpty) {
      throw Exception('Song already exists in playlist');
    }

    // Get the position for insertion
    final insertPosition = position ?? await _getNextPosition(playlistId);

    await _database!.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_path': song.path,
      'position': insertPosition,
    });

    // Update playlist's updated_at timestamp
    await _database!.update(
      'user_playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> removeSongFromPlaylist(int playlistId, Song song) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.delete('playlist_songs',
      where: 'playlist_id = ? AND song_path = ?',
      whereArgs: [playlistId, song.path],
    );

    // Update playlist's updated_at timestamp
    await _database!.update(
      'user_playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> addSongsToPlaylistBulk(int playlistId, List<Song> songs) async {
    if (_database == null) throw Exception('Database not initialized');

    int added = 0;
    int skipped = 0;

    // First pass: check which songs aren't already in playlist
    List<Song> songsToAdd = [];
    for (final song in songs) {
      try {
        final existing = await _database!.query(
          'playlist_songs',
          where: 'playlist_id = ? AND song_path = ?',
          whereArgs: [playlistId, song.path],
        );

        if (existing.isEmpty) {
          songsToAdd.add(song);
        } else {
          skipped++;
        }
      } catch (e) {
        print('Error during duplicate check: ${song.title}, $e');
      }
    }

    // Second pass: bulk insert valid songs
    int nextPosition = await _getNextPosition(playlistId);

    for (final song in songsToAdd) {
      try {
        await _database!.insert('playlist_songs', {
          'playlist_id': playlistId,
          'song_path': song.path,
          'position': nextPosition,
        });
        nextPosition++;
        added++;
      } catch (e) {
        print('Error inserting "${song.title}": $e');
      }
    }

    // Update playlist's updated_at timestamp
    await _database!.update(
      'user_playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );

    print('Bulk add to repository: $added added, $skipped skipped');
  }

  Future<void> reorderSongsInPlaylist(int playlistId, List<Song> songs) async {
    if (_database == null) throw Exception('Database not initialized');

    // Delete existing songs
    await _database!.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [playlistId]);

    // Insert songs with new positions
    for (int i = 0; i < songs.length; i++) {
      await _database!.insert('playlist_songs', {
        'playlist_id': playlistId,
        'song_path': songs[i].path,
        'position': i,
      });
    }

    // Update playlist's updated_at timestamp
    await _database!.update(
      'user_playlists',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<int> _getNextPosition(int playlistId) async {
    if (_database == null) throw Exception('Database not initialized');

    final positionResult = await _database!.rawQuery(
      'SELECT MAX(position) as max_pos FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );

    return (positionResult.first['max_pos'] as int? ?? -1) + 1;
  }

  // Legacy playlist support (for backward compatibility)
  Future<List<Song>> getLegacyPlaylist(List<Song> library) async {
    if (_database == null) throw Exception('Database not initialized');

    try {
      final playlistSongs = await _database!.query('playlists', orderBy: 'position ASC');
      return playlistSongs.map((map) {
        return library.firstWhere(
          (song) => song.path == map['song_path'],
          orElse: () => Song(title: 'Unknown', path: map['song_path'] as String),
        );
      }).toList();
    } catch (e) {
      // Legacy table might not exist
      return [];
    }
  }

  Future<void> saveLegacyPlaylist(List<Song> songs) async {
    if (_database == null) throw Exception('Database not initialized');

    // Create legacy table if it doesn't exist
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY,
        song_path TEXT,
        position INTEGER,
        FOREIGN KEY (song_path) REFERENCES songs(path) ON DELETE CASCADE
      )
    ''');

    try {
      await _database!.delete('playlists');
      for (int i = 0; i < songs.length; i++) {
        await _database!.insert('playlists', {
          'song_path': songs[i].path,
          'position': i,
        });
      }
    } catch (e) {
      print('Error saving legacy playlist: $e');
    }
  }
}
