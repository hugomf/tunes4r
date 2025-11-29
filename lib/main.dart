import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// Local imports
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/models/playlist.dart';
import 'package:tunes4r/models/download.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/utils/theme_manager.dart';
import 'package:tunes4r/widgets/equalizer_dialog.dart';
import 'package:tunes4r/services/playlist_import_service.dart';
import 'package:tunes4r/services/download_service.dart';

enum SearchMode { songs, albums }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize theme manager
    final themeManager = ThemeManager();
    final themeColors = themeManager.getCurrentColors();

    return MaterialApp(
      title: 'Tunes4R',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: themeColors?.scaffoldBackground ?? const Color(0xFFFBF1C7),
        primaryColor: themeColors?.primary ?? const Color(0xFFB57614),
        colorScheme: ColorScheme.light(
          primary: themeColors?.primary ?? const Color(0xFFB57614),
          secondary: themeColors?.secondary ?? const Color(0xFF79740E),
          surface: themeColors?.surfacePrimary ?? const Color(0xFFEBDBB2),
        ),
      ),
      home: const MusicPlayerHome(),
    );
  }
}

class MusicPlayerHome extends StatefulWidget {
  const MusicPlayerHome({super.key});

  @override
  State<MusicPlayerHome> createState() => _MusicPlayerHomeState();
}

