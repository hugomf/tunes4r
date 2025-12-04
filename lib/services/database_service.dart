import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/song.dart';

class DatabaseService {
  static const int _dbVersion = 6;
  static const String _dbName = 'tunes4r.db';
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS songs (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        path TEXT UNIQUE NOT NULL,
        duration INTEGER,
        is_favorite INTEGER DEFAULT 0,
        album_art BLOB,
        track_number INTEGER
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE songs ADD COLUMN is_favorite INTEGER DEFAULT 0',
        );
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN album_art BLOB');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN album TEXT');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE songs ADD COLUMN track_number INTEGER');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
  }

  Future<void> saveSong(Song song) async {
    final db = await database;
    await db.insert('songs', {
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'path': song.path,
      'duration': song.duration?.inMilliseconds ?? 0,
      'is_favorite': 0, // Will be updated by toggleFavorite
      'album_art': song.albumArt,
      'track_number': song.trackNumber,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Song>> loadAllSongs() async {
    final db = await database;
    final maps = await db.query('songs');
    return maps.map((map) {
      final albumArt = map['album_art'] != null
          ? Uint8List.fromList(List<int>.from(map['album_art'] as List))
          : null;

      return Song(
        title: map['title'] as String,
        artist: map['artist'] as String? ?? 'Unknown Artist',
        album: map['album'] as String? ?? 'Unknown Album',
        path: map['path'] as String,
        albumArt: albumArt,
        duration: Duration(milliseconds: map['duration'] as int? ?? 0),
        trackNumber: map['track_number'] as int?,
      );
    }).toList();
  }

  Future<List<Song>> loadFavorites() async {
    final db = await database;
    final maps = await db.query(
      'songs',
      where: 'is_favorite = ?',
      whereArgs: [1],
    );
    return maps.map((map) {
      return Song(
        title: map['title'] as String,
        artist: map['artist'] as String? ?? 'Unknown Artist',
        album: map['album'] as String? ?? 'Unknown Album',
        path: map['path'] as String,
        albumArt: map['album_art'] != null
            ? Uint8List.fromList(List<int>.from(map['album_art'] as List))
            : null,
        duration: Duration(milliseconds: map['duration'] as int? ?? 0),
        trackNumber: map['track_number'] as int?,
      );
    }).toList();
  }

  Future<void> updateFavorite(String path, bool isFavorite) async {
    final db = await database;
    await db.update(
      'songs',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> deleteSong(String path) async {
    final db = await database;
    await db.delete('songs', where: 'path = ?', whereArgs: [path]);
  }

  Future<void> clearLibrary() async {
    final db = await database;
    await db.delete('songs');
  }

  void dispose() {
    // Note: sqflite databases don't need explicit disposal
  }
}
