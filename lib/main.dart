import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/file_import_service.dart';
import 'package:tunes4r/services/media_service.dart';
import 'package:tunes4r/services/permission_service.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/utils/theme_manager.dart';
import 'package:tunes4r/widgets/albums_tab.dart';
import 'package:tunes4r/widgets/download_tab.dart';
import 'package:tunes4r/widgets/favorites_tab.dart';
import 'package:tunes4r/widgets/library_tab.dart';
import 'package:tunes4r/widgets/music_player_controls.dart';
import 'package:tunes4r/widgets/now_playing_tab.dart';
import 'package:tunes4r/widgets/playlist_state.dart';
import 'package:tunes4r/widgets/playlist_widget.dart';
import 'package:tunes4r/widgets/settings_tab.dart';


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
  // Services
  late final PlaybackManager _playbackManager;
  late final DatabaseService _databaseService;
  late final FileImportService _fileImportService;
  late final MediaService _mediaService;
  late final PermissionService _permissionService;
  SharedPreferences? _prefs;

  List<Song> _library = [];
  List<Song> _favorites = [];
  int _selectedIndex = 0;


  @override
  void initState() {
    super.initState();
    print('Initializing Tunes4R...');
    // Initialize services
    _databaseService = DatabaseService();
    _fileImportService = FileImportService(_databaseService);
    _mediaService = MediaService();
    _permissionService = PermissionService();

    // Initialize PlaybackManager first
    _playbackManager = PlaybackManager();
    _playbackManager.initialize(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onSongChanged: (song) {
        // Handle song change if needed
      },
    );

    _initApp().then((_) {
      print('App initialized successfully');
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
    } catch (e) {
      print('Error in _initApp: $e');
      // Continue with empty data
    }
  }

  Future<void> _initDatabase() async {
    // Initialize database by accessing the getter
    await _databaseService.database;
  }

  Future<void> _loadPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _playbackManager.setShuffling(_prefs?.getBool('isShuffling') ?? false);
          _playbackManager.setRepeating(_prefs?.getBool('isRepeating') ?? false);
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _loadLibrary() async {
    try {
      final songs = await _databaseService.loadAllSongs();
      final favorites = await _databaseService.loadFavorites();

      if (mounted) {
        setState(() {
          _library = songs;
          _favorites = favorites;
        });
      }
    } catch (e) {
      print('Error loading library: $e');
    }
  }

  Future<void> _saveSong(Song song) async {
    await _databaseService.saveSong(song);
  }

  Future<void> _savePreferences() async {
    try {
      await _prefs?.setBool('isShuffling', _playbackManager.isShuffling);
      await _prefs?.setBool('isRepeating', _playbackManager.isRepeating);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }





  Future<void> _pickFiles() async {
    final result = await _fileImportService.importFiles(context);

    // Refresh library if songs were added (result > 0)
    if (result > 0 && mounted) {
      await _loadLibrary();
    }
  }

  Future<void> _playSong(Song song) async {
    _playbackManager.playSong(song);
  }

  Future<void> _togglePlayPause() async {
    _playbackManager.togglePlayPause();
  }

  void _playNext() {
    _playbackManager.playNext();
  }

  void _playPrevious() {
    _playbackManager.playPrevious();
  }

  void _addToQueue(Song song) {
    _playbackManager.addToQueue(song);
  }

  void _addToPlayNext(Song song) {
    _playbackManager.addToPlayNext(song);
  }

  Future<void> _toggleFavorite(Song song) async {
    final isCurrentlyFavorite = _favorites.contains(song);

    if (mounted) {
      setState(() {
        if (isCurrentlyFavorite) {
          _favorites.remove(song);
        } else {
          _favorites.add(song);
        }
      });
    }

    await _databaseService.updateFavorite(song.path, !isCurrentlyFavorite);
  }



  @override
  void dispose() {
    _playbackManager.dispose();
    super.dispose();
  }



  Widget _buildPlaylist() {
    return FutureBuilder<Database?>(
      future: _databaseService.database,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final playlistState = PlaylistState();
          playlistState.setDatabase(snapshot.data);
          return PlaylistWidget(
            playlistState: playlistState,
            addToPlaylist: (song) => _playbackManager.addToQueue(song),
            addToPlayNext: (song, showSnackbar) => _playbackManager.addToPlayNext(song),
            playSong: _playSong,
            showSnackBar: (message) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    message,
                    style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                  ),
                  backgroundColor: ThemeColorsUtil.surfaceColor,
                ),
              );
            },
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading playlists: ${snapshot.error}',
              style: TextStyle(color: ThemeColorsUtil.error),
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
            ? 'Library (${_library.length})'
            : _selectedIndex == 1
                ? 'Playlists'
                : _selectedIndex == 2
                    ? 'Now Playing'
                    : _selectedIndex == 3
                        ? 'Albums (${_library.map((song) => song.album).toSet().length})'
                        : _selectedIndex == 4
                            ? 'Favorites (${_favorites.length})'
                            : _selectedIndex == 5
                                ? 'Download'
                                : 'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ThemeColorsUtil.textColorPrimary,
          ),
        ),
        actions: [
          if (_selectedIndex == 0) ...[
            // Library controls - simplified
            if (isMobile) ...[
              // On mobile, show primary action and use overflow menu
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _pickFiles,
                  icon: Icon(
                    Icons.add,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: ThemeColorsUtil.primaryColor,
                  ),
                  tooltip: 'Add Music',
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: ThemeColorsUtil.textColorSecondary,
                ),
                tooltip: 'More Options',
                onSelected: (value) {
                  switch (value) {
                    case 'clear':
                      _clearLibrary();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear_all,
                          color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Clear Library',
                          style: TextStyle(
                            color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
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
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _pickFiles,
                  icon: Icon(
                    Icons.add,
                    color: ThemeColorsUtil.scaffoldBackgroundColor,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: ThemeColorsUtil.primaryColor,
                  ),
                  tooltip: 'Add Music',
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
      drawer: Container(
        width: isMobile ? 220.0 : null,
        child: Drawer(
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
                      _buildDrawerItem(Icons.library_music, 'Library', 0),
                      _buildDrawerItem(Icons.playlist_play, 'Playlist', 1),
                      _buildDrawerItem(Icons.album, 'Now Playing', 2),
                      _buildDrawerItem(Icons.music_note, 'Albums', 3),
                      _buildDrawerItem(Icons.favorite, 'Favorites', 4),
                      _buildDrawerItem(Icons.cloud_download, 'Download', 5),

                      _buildDrawerItem(Icons.palette, 'Settings', 6, useShortLabels: false),

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
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: _selectedIndex == 0
                ? LibraryTab(
                    library: _library,
                    favorites: _favorites,
                    onPlaySong: _playSong,
                    onPlayNext: (song, [message]) {
                      _addToPlayNext(song);
                      if (message != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              message,
                              style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                            ),
                            backgroundColor: ThemeColorsUtil.surfaceColor,
                          ),
                        );
                      }
                    },
                    onToggleFavorite: _toggleFavorite,
                    onPickFiles: _pickFiles,
                    onClearLibrary: _clearLibrary,
                  )
                : _selectedIndex == 1
                    ? _buildPlaylist()
                    : _selectedIndex == 2
                        ? NowPlayingTab(
                            playbackManager: _playbackManager,
                            onTogglePlayPause: _togglePlayPause,
                            onPlayNext: _playNext,
                            onPlayPrevious: _playPrevious,
                          )
                        : _selectedIndex == 3
                            ? AlbumsTab(
                                library: _library,
                                onPlaySong: _playSong,
                                playbackManager: _playbackManager,
                              )
                            : _selectedIndex == 4
                                ? FavoritesTab(
                                    favorites: _favorites,
                                    onPlaySong: _playSong,
                                    onAddToQueue: _addToQueue,
                                    playbackManager: _playbackManager,
                                  )
                                : _selectedIndex == 5
                                    ? DownloadTab()
                                    : _selectedIndex == 6
                                        ? SettingsTab()
                                        : Placeholder(),
          ),

          // Music Player
          MusicPlayerControls(
            playbackManager: _playbackManager,
            onSavePreferences: _savePreferences,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, int index, {bool useShortLabels = true}) {
    bool isSelected = _selectedIndex == index;
    // Use shorter labels for mobile to prevent overflow
    final bool isMobile = useShortLabels && MediaQuery.of(context).size.width < 600;
    final displayLabel = isMobile ? _getShortLabel(label) : label;

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
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayLabel,
                style: TextStyle(
                  color: isSelected ? ThemeColorsUtil.primaryColor : ThemeColorsUtil.textColorSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortLabel(String label) {
    switch (label) {
      case 'Playlist':
        return 'List';
      case 'Now Playing':
        return 'Playing';
      case 'Favorites':
        return 'Favs';
      default:
        return label;
    }
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
        // Clear database
        await _databaseService.clearLibrary();

        // Clear in-memory data
        if (mounted) {
          setState(() {
            _library.clear();
            _favorites.clear();
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






}