class _MusicPlayerHomeState extends State<MusicPlayerHome> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Database? _database;
  SharedPreferences? _prefs;

  List<Song> _library = [];
  List<Song> _playlist = []; // Current playing list
  final List<Song> _queue = [];    // Next songs to play
  List<Song> _favorites = [];
  List<Playlist> _userPlaylists = [];
  Playlist? _currentPlaylist;
  Song? _currentSong;
  bool _isPlaying = false;
  bool _isShuffling = false;
  bool _isRepeating = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _selectedIndex = 0;

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};

  // Playlist management state (for Playlist tab)
  bool _isManagingPlaylists = true; // true = show playlist list, false = show current playlist


  // Equalizer bands (10-band EQ for professional frequency control)
  List<double> _eqBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  bool _isEqualizerEnabled = false;
  final List<String> _eqLabels = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

  // Spectrum visualizer
  final List<double> _spectrumData = List.generate(32, (index) => 0.0);
  Timer? _spectrumTimer;

  // Download service and manager
  DownloadService? _downloadService;
  bool _downloadServiceAvailable = false;
  final DownloadManager _downloadManager = DownloadManager();
  Timer? _downloadRefreshTimer;
  DateTime? _lastDownloadQueueSave;

  // Search controller for download tab
  final TextEditingController _searchController = TextEditingController();

  // Album download controllers
  final TextEditingController _albumArtistController = TextEditingController();
  final TextEditingController _albumNameController = TextEditingController();

  // Search mode selection
  SearchMode _searchMode = SearchMode.songs;

  // Search results state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    print('Initializing Tunes4R...');
    _initApp().then((_) {
      print('App initialized successfully');
      _setupAudioPlayer();
      _startSpectrumAnimation();
    }).catchError((error) {
      print('Error initializing app: $error');
    });
  }

  Future<void> _initApp() async {
    try {
      await ThemeManager().initialize();
      await _initDatabase();
      await _loadPreferences();
      await _loadLibrary();
      await _initDownloadService();
    } catch (e) {
      print('Error in _initApp: $e');
      // Continue with empty data
    }
  }

  Future<void> _initDownloadService() async {
    try {
      _downloadService = DownloadService();
      final status = await _downloadService?.getServiceStatus();
      if (mounted) {
        setState(() {
          _downloadServiceAvailable = status != null;
        });
      }
      print('✅ Download service available: $_downloadServiceAvailable');

      // Start download progress monitoring if service is available
      if (_downloadServiceAvailable) {
        _startDownloadProgressMonitoring();
        _loadDownloadQueue();
      }
    } catch (e) {
      print('❌ Download service not available: $e');
      if (mounted) {
        setState(() {
          _downloadServiceAvailable = false;
        });
      }
    }
  }

  Future<void> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(directory.path, 'tunes4r.db');
      _database = await openDatabase(
        path,
        version: 6, // Updated to version 6 for track_number support
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
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

    // New user-created playlists table
    await db.execute('''
      CREATE TABLE user_playlists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Playlist songs relationship table
    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id INTEGER,
        song_path TEXT,
        position INTEGER,
        PRIMARY KEY (playlist_id, song_path),
        FOREIGN KEY (playlist_id) REFERENCES user_playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_path) REFERENCES songs(path) ON DELETE CASCADE
      )
    ''');

    // Legacy compatibility - renamed from playlists to playlist_songs for clarity
    // This table remains for backward compatibility but will be deprecated
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY,
        song_path TEXT,
        position INTEGER,
        FOREIGN KEY (song_path) REFERENCES songs(path) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE songs ADD COLUMN is_favorite INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE songs ADD COLUMN album_art BLOB');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE songs ADD COLUMN album TEXT');
    }
    if (oldVersion < 5) {
      // Create new playlist tables for version 5
      await db.execute('''
        CREATE TABLE user_playlists (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE playlist_songs (
          playlist_id INTEGER,
          song_path TEXT,
          position INTEGER,
          PRIMARY KEY (playlist_id, song_path),
          FOREIGN KEY (playlist_id) REFERENCES user_playlists(id) ON DELETE CASCADE,
          FOREIGN KEY (song_path) REFERENCES songs(path) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      // Add track_number column for albums in version 6
      await db.execute('ALTER TABLE songs ADD COLUMN track_number INTEGER');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isShuffling = _prefs?.getBool('isShuffling') ?? false;
          _isRepeating = _prefs?.getBool('isRepeating') ?? false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _loadLibrary() async {
    if (_database == null) return;

    try {
      final songs = await _database!.query('songs');
      final favorites = await _database!.query('songs', where: 'is_favorite = ?', whereArgs: [1]);
      final playlistSongs = await _database!.query('playlists', orderBy: 'position ASC');

      // Load user playlists
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

        final playlistSongsList = playlistSongs.map((songData) {
          return _library.firstWhere(
            (song) => song.path == songData['song_path'],
            orElse: () => Song(title: 'Unknown', path: songData['song_path'] as String),
          );
        }).toList();

        userPlaylists.add(Playlist.fromMap(playlistData, playlistSongsList));
      }

      if (mounted) {
        setState(() {
          _library = songs.map((map) {
            final albumArt = map['album_art'] != null ? Uint8List.fromList(List<int>.from(map['album_art'] as List)) : null;
            print('📥 Loaded song "${map['title']}" with album art: ${albumArt != null ? 'Yes (${albumArt.length} bytes)' : 'No'}');
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

          _favorites = favorites.map((map) => Song(
            title: map['title'] as String,
            artist: map['artist'] as String? ?? 'Unknown Artist',
            album: map['album'] as String? ?? 'Unknown Album',
            path: map['path'] as String,
            albumArt: map['album_art'] != null ? Uint8List.fromList(List<int>.from(map['album_art'] as List)) : null,
            duration: Duration(milliseconds: map['duration'] as int? ?? 0),
            trackNumber: map['track_number'] as int?,
          )).toList();

          _playlist = playlistSongs.map((map) {
            return _library.firstWhere(
              (song) => song.path == map['song_path'],
              orElse: () => Song(title: 'Unknown', path: map['song_path'] as String),
            );
          }).toList();

          _userPlaylists = userPlaylists;
        });
      }
    } catch (e) {
      print('Error loading library: $e');
    }
  }

  Future<void> _saveSong(Song song) async {
    if (_database == null) return;
    try {
      await _database!.insert(
        'songs',
        {
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'path': song.path,
          'duration': song.duration?.inMilliseconds ?? 0,
          'is_favorite': _favorites.contains(song) ? 1 : 0,
          'album_art': song.albumArt?.toList(),
          'track_number': song.trackNumber,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving song: $e');
    }
  }

  Future<void> _savePlaylist() async {
    if (_database == null) return;
    try {
      await _database!.delete('playlists');
      for (int i = 0; i < _playlist.length; i++) {
        await _database!.insert('playlists', {
          'song_path': _playlist[i].path,
          'position': i,
        });
      }
    } catch (e) {
      print('Error saving playlist: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _prefs?.setBool('isShuffling', _isShuffling);
      await _prefs?.setBool('isRepeating', _isRepeating);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _playNext();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  void _startSpectrumAnimation() {
    _spectrumTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isPlaying) {
        if (mounted) {
          setState(() {
            final random = Random();
            for (int i = 0; i < _spectrumData.length; i++) {
              double target = random.nextDouble() * (0.3 + random.nextDouble() * 0.7);
              _spectrumData[i] = _spectrumData[i] * 0.7 + target * 0.3;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            for (int i = 0; i < _spectrumData.length; i++) {
              _spectrumData[i] *= 0.85;
            }
          });
        }
      }
    });
  }

  Future<List<String>> _getAudioFilesFromDirectory(String dirPath) async {
    final List<String> audioFiles = [];
    final directory = Directory(dirPath);

    try {
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final extension = p.extension(entity.path).toLowerCase();
          // Check for common audio file extensions
          if (['.mp3', '.m4a', '.aac', '.ogg', '.flac', '.wav', '.wma', '.aiff'].contains(extension)) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory $dirPath: $e');
    }

    return audioFiles;
  }

  Future<List<Song>> _processAudioFiles(List<String> filePaths) async {
    List<Song> newSongs = [];

    for (var path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final fileName = p.basenameWithoutExtension(path);

      try {
        // This works on Android, iOS, macOS, Windows, Linux
        final metadata = readMetadata(file, getImage: true);

        Uint8List? albumArtBytes;
        if (metadata.pictures.isNotEmpty) {
          albumArtBytes = metadata.pictures.first.bytes;
        }

        final durationMs = metadata.duration?.inMilliseconds;

        newSongs.add(Song(
          title: metadata.title?.trim().isNotEmpty == true
              ? metadata.title!
              : fileName,
          path: path,
          artist: metadata.artist?.trim().isNotEmpty == true
              ? metadata.artist!
              : 'Unknown Artist',
          album: metadata.album?.trim().isNotEmpty == true
              ? metadata.album!
              : 'Unknown Album',
          albumArt: albumArtBytes, // Uint8List? for Image.memory()
          duration: durationMs != null
              ? Duration(milliseconds: durationMs)
              : null,
          trackNumber: metadata.trackNumber ?? metadata.trackTotal, // Use track number or track total if available
        ));
      } catch (e) {
        print('Error reading metadata for $fileName: $e');
        // Fallback
        newSongs.add(Song(
          title: fileName,
          path: path,
          artist: 'Unknown Artist',
        ));
      }
    }

    return newSongs;
  }

  Future<void> _pickFiles() async {
    try {
      // First, let user choose between files and folders
      final result = await showDialog<String>(
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
              style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.primaryColor),
              child: const Text('Files'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('folder'),
              style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.secondary),
              child: const Text('Folder'),
            ),
          ],
        ),
      );

      if (result == null) return;

      List<String> audioFilePaths = [];

      if (result == 'files') {
        // Pick multiple audio files
        FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: true,
        );

        if (fileResult != null && fileResult.files.isNotEmpty) {
          audioFilePaths = fileResult.files
              .map((f) => f.path)
              .where((path) => path != null)
              .cast<String>()
              .toList();
        }
      } else {
        // Pick a folder
        String? folderPath = await FilePicker.platform.getDirectoryPath();

        if (folderPath != null) {
          audioFilePaths = await _getAudioFilesFromDirectory(folderPath);
        }
      }

      if (audioFilePaths.isEmpty) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Adding music files...',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
      }

      // Process all audio files
      final newSongs = await _processAudioFiles(audioFilePaths);

      if (mounted) {
        setState(() {
          _library.addAll(newSongs);
        });
      }

      for (var song in newSongs) {
        await _saveSong(song);
      }

      print('Added ${newSongs.length} songs to library');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${newSongs.length} ${newSongs.length == 1 ? 'song' : 'songs'} to library!',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
      }
    } catch (e) {
      print('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding music: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    }
  }

  Future<void> _playSong(Song song) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(song.path));
      if (mounted) {
        setState(() {
          _currentSong = song;
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error playing song: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentSong != null) {
          await _audioPlayer.resume();
        } else if (_playlist.isNotEmpty) {
          await _playSong(_playlist[0]);
        }
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  void _playNext() {
    // First priority: check queue for next songs
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0); // Remove and get first song from queue
      _playSong(nextSong);
      return;
    }

    // Second priority: repeat current song if enabled
    if (_isRepeating && _currentSong != null) {
      _playSong(_currentSong!);
      return;
    }

    // Third priority: shuffle mode using playlist
    if (_isShuffling && _playlist.isNotEmpty) {
      final currentIndex = _playlist.indexOf(_currentSong!);
      if (_playlist.length > 1) {
        int nextIndex;
        do {
          nextIndex = Random().nextInt(_playlist.length);
        } while (nextIndex == currentIndex);
        _playSong(_playlist[nextIndex]);
      }
    } else if (_playlist.isNotEmpty) {
      // Normal mode: next song in sequence
      int currentIndex = _playlist.indexOf(_currentSong!);
      if (currentIndex < _playlist.length - 1) {
        _playSong(_playlist[currentIndex + 1]);
      } else {
        // End of playlist - stop or restart if repeating
        if (_isRepeating && _playlist.isNotEmpty) {
          _playSong(_playlist[0]);
        } else {
          if (mounted) {
            setState(() {
              _currentSong = null;
              _isPlaying = false;
            });
          }
        }
      }
    }
  }

  void _playPrevious() {
    if (_playlist.isEmpty || _currentSong == null) return;

    int currentIndex = _playlist.indexOf(_currentSong!);
    if (currentIndex > 0) {
      _playSong(_playlist[currentIndex - 1]);
    }
  }

  void _addToPlaylist(Song song) {
    if (mounted) {
      setState(() {
        if (!_playlist.contains(song)) {
          _playlist.add(song);
        }
      });
    }
  }

  void _addToQueue(Song song) {
    if (mounted) {
      setState(() {
        if (!_queue.contains(song)) {
          _queue.add(song);
        }
      });
    }
  }

  void _addToPlayNext(Song song) {
    if (mounted) {
      setState(() {
        // Insert at position 0 (will play immediately after current song)
        _queue.insert(0, song);
      });
    }
  }

  void _removeFromQueue(Song song) {
    if (mounted) {
      setState(() {
        _queue.remove(song);
      });
    }
  }

  void _clearQueue() {
    if (mounted) {
      setState(() {
        _queue.clear();
      });
    }
  }

  // Multi-select methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedSongs.clear(); // Clear selection when toggling mode
    });
  }

  void _toggleSongSelection(Song song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  void _selectAllSongs() {
    setState(() {
      _selectedSongs.addAll(_library.where((song) => !_selectedSongs.contains(song)));
    });
  }

  void _deselectAllSongs() {
    setState(() {
      _selectedSongs.clear();
    });
  }

  Future<void> _addSelectedSongsToPlaylist() async {
    if (_selectedSongs.isEmpty) {
      print('❌ No songs selected, returning early');
      return;
    }

    if (_userPlaylists.isEmpty) {
      print('❌ No playlists available');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No playlists available. Create one first!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
      return;
    }

    print('🎯 Opening playlist selection dialog...');

    final selectedPlaylist = await showDialog<Playlist>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text(
          'Add ${pluralSongs(_selectedSongs.length)} to Playlist',
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

    print('🎵 Starting bulk add of ${_selectedSongs.length} songs to "${selectedPlaylist.name}"...');

    int added = 0;
    int skipped = 0;
    List<Song> songsToAdd = [];

    // First pass: collect songs that aren't already in playlist
    for (final song in _selectedSongs) {
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

      setState(() {
        final index = _userPlaylists.indexOf(selectedPlaylist);
        if (index != -1) {
          _userPlaylists[index] = updatedPlaylist;
        }
      });

      // Update the timestamp in database
      await _database!.update(
        'user_playlists',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [selectedPlaylist.id],
      );

      print('📝 Updated playlist in memory and database');
    }

    // Exit selection mode and clear selection
    setState(() {
      _isSelectionMode = false;
      _selectedSongs.clear();
    });

    final totalProcessed = added + skipped;
    print('🎵 Bulk add complete: $added added, $skipped skipped, $totalProcessed total processed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $added ${pluralSongs(added)} to "${selectedPlaylist.name}"!${skipped > 0 ? ' ($skipped already existed)' : ''}',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        backgroundColor: ThemeColorsUtil.surfaceColor,
      ),
    );
  }

  String pluralSongs(int count) {
    return '$count ${count == 1 ? 'song' : 'songs'}';
  }

  // Playlist Management Methods
  Future<void> _createPlaylist(String name) async {
    if (_database == null || name.trim().isEmpty) return;

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

      setState(() {
        _userPlaylists.add(newPlaylist);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Playlist "${name.trim()}" created!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    } catch (e) {
      print('Error creating playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Failed to create playlist: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  Future<void> _addSongToPlaylist(Playlist playlist, Song song, {bool showSnackbar = true}) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Song already in playlist',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.surfaceColor,
            ),
          );
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

      setState(() {
        final index = _userPlaylists.indexOf(playlist);
        if (index != -1) {
          _userPlaylists[index] = updatedPlaylist;
        }
      });

      // Update database
      await _database!.update(
        'user_playlists',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to "${playlist.name}"',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
      }
      } catch (e) {
        print('Error adding song "${song.title}" to playlist: $e');
      }
  }

  Future<void> _loadPlaylist(Playlist playlist) async {
    setState(() {
      _playlist = List.from(playlist.songs);
      _currentPlaylist = playlist;
    });
    _savePlaylist();

    if (_playlist.isNotEmpty) {
      await _playSong(_playlist[0]);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded playlist "${playlist.name}"',
          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
        ),
        backgroundColor: ThemeColorsUtil.surfaceColor,
      ),
    );
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    print('🔍 Attempting to delete playlist: ${playlist.name}, id: ${playlist.id}');

    if (_database == null) {
      print('❌ Database is null');
      return;
    }

    if (playlist.id == null) {
      print('❌ Playlist ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete playlist: Invalid ID',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
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
      setState(() {
        _userPlaylists.remove(playlist);
        if (_currentPlaylist == playlist) {
          _currentPlaylist = null;
          print('🎵 Cleared current playlist');
        }
      });

      print('✅ Playlist deleted successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Playlist deleted',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    } catch (e) {
      print('❌ Error deleting playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Failed to delete playlist: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  void _removeFromPlaylist(Song song) {
    if (mounted) {
      setState(() {
        _playlist.remove(song);
      });
    }
    _savePlaylist();
  }

  Future<void> _toggleFavorite(Song song) async {
    if (mounted) {
      setState(() {
        if (_favorites.contains(song)) {
          _favorites.remove(song);
        } else {
          _favorites.add(song);
        }
      });
    }

    if (_database != null) {
      try {
        await _database!.update(
          'songs',
          {'is_favorite': _favorites.contains(song) ? 1 : 0},
          where: 'path = ?',
          whereArgs: [song.path],
        );
      } catch (e) {
        print('Error updating favorite: $e');
      }
    }
  }

  // Download Queue Methods
  Future<void> _loadDownloadQueue() async {
    try {
      final data = _prefs?.getStringList('download_queue');
      if (data != null) {
        final downloads = data.map((jsonStr) => json.decode(jsonStr) as Map<String, dynamic>).toList();
        _downloadManager.loadFromStorage(downloads);
        print('📥 Loaded ${_downloadManager.downloads.length} downloads from storage');
      }
    } catch (e) {
      print('❌ Error loading download queue: $e');
    }
  }

  Future<void> _saveDownloadQueue() async {
    try {
      // Rate limit saves to prevent spam - only save once every 3 seconds
      final now = DateTime.now();
      if (_lastDownloadQueueSave != null) {
        final timeSinceLastSave = now.difference(_lastDownloadQueueSave!);
        if (timeSinceLastSave.inSeconds < 3) {
          // Skip save if less than 3 seconds have passed
          return;
        }
      }

      final data = _downloadManager.saveToStorage();
      final jsonData = data.map((d) => json.encode(d)).toList();
      await _prefs?.setStringList('download_queue', jsonData);
      _lastDownloadQueueSave = now;
      print('💾 Saved ${_downloadManager.downloads.length} downloads to storage');
    } catch (e) {
      print('❌ Error saving download queue: $e');
    }
  }

  void _startDownloadProgressMonitoring() {
    _downloadRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_downloadServiceAvailable || _downloadService == null) return;

      // Check if it's time to refresh status based on manager's logic
      if (!_downloadManager.shouldRefreshStatus()) return;

      // Get active downloads and check their status
      final activeDownloads = _downloadManager.activeDownloads;
      if (activeDownloads.isEmpty) return;

      bool hasCompletion = false;

      print('🎯 DEBUG: Currently checking ${activeDownloads.length} active downloads');
      for (int i = 0; i < activeDownloads.length; i++) {
        final download = activeDownloads[i];
        print('🎯 DEBUG: Download ${i+1}/${activeDownloads.length}: id=${download.id}, title="${download.title}", status=${download.status}, progress=${download.progress}%, displays progress bar: ${download.status == DownloadStatus.downloading}');
      }

      for (final download in activeDownloads) {
        try {
          print('🔄 Checking status for download ${download.id} (${download.title}) - current status: ${download.status}, current progress: ${download.progress}%');
          final statusResponse = await _downloadService!.getDownloadStatus(download.id);
          if (statusResponse != null) {
            print('📡 Status response for ${download.id}: $statusResponse');

            // Check what status the API is sending
            final apiStatus = statusResponse['status'];
            final apiProgress = statusResponse['progress'];
            print('🎯 API status for ${download.id}: "$apiStatus" (type: ${apiStatus.runtimeType}), progress: $apiProgress');

            _downloadManager.updateDownload(download.id, statusResponse);

            // If download completed, save to library and show notification
            final updatedDownload = _downloadManager.getDownload(download.id);
            print('📝 Updated download ${download.id}: ${updatedDownload?.title} - status now ${updatedDownload?.status}');

            if (updatedDownload?.status == DownloadStatus.completed &&
                download.status != DownloadStatus.completed) {
              print('🎉 Download ${download.id} just completed!');
              await _handleDownloadCompletion(updatedDownload!);
              hasCompletion = true;
            }
          } else {
            print('⚠️ Null status response for download ${download.id}');
          }
        } catch (e) {
          // Mark download as failed when status check fails
          _downloadManager.updateDownload(download.id, {
            'status': 'error',
            'error': 'Failed to check status: $e'
          });
          print('⚠️ Marked download ${download.id} as failed due to status check error: $e');
        }
      }

      // Clean up old downloads
      _downloadManager.clearOldDownloads();

      // Mark status refreshed
      _downloadManager.markStatusRefreshed();

      // Trigger UI update if needed
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _handleDownloadCompletion(DownloadItem download) async {
    try {
      // Import the downloaded songs into the library
      if (download.songs != null) {
        final songFiles = await _findDownloadedAudioFiles();

        for (final songInfo in download.songs!) {
          // Look for corresponding file in downloaded_music directory
          final filename = '${songInfo['artist']} - ${songInfo['title']}.mp3';
          final filePath = songFiles.firstWhere(
            (path) => path.split(Platform.pathSeparator).last == filename,
            orElse: () => '',
          );

          if (filePath.isNotEmpty) {
            // Create Song object and add to library
            final song = Song(
              title: songInfo['title'],
              artist: songInfo['artist'],
              album: songInfo['album'] ?? download.album ?? 'Unknown Album',
              path: filePath,
            );

            await _saveSong(song);
            _library.add(song);
          }
        }
      }

      // Show completion notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ "${download.title}" downloaded successfully!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
          duration: const Duration(seconds: 3),
        ),
      );

      print('🎉 Download completed: "${download.title}" by ${download.artist}');
    } catch (e) {
      print('❌ Error handling download completion: $e');
    }
  }

  Future<List<String>> _findDownloadedAudioFiles() async {
    final List<String> audioFiles = [];

    // Try multiple possible locations for downloaded files
    final possiblePaths = [
      // Primary location (from API service path)
      p.join(Directory.current.path, '..', 'downloaded_music'),
      // Alternative locations if working directory differs
      p.join(Directory.current.path, 'downloaded_music'),
      // Path relative to app documents
      p.join((await getApplicationDocumentsDirectory()).path, '..', 'downloaded_music'),
    ];

    for (final dirPath in possiblePaths) {
      final directory = Directory(dirPath);

      try {
        print('🔍 Scanning download directory: $dirPath');
        if (await directory.exists()) {
          print('✅ Directory exists: $dirPath');
          await for (var entity in directory.list(recursive: false)) {
            if (entity is File) {
              final extension = p.extension(entity.path).toLowerCase();
              if (['.mp3', '.m4a', '.aac', '.ogg', '.flac', '.wav'].contains(extension)) {
                audioFiles.add(entity.path);
                print('📁 Found audio file: ${p.basename(entity.path)}');
              }
            }
          }
          if (audioFiles.isNotEmpty) {
            print('🎵 Found ${audioFiles.length} audio files total');
            break; // Stop scanning if we found files
          }
        } else {
          print('⚠️ Directory does not exist: $dirPath');
        }
      } catch (e) {
        print('❌ Error scanning directory $dirPath: $e');
      }
    }

    return audioFiles;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _spectrumTimer?.cancel();
    _downloadRefreshTimer?.cancel();
    _searchController.dispose();
    _albumArtistController.dispose();
    _albumNameController.dispose();
    super.dispose();
  }

  Widget _buildCreatePlaylistItem() {
    return InkWell(
      onTap: () async {
        final TextEditingController controller = TextEditingController();
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

        if (result != null) {
          await _createPlaylist(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ThemeColorsUtil.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add,
              color: ThemeColorsUtil.primaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              'New Playlist',
              style: TextStyle(
                color: ThemeColorsUtil.textColorPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(Playlist playlist) {
    final bool isActive = _currentPlaylist == playlist;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? ThemeColorsUtil.primaryColor.withOpacity(0.2) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Main tappable area (most of the item)
          Expanded(
            child: InkWell(
              onTap: () async => await _loadPlaylist(playlist),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      color: isActive ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: TextStyle(
                              color: isActive ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorPrimary,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          // Menu button (separate, no InkWell conflict)
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'load':
                  await _loadPlaylist(playlist);
                  break;
                case 'delete':
                  await _deletePlaylist(playlist);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.playlist_play, size: 18),
                    SizedBox(width: 8),
                    Text('Load'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
            ? 'Library (${_library.length})'
            : _selectedIndex == 1
                ? 'Playlist (${_playlist.length})'
                : _selectedIndex == 2
                    ? 'Now Playing'
                    : _selectedIndex == 3
                        ? 'Albums (${_getAlbumCount()})'
                        : _selectedIndex == 4
                            ? 'Favorites (${_favorites.length})'
                            : _selectedIndex == 5
                                ? 'Settings'
                                : 'Download',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ThemeColorsUtil.textColorPrimary,
          ),
        ),
        actions: [
          if (_selectedIndex == 0) ...[
            // Multi-select mode controls
            if (_isSelectionMode) ...[
              IconButton(
                onPressed: _deselectAllSongs,
                icon: Icon(
                  Icons.deselect,
                  color: ThemeColorsUtil.textColorPrimary,
                ),
                tooltip: 'Deselect All',
              ),
              IconButton(
                onPressed: _selectAllSongs,
                icon: Icon(
                  Icons.select_all,
                  color: ThemeColorsUtil.textColorPrimary,
                ),
                tooltip: 'Select All',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _toggleSelectionMode,
                  icon: Icon(
                    Icons.cancel,
                    color: ThemeColorsUtil.textColorSecondary,
                  ),
                  tooltip: 'Cancel Selection',
                ),
              ),
            ] else ...[
              // Normal mode controls
              IconButton(
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  Icons.checklist,
                  color: ThemeColorsUtil.textColorPrimary,
                ),
                tooltip: 'Select Songs',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _clearLibrary,
                  icon: Icon(
                    Icons.clear_all,
                    color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D),
                  ),
                  tooltip: 'Clear Library',
                ),
              ),
              // Import downloaded songs button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _importDownloadedSongs,
                  icon: Icon(
                    Icons.download_done,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  label: const Text('Import Downloads'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColorsUtil.secondary,
                    foregroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: Icon(
                    Icons.add,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  label: const Text('Add Music'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColorsUtil.primaryColor,
                    foregroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ]
          ],
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: ThemeColorsUtil.textColorPrimary,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: ThemeColorsUtil.appBarBackgroundColor,
                child: Center(
                  child: Text(
                    '🎵 Tunes4R',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeColorsUtil.textColorPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildNavItem(Icons.library_music, 'Library', 0),
                    _buildNavItem(Icons.playlist_play, 'Playlist', 1),
                    _buildNavItem(Icons.album, 'Now Playing', 2),
                    _buildNavItem(Icons.music_note, 'Albums', 3),
                    _buildNavItem(Icons.favorite, 'Favorites', 4),
                    _buildNavItem(Icons.cloud_download, 'Download', 6),

                    _buildSettingsTab(5),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Simple Mode',
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: _selectedIndex == 0
                ? _buildLibrary()
                : _selectedIndex == 1
                    ? _buildPlaylist()
                    : _selectedIndex == 2
                        ? _buildNowPlaying()
                        : _selectedIndex == 3
                            ? _buildAlbums()
                            : _selectedIndex == 4
                                ? _buildFavorites()
                                : _selectedIndex == 5
                                    ? _buildSettings()
                                    : _buildDownload(),
          ),

          // Music Player
          _buildMusicPlayer(),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? ThemeColorsUtil.primaryColor.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary() {
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
        : Column(
            children: [
              // Selection mode toolbar
              if (_isSelectionMode) ...[
                Container(
                  color: ThemeColorsUtil.appBarBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${pluralSongs(_selectedSongs.length)} selected',
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _selectedSongs.isEmpty ? null : _addSelectedSongsToPlaylist,
                        icon: Icon(
                          Icons.playlist_add,
                          color: _selectedSongs.isEmpty
                            ? ThemeColorsUtil.textColorSecondary
                            : ThemeColorsUtil.primaryColor,
                          size: 18,
                        ),
                        label: Text(
                          'Add to Playlist',
                          style: TextStyle(
                            color: _selectedSongs.isEmpty
                              ? ThemeColorsUtil.textColorSecondary
                              : ThemeColorsUtil.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _toggleSelectionMode,
                        icon: Icon(
                          Icons.cancel,
                          color: ThemeColorsUtil.textColorSecondary,
                          size: 18,
                        ),
                        label: Text(
                          'Cancel',
                          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Song list
              Expanded(
                child: ListView.builder(
                  itemCount: _library.length,
                  itemBuilder: (context, index) {
                    final song = _library[index];
                    final isSelected = _selectedSongs.contains(song);

                    if (_isSelectionMode) {
                      // Selection mode layout
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                            ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
                            : ThemeColorsUtil.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                              ? ThemeColorsUtil.primaryColor
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _toggleSongSelection(song),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleSongSelection(song),
                                activeColor: ThemeColorsUtil.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Container(
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
                                      ),
                                    )
                                  : Icon(
                                      Icons.music_note,
                                      size: 20,
                                      color: ThemeColorsUtil.primaryColor,
                                    ),
                              ),
                            ],
                          ),
                          title: Text(
                            song.title,
                            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                          ),
                          subtitle: Text(
                            song.artist,
                            style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
                          ),
                        ),
                      );
                    } else {
                      // Normal mode layout
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          tileColor: Colors.transparent,
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
                                  _favorites.contains(song)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                  color: _favorites.contains(song)
                                    ? ThemeColorsUtil.error
                                    : ThemeColorsUtil.textColorSecondary,
                                  size: 20,
                                ),
                                onPressed: () => _toggleFavorite(song),
                                tooltip: 'Toggle Favorite',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.play_arrow,
                                  color: ThemeColorsUtil.secondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _addToPlaylist(song);
                                  _playSong(song);
                                },
                                tooltip: 'Play Song',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.skip_next,
                                  color: ThemeColorsUtil.primaryColor,
                                  size: 20,
                                ),
                                onPressed: () => _addToPlayNext(song),
                                tooltip: 'Play Next',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.queue_music,
                                  color: ThemeColorsUtil.textColorSecondary,
                                  size: 20,
                                ),
                                onPressed: () => _addToQueue(song),
                                tooltip: 'Add to Queue',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.playlist_add,
                                  color: ThemeColorsUtil.textColorSecondary,
                                  size: 20,
                                ),
                                onPressed: () => _addToPlaylist(song),
                                tooltip: 'Add to Playlist',
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildPlaylist() {
    // Playlist Management View
    if (_isManagingPlaylists) {
      return Column(
        children: [
          // Create New Playlist Button and Import Button
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final TextEditingController controller = TextEditingController();
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

                    if (result != null) {
                      await _createPlaylist(result);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create New Playlist',
                          style: TextStyle(
                            color: ThemeColorsUtil.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _showPlaylistImportDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_upload,
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Import Playlist',
                          style: TextStyle(
                            color: ThemeColorsUtil.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Playlists List
          Expanded(
            child: _userPlaylists.isEmpty
                ? Center(
                    child: Text(
                      '🎵 No playlists yet.\nCreate your first playlist above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ThemeColorsUtil.textColorSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _userPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = _userPlaylists[index];
                      final bool isActive = _currentPlaylist == playlist;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                            ? ThemeColorsUtil.primaryColor.withOpacity(0.1)
                            : ThemeColorsUtil.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                              ? ThemeColorsUtil.primaryColor
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Main tappable area
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  await _loadPlaylist(playlist);
                                  setState(() => _isManagingPlaylists = false);
                                },
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
                                            if (isActive) ...[
                                              Text(
                                                'Currently loaded',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: ThemeColorsUtil.primaryColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Menu button
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case 'edit':
                                    await _loadPlaylist(playlist);
                                    setState(() => _isManagingPlaylists = false);
                                    break;
                                  case 'delete':
                                    await _deletePlaylist(playlist);
                                    break;
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
                    },
                  ),
          ),
        ],
      );
    }

    // Individual Playlist Editing View
    else {
      return Column(
        children: [
          // Back Button and Playlist Info
          Container(
            padding: const EdgeInsets.all(16),
            color: ThemeColorsUtil.appBarBackgroundColor,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: ThemeColorsUtil.textColorPrimary,
                  ),
                  onPressed: () => setState(() => _isManagingPlaylists = true),
                  tooltip: 'Back to Playlists',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPlaylist?.name ?? 'Current Playlist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeColorsUtil.textColorPrimary,
                        ),
                      ),
                      Text(
                        '${_playlist.length} ${pluralSongs(_playlist.length)}',
                        style: TextStyle(
                          color: ThemeColorsUtil.textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Playlist Content
          Expanded(
            child: _playlist.isEmpty
                ? Center(
                    child: Text(
                      '🎵 This playlist is empty.\nAdd songs from the Library.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ThemeColorsUtil.textColorSecondary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _playlist.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final song = _playlist.removeAt(oldIndex);
                        _playlist.insert(newIndex, song);
                        _savePlaylist();
                      });
                    },
                    itemBuilder: (context, index) {
                      final song = _playlist[index];
                      bool isCurrent = song == _currentSong;
                      return ListTile(
                        key: ValueKey(song.path),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCurrent ? Icons.equalizer : Icons.music_note,
                            color: isCurrent ? ThemeColorsUtil.scaffoldBackgroundColor : ThemeColorsUtil.primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: ThemeColorsUtil.textColorPrimary,
                          ),
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
                                Icons.remove_circle_outline,
                                color: ThemeColorsUtil.error,
                              ),
                              onPressed: () => _removeFromPlaylist(song),
                              tooltip: 'Remove from playlist',
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                color: ThemeColorsUtil.textColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }
  }

  Widget _buildFavorites() {
    return _favorites.isEmpty
        ? Center(
            child: Text(
              '❤️ No favorite songs yet.\nUse the heart icon in Library to add some!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeColorsUtil.textColorSecondary,
                fontSize: 16,
              ),
            ),
          )
        : ListView.builder(
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final song = _favorites[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: ThemeColorsUtil.error,
                    size: 20,
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
                        Icons.play_arrow,
                        color: ThemeColorsUtil.secondary,
                      ),
                      onPressed: () {
                        _addToPlaylist(song);
                        _playSong(song);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_to_queue,
                        color: ThemeColorsUtil.textColorSecondary,
                      ),
                      onPressed: () => _addToPlaylist(song),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildNowPlaying() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Album art display
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _currentSong?.albumArt != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        _currentSong!.albumArt!,
                        fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: ThemeColorsUtil.albumGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: 80,
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                        ),
                      );
                    },
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ThemeColorsUtil.albumGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 80,
                        color: ThemeColorsUtil.scaffoldBackgroundColor,
                      ),
                    ),
              ),

              const SizedBox(height: 20),

              // Current song info - shows title and artist on same line like player controls
              if (_currentSong != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${_currentSong!.title} - ${_currentSong!.artist.isNotEmpty ? _currentSong!.artist : 'Unknown Artist'}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColorsUtil.textColorPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Text(
                  'No song is currently playing',
                  style: TextStyle(
                    fontSize: 18,
                    color: ThemeColorsUtil.textColorSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Play a song from your Library or Playlist',
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeColorsUtil.textColorSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              // Spectrum visualizer - only shown when needed
              if (_isPlaying && _currentSong != null) ...[
                Container(
                  height: 35,
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(20, (index) {
                      final height = (_spectrumData[index % _spectrumData.length] * 25 + 5).clamp(5.0, 25.0);
                      return Container(
                        width: 4,
                        height: height,
                        margin: EdgeInsets.only(right: index < 19 ? 2 : 0), // Small gap between bars
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ThemeColorsUtil.spectrumColors,
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicPlayer() {
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
                _formatDuration(_position),
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
              Expanded(
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  activeColor: ThemeColorsUtil.seekBarActiveColor,
                  inactiveColor: ThemeColorsUtil.seekBarInactiveColor,
                  onChanged: (value) async {
                    await _audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
              ),
            ],
          ),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: _isShuffling ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () {
                  setState(() => _isShuffling = !_isShuffling);
                  _savePreferences();
                },
                tooltip: 'Shuffle',
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: _playPrevious,
                color: ThemeColorsUtil.textColorPrimary,
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
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: _playNext,
                color: ThemeColorsUtil.textColorPrimary,
              ),
              IconButton(
                icon: Icon(
                  Icons.equalizer,
                  color: ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () => _showEqualizerDialog(),
                tooltip: 'Equalizer',
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat,
                  color: _isRepeating ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                ),
                onPressed: () {
                  setState(() => _isRepeating = !_isRepeating);
                  _savePreferences();
                },
                tooltip: 'Repeat',
              ),
            ],
          ),



          // Current song info
          if (_currentSong != null) ...[
            const SizedBox(height: 16),
            Text(
              '${_currentSong?.title ?? ''} - ${_currentSong?.artist ?? ''}',
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

  void _showEqualizerDialog() {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EqualizerDialog(
        initialBands: _eqBands,
        initialEnabled: _isEqualizerEnabled,
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _eqBands = List<double>.from(result['bands']);
          _isEqualizerEnabled = result['enabled'];
        });
      }
    });
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
          'Are you sure you want to delete all songs from your library?\n\n'
          'This action cannot be undone.',
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
            child: const Text('Clear Library'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Stop current playback if any
        await _audioPlayer.stop();

        // Clear database
        if (_database != null) {
          await _database!.delete('songs');
          await _database!.delete('playlists');
        }

        // Clear in-memory data
        if (mounted) {
          setState(() {
            _library.clear();
            _playlist.clear();
            _favorites.clear();
            _currentSong = null;
            _isPlaying = false;
            _position = Duration.zero;
            _duration = Duration.zero;
          });
        }

        print('🧹 Library cleared successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Library cleared successfully!',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
      } catch (e) {
        print('❌ Error clearing library: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error clearing library: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildAlbums() {
    final albums = _library.map((song) => song.album).toSet().toList()..sort();
    return albums.isEmpty
        ? Center(
            child: Text(
              '📀 No albums in your library yet.\nAdd some music with album metadata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeColorsUtil.textColorSecondary,
                fontSize: 16,
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3 / 2,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              final albumSongs = _library.where((song) => song.album == albumName).toList();
              final firstSongWithArt = albumSongs.firstWhere(
                (song) => song.albumArt != null,
                orElse: () => albumSongs.first,
              );

              return GestureDetector(
                onTap: () {
                  // Sort album songs by track number when available, otherwise by title
                  final sortedAlbumSongs = List<Song>.from(albumSongs)..sort((a, b) {
                    if (a.trackNumber != null && b.trackNumber != null) {
                      return a.trackNumber!.compareTo(b.trackNumber!);
                    } else if (a.trackNumber != null) {
                      return -1; // a comes first
                    } else if (b.trackNumber != null) {
                      return 1; // b comes first
                    } else {
                      return a.title.compareTo(b.title); // alphabetical fallback
                    }
                  });

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
                          title: Text(
                            albumName,
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        body: Container(
                          color: ThemeColorsUtil.scaffoldBackgroundColor,
                          child: ListView.builder(
                            itemCount: sortedAlbumSongs.length,
                            itemBuilder: (context, idx) {
                              final song = sortedAlbumSongs[idx];
                              return ListTile(
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
                                        ),
                                      )
                                    : Icon(
                                        Icons.music_note,
                                        color: ThemeColorsUtil.primaryColor,
                                        size: 20,
                                      ),
                                ),
                                title: Row(
                                  children: [
                                    if (song.trackNumber != null) ...[
                                      Text(
                                        '${song.trackNumber}. ',
                                        style: TextStyle(
                                          color: ThemeColorsUtil.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(
                                        song.title,
                                        style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                                      ),
                                    ),
                                  ],
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
                                        Icons.play_arrow,
                                        color: ThemeColorsUtil.secondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _playlist.clear();
                                          _playlist.addAll(sortedAlbumSongs);
                                          _playSong(song);
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_to_queue,
                                        color: ThemeColorsUtil.textColorSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _playlist.addAll(sortedAlbumSongs);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            gradient: firstSongWithArt.albumArt != null
                              ? null
                              : LinearGradient(
                                  colors: ThemeColorsUtil.albumGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          ),
                          child: firstSongWithArt.albumArt != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.memory(
                                  firstSongWithArt.albumArt!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.album,
                                color: ThemeColorsUtil.scaffoldBackgroundColor,
                                size: 40,
                              ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                albumName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: ThemeColorsUtil.textColorPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${albumSongs.length} ${albumSongs.length == 1 ? 'track' : 'tracks'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ThemeColorsUtil.textColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  int _getAlbumCount() {
    final albums = _library.map((song) => song.album).toSet();
    return albums.length;
  }

  Widget _buildSettingsTab(int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? ThemeColorsUtil.primaryColor.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.palette,
              color: isSelected ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: TextStyle(
                color: isSelected ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Playlist Import Dialog
  void _showPlaylistImportDialog() async {
    if (!mounted) return;

    try {
      // Select file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'pls'],
        dialogTitle: 'Select Playlist File',
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = File(result.files.single.path!);

      if (!PlaylistImportValidator.isValidFileForImport(file)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid playlist file format',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.error,
            ),
          );
        }
        return;
      }

      // Show loading dialog
      if (mounted) {
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
      }

      // Parse and match tracks
      final importService = PlaylistImportService(
        library: _library,
        existingPlaylists: _userPlaylists,
      );

      final importResult = await importService.importPlaylist(file);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show import preview dialog and handle everything in one async flow
      if (mounted) {
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

        if (playlistName != null && mounted) {
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
            if (mounted) {
              Navigator.of(context).pop();
            }

            if (importedSongs.isNotEmpty && mounted) {
              // Create the playlist in database (this gives us the ID)
              await _createPlaylist(playlistName);

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

              if (newPlaylist.id != null && mounted) {
                // Add all imported songs to the playlist
                for (final song in importedSongs) {
                  await _addSongToPlaylist(newPlaylist, song, showSnackbar: false);
                }

                // Load the playlist to switch to playlist view
                await _loadPlaylist(newPlaylist);
                setState(() => _isManagingPlaylists = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Imported ${importedSongs.length} songs to "$playlistName"',
                      style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                    ),
                    backgroundColor: ThemeColorsUtil.surfaceColor,
                  ),
                );
              } else {
                // Fallback: couldn't create playlist properly
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ Failed to create playlist with proper ID',
                      style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                    ),
                    backgroundColor: ThemeColorsUtil.error,
                  ),
                );
              }
            } else {
              // No songs to import
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'No songs could be imported from this playlist',
                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                  ),
                  backgroundColor: ThemeColorsUtil.error,
                ),
              );
            }
          } catch (e) {
            // Close progress dialog on error if still open
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Import failed: $e',
                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                  ),
                  backgroundColor: ThemeColorsUtil.error,
                ),
              );
            }
          }
        }
      }

    } catch (e) {
      if (mounted) {
        // Close any open dialogs
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import failed: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    }
  }

  Widget _buildSettings() {
    final themeManager = ThemeManager();
    final availableThemes = themeManager.getThemes();

    return Container(
      color: ThemeColorsUtil.scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '🎨 Theme Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ThemeColorsUtil.textColorPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your favorite theme from our legendary collection!',
            style: TextStyle(
              fontSize: 16,
              color: ThemeColorsUtil.textColorSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: availableThemes.length,
            itemBuilder: (context, index) {
              final themeName = availableThemes.keys.elementAt(index);
              final theme = availableThemes[themeName]!;
              final currentTheme = ThemeManager().getCurrentTheme();
              final isSelected = currentTheme?.name == theme.name;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    ThemeManager().setTheme(themeName);
                  });
                  // Show feedback to user
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎨 Switched to "${theme.name}" theme!',
                        style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                      ),
                      backgroundColor: ThemeColorsUtil.surfaceColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? theme.colors.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: theme.colors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Color preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: theme.colors.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '💡 Pro Tip: Themes are automatically saved and applied immediately!',
            style: TextStyle(
              color: ThemeColorsUtil.secondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDownload() {
    if (!_downloadServiceAvailable || _downloadService == null) {
      return Container(
        color: ThemeColorsUtil.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 80,
                color: ThemeColorsUtil.textColorSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Download Service Unavailable',
                style: TextStyle(
                  fontSize: 20,
                  color: ThemeColorsUtil.textColorPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The download service is not available.\nMake sure the Python API is running.',
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final status = await _downloadService?.getServiceStatus();
                  setState(() {
                    _downloadServiceAvailable = status != null;
                  });
                },
                icon: Icon(
                  Icons.refresh,
                  color: ThemeColorsUtil.scaffoldBackgroundColor,
                ),
                label: Text(
                  'Retry Connection',
                  style: TextStyle(color: ThemeColorsUtil.scaffoldBackgroundColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColorsUtil.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: ThemeColorsUtil.scaffoldBackgroundColor,
      child: ListView(
        children: [
          // Search Header
          Container(
            color: ThemeColorsUtil.appBarBackgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎵 Download Music',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeColorsUtil.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search and download songs or albums from YouTube!',
                  style: TextStyle(
                    fontSize: 16,
                    color: ThemeColorsUtil.textColorSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Radio buttons for search mode
                Container(
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ThemeColorsUtil.textColorPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Radio<SearchMode>(
                            value: SearchMode.songs,
                            groupValue: _searchMode,
                            onChanged: (SearchMode? value) {
                              setState(() {
                                _searchMode = value!;
                                _searchResults.clear(); // Clear results when switching mode
                              });
                            },
                            activeColor: ThemeColorsUtil.primaryColor,
                          ),
                         Text(
                            'Song Search',
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Radio<SearchMode>(
                            value: SearchMode.albums,
                            groupValue: _searchMode,
                            onChanged: (SearchMode? value) {
                              setState(() {
                                _searchMode = value!;
                                _searchResults.clear(); // Clear results when switching mode
                              });
                            },
                            activeColor: ThemeColorsUtil.primaryColor,
                          ),
                          Text(
                            'Album Search',
                            style: TextStyle(
                              color: ThemeColorsUtil.textColorPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _searchMode == SearchMode.songs
                            ? '"Shape of You", "Adele", etc.'
                            : '"Abbey Road", "The Beatles - Sgt Pepper"'
                          ,
                          hintStyle: TextStyle(color: ThemeColorsUtil.textColorSecondary.withOpacity(0.7)),
                          filled: true,
                          fillColor: ThemeColorsUtil.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            _searchMode == SearchMode.songs ? Icons.music_note : Icons.album,
                            color: ThemeColorsUtil.primaryColor,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: ThemeColorsUtil.textColorSecondary,
                            ),
                            onPressed: () => _searchController.clear(),
                          ),
                        ),
                        style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                        onSubmitted: (value) => _performSearch(value.trim()),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final query = _searchController.text.trim();
                            if (query.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please enter something to search',
                                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                                  ),
                                  backgroundColor: ThemeColorsUtil.error,
                                ),
                              );
                              return;
                            }
                            _performSearch(query);
                          },
                          icon: Icon(
                            Icons.search,
                            color: ThemeColorsUtil.scaffoldBackgroundColor,
                          ),
                          label: Text(
                            'Search ${_searchMode == SearchMode.songs ? 'Songs' : 'Albums'}',
                            style: TextStyle(
                              color: ThemeColorsUtil.scaffoldBackgroundColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColorsUtil.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Results
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 300, // Fixed height for scrollable panel
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Fixed header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            color: ThemeColorsUtil.surfaceColor,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list,
                                color: ThemeColorsUtil.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search Results (${_searchResults.length})',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeColorsUtil.textColorPrimary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: ThemeColorsUtil.textColorSecondary,
                                ),
                                onPressed: () => setState(() => _searchResults.clear()),
                                tooltip: 'Clear Results',
                              ),
                            ],
                          ),
                        ),
                        // Scrollable results area
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.5),
                            child: ListView.builder(
                              itemCount: _searchResults.length,
                              padding: const EdgeInsets.only(bottom: 16),
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return _buildSearchResultItem(result);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Download Queue - only show if there are downloads
          if (_downloadManager.downloads.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: ThemeColorsUtil.appBarBackgroundColor,
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    color: ThemeColorsUtil.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Downloads (${_downloadManager.downloads.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ThemeColorsUtil.textColorPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: ThemeColorsUtil.scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _downloadManager.downloads.length,
                itemBuilder: (context, index) {
                  final download = _downloadManager.downloads[index];
                  return _buildDownloadItem(download);
                },
              ),
            ),
          ] else if (_searchResults.isEmpty) ...[
            // No downloads and no search results
            Container(
              height: 300,
              color: ThemeColorsUtil.scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 80,
                      color: ThemeColorsUtil.textColorSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for Music',
                      style: TextStyle(
                        fontSize: 20,
                        color: ThemeColorsUtil.textColorPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the search box above to find songs or albums\nYour downloads will appear here',
                      style: TextStyle(
                        color: ThemeColorsUtil.textColorSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Smart download function that determines what type of download to perform
  Future<void> _performSmartDownload(String query) async {
    if (query.isEmpty) return;

    // Check if it's a URL
    if (_isYouTubeUrl(query)) {
      await _downloadFromUrl(query);
    }
    // Check if it might be an album (contains common album keywords)
    else if (_looksLikeAlbumQuery(query)) {
      await _downloadAlbumSmart(query);
    }
    // Otherwise, treat as song search
    else {
      await _searchAndDownloadSong(query);
    }
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
           url.contains('youtu.be') ||
           url.contains('music.youtube.com') ||
           url.startsWith('http');
  }

  bool _looksLikeAlbumQuery(String query) {
    // Simple heuristic for album queries
    // If it has "album" keyword or looks like "artist - album" format
    return query.toLowerCase().contains('album') ||
           query.split('-').length >= 2 && !query.contains('ft.') && !query.contains('feat');
  }

  Future<void> _downloadFromUrl(String url) async {
    try {
      final result = await _downloadService!.downloadFromUrl(url);
      if (result != null) {
        // Check if response has expected structure - API returns download_id, not id
        if (result.containsKey('download_id')) {
          print('✅ URL download API returned valid response with download_id: ${result['download_id']}');

          // Extract download ID from response
          final downloadId = result['download_id'] as String;
          print('🎵 Extracted downloadId: "$downloadId" (type: ${downloadId.runtimeType})');

          // Create DownloadItem from API response and add to queue
          final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
          _downloadManager.addDownload(downloadItem);

          // Save queue to persistence
          await _saveDownloadQueue();

          // Force an immediate status check for this download
          if (_downloadService != null) {
            try {
              print('🔄 Performing immediate status check for download: $downloadId');
              final statusResponse = await _downloadService!.getDownloadStatus(downloadId);
              if (statusResponse != null) {
                print('📡 Immediate status response: $statusResponse');
                _downloadManager.updateDownload(downloadId, statusResponse);
              } else {
                print('⚠️ No status response received');
              }
            } catch (e) {
              print('❌ Error in immediate status check: $e');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Started downloading "${downloadItem.title}" by ${downloadItem.artist}',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.surfaceColor,
            ),
          );
        } else {
          throw 'Invalid response format - missing download_id field';
        }
      } else {
        throw 'Download from URL failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download failed: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  Future<void> _downloadAlbumSmart(String query) async {
    try {
      // Parse album query - try to extract artist and album
      final parts = query.split('-').map((s) => s.trim()).toList();
      String artist = '';
      String album = '';

      if (parts.length >= 2) {
        artist = parts[0];
        album = parts.sublist(1).join('-');
      } else {
        // Fallback to entire query as album name
        album = query;
      }

      if (artist.isEmpty) {
        artist = _albumArtistController.text.trim();
      }
      if (album.isEmpty) {
        album = _albumNameController.text.trim();
      }

      if (artist.isEmpty || album.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'For album searches, please specify "Artist - Album Name"',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
        return;
      }

      final result = await _downloadService!.downloadAlbum(artist, album);
      if (result != null) {
        // Check if response has expected structure - API returns download_id, not id
        if (result.containsKey('download_id')) {
          print('✅ Album download API returned valid response with download_id: ${result['download_id']}');

          // Extract download ID from response
          final downloadId = result['download_id'] as String;
          print('🎵 Extracted downloadId: "$downloadId" (type: ${downloadId.runtimeType})');

          // Album downloads return different structure, create DownloadItem differently
          // The API might handle album downloads differently, so we'll need to handle this case
          final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
          _downloadManager.addDownload(downloadItem);

          // Save queue to persistence
          await _saveDownloadQueue();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Started downloading album "$album" by $artist',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.surfaceColor,
            ),
          );
        } else {
          throw 'Invalid response format - missing download_id field';
        }
      } else {
        throw 'Album download failed';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Album download failed: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  Future<void> _searchAndDownloadSong(String query) async {
    try {
      print('🔍 Searching for song: "$query"');
      final result = await _downloadService!.searchSong(query: query);
      print('📡 Raw API response: $result');

      if (result != null) {
        print('🔍 Processing API response...');

        // Check if response has expected structure - API returns download_id, not id
        if (result.containsKey('download_id')) {
          print('✅ API returned valid response with download_id: ${result['download_id']}');

          // Extract download ID from response
          final downloadId = result['download_id'] as String;
          print('🎵 Extracted downloadId: "$downloadId" (type: ${downloadId.runtimeType})');

          // Create DownloadItem from API response and add to queue
          print('🏗️ Creating DownloadItem from API response...');
          final downloadItem = DownloadItem.fromApiResponse(downloadId, result);
          print('✅ Created DownloadItem: ${downloadItem.title} by ${downloadItem.artist} (ID: ${downloadItem.id})');

          // Add to download manager
          print('📋 Adding download item to queue...');
          _downloadManager.addDownload(downloadItem);
          print('✅ Added to download manager. Total downloads: ${_downloadManager.downloads.length}');

          // Save queue to persistence
          print('💾 Saving download queue to persistence...');
          await _saveDownloadQueue();
          print('✅ Download queue saved successfully');

          // Force an immediate status check for this download (CRITICAL!)
          print('🔍 DEBUG: About to check download service availability...');
          print('🔍 DEBUG: _downloadService is null?: ${this._downloadService == null}');
          if (_downloadService != null) {
            print('✅ Download service is available, performing immediate status check');
            try {
              print('🔄 Performing immediate status check for download: $downloadId');
              final statusResponse = await _downloadService!.getDownloadStatus(downloadId);
              print('📡 Immediate status response received: ${statusResponse != null}');
              if (statusResponse != null) {
                print('📡 Immediate status response content: $statusResponse');
                _downloadManager.updateDownload(downloadId, statusResponse);
                print('✅ Updated download status from immediate check');
              } else {
                print('⚠️ Immediate status response was null');
              }
            } catch (e, stackTrace) {
              print('❌ Error in immediate status check: $e');
              print('❌ Stack trace: $stackTrace');
            }
          } else {
            print('❌ CRITICAL: _downloadService is null during immediate status check!');
            print('❌ This explains why status updates are not working');
          }

          print('🎵 Download setup complete: "${downloadItem.title}" by ${downloadItem.artist} (ID: ${downloadItem.id})');

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Started downloading "${downloadItem.title}" by ${downloadItem.artist}',
                  style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                ),
                backgroundColor: ThemeColorsUtil.surfaceColor,
              ),
            );
          }

          // Force UI update to show the new download item
          if (mounted) {
            setState(() {});
          }

        } else {
          print('❌ Invalid response format:');
          print('   - Result type: ${result.runtimeType}');
          print('   - Is Map?: ${result is Map}');
          print('   - Keys: ${result.keys.toList()}');
          result.forEach((key, value) {
            print('     $key (${value.runtimeType}): $value');
          });
                  throw 'Invalid response format - missing download_id field';
        }
      } else {
        throw 'Search returned no results or null response';
      }
    } catch (e, stackTrace) {
      print('❌ Download error: $e');
      print('📄 Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download failed: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }

  Widget _buildDownloadItem(DownloadItem download) {
    IconData getStatusIcon() {
      switch (download.status) {
        case DownloadStatus.queued:
          return Icons.hourglass_empty;
        case DownloadStatus.downloading:
          return Icons.downloading;
        case DownloadStatus.completed:
          return Icons.check_circle;
        case DownloadStatus.failed:
          return Icons.error;
        case DownloadStatus.cancelled:
          return Icons.cancel;
      }
    }

    Color getStatusColor() {
      switch (download.status) {
        case DownloadStatus.queued:
          return ThemeColorsUtil.textColorSecondary;
        case DownloadStatus.downloading:
          return ThemeColorsUtil.primaryColor;
        case DownloadStatus.completed:
          return Colors.green.shade600;
        case DownloadStatus.failed:
          return ThemeColorsUtil.error;
        case DownloadStatus.cancelled:
          return Colors.orange.shade600;
      }
    }

    String getStatusText() {
      switch (download.status) {
        case DownloadStatus.queued:
          return 'Queued';
        case DownloadStatus.downloading:
          return 'Downloading...';
        case DownloadStatus.completed:
          return 'Completed';
        case DownloadStatus.failed:
          return 'Failed';
        case DownloadStatus.cancelled:
          return 'Cancelled';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThemeColorsUtil.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                getStatusIcon(),
                color: getStatusColor(),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            // Title and status in a column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          download.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeColorsUtil.textColorPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          download.artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeColorsUtil.textColorSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        getStatusText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: getStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (download.status == DownloadStatus.downloading) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${download.progress.round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: ThemeColorsUtil.textColorSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Progress bar for downloading items
                  if (download.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: download.progress / 100.0,
                      backgroundColor: ThemeColorsUtil.surfaceColor.withOpacity(0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(ThemeColorsUtil.primaryColor),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ],
                ],
              ),
            ),
            // Action button
            if (download.status == DownloadStatus.failed ||
                download.status == DownloadStatus.cancelled)
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: ThemeColorsUtil.primaryColor,
                  size: 16,
                ),
                onPressed: () => _retryDownload(download),
                tooltip: 'Retry',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              )
            else if (download.status == DownloadStatus.downloading)
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: Colors.red.shade600,
                  size: 16,
                ),
                onPressed: () => _cancelDownload(download),
                tooltip: 'Cancel',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              )
            else if (download.status == DownloadStatus.completed)
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: ThemeColorsUtil.textColorSecondary,
                  size: 16,
                ),
                onPressed: () => _removeDownload(download),
                tooltip: 'Remove',
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryDownload(DownloadItem download) async {
    // Reset status and re-add to queue via manager update
    _downloadManager.updateDownload(download.id, {
      'status': DownloadStatus.queued.index,
      'errorMessage': null,
      'progress': 0,
    });
    await _saveDownloadQueue();

    // Trigger re-processing
    _downloadRefreshTimer?.cancel();
    _startDownloadProgressMonitoring();

    setState(() {});
  }

  Future<void> _cancelDownload(DownloadItem download) async {
    _downloadManager.updateDownload(download.id, {'status': DownloadStatus.cancelled.index});
    await _saveDownloadQueue();
    setState(() {});
  }

  Future<void> _removeDownload(DownloadItem download) async {
    _downloadManager.removeDownload(download.id);
    await _saveDownloadQueue();
    setState(() {});
  }

  // Search functionality for download tab
  Future<void> _performSearch(String query) async {
    if (_downloadService == null || query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      if (_searchMode == SearchMode.songs) {
        // Use the proper search endpoint that returns multiple results
        final searchResults = await _downloadService!.searchSongs(query, limit: 10);
        print('🔍 Song search API returned: $searchResults');

        if (searchResults != null && searchResults.isNotEmpty) {
          // Add additional fields that the UI expects
          final formattedResults = searchResults.map<Map<String, dynamic>>((song) => {
            ...song,
            'thumbnail_url': song['thumbnail_url'] ?? 'https://via.placeholder.com/120x90/333333/666666?text=No+Image',
          }).toList();
          print('🔍 Formatted song results with thumbnails: $formattedResults');

          setState(() => _searchResults = formattedResults);
        } else {
          print('No song results found for: $query');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No results found for "$query"',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.error,
            ),
          );
        }
      } else {
        // Use the proper album search endpoint
        final albumResults = await _downloadService!.searchAlbums(query, limit: 5);

        if (albumResults != null && albumResults.isNotEmpty) {
          // Convert album search results to the expected format
          final formattedResults = albumResults.map<Map<String, dynamic>>((album) => {
            'title': album['album'] ?? 'Unknown Album',
            'artist': album['artist'] ?? 'Unknown Artist',
            'album': album['album'],
            'track_count': album['track_count'] ?? 0,
            'release_year': album['release_year'],
            'type': 'album',
            'album_info': album,
            'thumbnail_url': album['cover_url'] ?? 'https://via.placeholder.com/120x90/333333/666666?text=Album',
          }).toList();

          setState(() => _searchResults = formattedResults);
        } else {
          print('No album results found for: $query');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No albums found for "$query"',
                style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
              ),
              backgroundColor: ThemeColorsUtil.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Search failed: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    final title = result['title'] ?? 'Unknown Title';
    final artist = result['artist'] ?? 'Unknown Artist';
    final album = result['album'];
    final duration = result['duration'] ?? result['length'];
    final trackNumber = result['track_number'];
    final isAlbumTrack = result['type'] == 'album_track';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              result['thumbnail_url'] ?? 'https://via.placeholder.com/120x90/333333/666666?text=No+Image',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _searchMode == SearchMode.songs ? Icons.music_note : Icons.album,
                  color: ThemeColorsUtil.primaryColor,
                  size: 20,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Icon(
                  _searchMode == SearchMode.songs ? Icons.music_note : Icons.album,
                  color: ThemeColorsUtil.primaryColor,
                  size: 18,
                );
              },
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (trackNumber != null) ...[
                  Text(
                    '$trackNumber. ',
                    style: TextStyle(
                      color: ThemeColorsUtil.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: ThemeColorsUtil.textColorPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (album != null) ...[
              Text(
                album,
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        subtitle: Text(
          artist,
          style: TextStyle(color: ThemeColorsUtil.textColorSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (duration != null) ...[
              Text(
                duration.toString(),
                style: TextStyle(
                  color: ThemeColorsUtil.textColorSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: Icon(
                Icons.download,
                color: ThemeColorsUtil.primaryColor,
              ),
              onPressed: () => _downloadFromSearchResult(result, isAlbumTrack),
              tooltip: 'Download',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFromSearchResult(Map<String, dynamic> result, bool isAlbumTrack) async {
    try {
      if (_searchMode == SearchMode.songs) {
        // Download individual song
        final songQuery = '${result['artist']} - ${result['title']}';
        await _searchAndDownloadSong(songQuery);
      } else {
        // For albums, check if it's part of an album search result
        if (isAlbumTrack && result.containsKey('album_info')) {
          final albumInfo = result['album_info'] as Map<String, dynamic>;
          final artist = albumInfo['artist'] ?? result['artist'];
          final album = albumInfo['album'] ?? result['album'];
          await _downloadAlbumSmart('$artist - $album');
        } else {
          // Fallback: download as individual song
          final songQuery = '${result['artist']} - ${result['title']}';
          await _searchAndDownloadSong(songQuery);
        }
      }
    } catch (e) {
      print('❌ Error downloading from search result: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download failed: $e',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
      }
    }
  }

  Future<void> _importDownloadedSongs() async {
    try {
      final songFiles = await _findDownloadedAudioFiles();

      if (songFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No downloaded music files found to import',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.surfaceColor,
          ),
        );
        return;
      }

      // Process all found audio files
      final newSongs = await _processAudioFiles(songFiles);

      if (newSongs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No valid music files found',
              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
            ),
            backgroundColor: ThemeColorsUtil.error,
          ),
        );
        return;
      }

      // Add to library database
      for (final song in newSongs) {
        await _saveSong(song);
      }

      // Add to in-memory library
      if (mounted) {
        setState(() {
          _library.addAll(newSongs);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Imported ${newSongs.length} ${newSongs.length == 1 ? 'song' : 'songs'} from downloads!',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );

      print('Imported ${newSongs.length} downloaded songs into library');
    } catch (e) {
      print('❌ Error importing downloaded songs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to import downloaded songs: $e',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.error,
        ),
      );
    }
  }
}
