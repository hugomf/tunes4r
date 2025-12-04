import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/file_import_service.dart';
import 'package:tunes4r/services/library_service.dart';
import 'package:tunes4r/services/media_control_service.dart';
import 'package:tunes4r/services/media_service.dart';
import 'package:tunes4r/services/permission_service.dart';
import 'package:tunes4r/services/audio_equalizer_service.dart';
import 'package:logging/logging.dart';
import 'package:tunes4r/audio_player/audio_player.dart';
import 'package:tunes4r/audio_player/playback_commands.dart';
import 'package:tunes4r/audio_player/logger.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/utils/theme_manager.dart';
import 'package:tunes4r/widgets/albums_tab.dart';
import 'package:tunes4r/widgets/download_tab.dart';
import 'package:tunes4r/widgets/favorites_tab.dart';
import 'package:tunes4r/widgets/library_tab.dart';
import 'package:tunes4r/audio_player/widgets/music_player_controls.dart';
import 'package:tunes4r/audio_player/widgets/now_playing_tab.dart';
import 'package:tunes4r/widgets/playlist_state.dart';
import 'package:tunes4r/widgets/playlist_widget.dart';
import 'package:tunes4r/widgets/settings_tab.dart';

enum SearchMode { songs, albums }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure bounded context logger for structured logging
  AudioPlayerLogger.configure(
    level: Level.INFO, // INFO for playback events, WARNING for errors, SEVERE for critical issues
  );

  // Test that logger works
  AudioPlayerLogger.info('Logger initialized - testing console output');

  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();
    final themeColors = themeManager.getCurrentColors();

    return MaterialApp(
      title: 'Tunes4R',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor:
            themeColors?.scaffoldBackground ?? const Color(0xFFFBF1C7),
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
  late final AudioPlayer _audioPlayer;
  late final AudioEqualizerService _equalizerService;
  late final DatabaseService _databaseService;
  late final FileImportService _fileImportService;
  late final LibraryService _libraryService;
  late final MediaControlService _mediaControlService;
  late final MediaService _mediaService;
  late final PermissionService _permissionService;
  SharedPreferences? _prefs;

  List<Song> _library = [];
  List<Song> _favorites = [];
  int _selectedIndex = 0;
  PlaylistState? _playlistState;


  @override
  void initState() {
    super.initState();
    print('Initializing Tunes4R...');

    _databaseService = DatabaseService();
    _libraryService = LibraryService(_databaseService);
    _fileImportService = FileImportService(
      _databaseService,
      libraryService: _libraryService,
    );
    _mediaService = MediaService();
    _permissionService = PermissionService();
    _audioPlayer = AudioPlayer();
    _equalizerService = AudioEqualizerService(_audioPlayer);
    _mediaControlService = MediaControlService(_audioPlayer);

    // Initialize audio player with reactive state
    _audioPlayer.initialize().then((_) {
      // Listen to state changes for UI updates
      _audioPlayer.state.listen((state) {
        if (mounted) setState(() {});
      });

      // Listen to events for specific actions
      _audioPlayer.events.listen((event) {
        switch (event.runtimeType) {
          case SongStartedEvent:
            final songEvent = event as SongStartedEvent;
            _mediaControlService.updateMetadata();
            print('Song changed to: ${songEvent.song.title}');
            break;
          case PlaybackErrorEvent:
            final errorEvent = event as PlaybackErrorEvent;
            // Log technical error details for debugging (structured logging)
            AudioPlayerLogger.error('Playback error occurred: ${errorEvent.message}');

            // Parse error message to extract high-level reason for user
            String userMessage = 'Playback Error';
            if (errorEvent.message.startsWith('Error playing song')) {
              userMessage = 'Playback Error: Error playing song';
            } else if (errorEvent.message.startsWith('Error pausing playback')) {
              userMessage = 'Playback Error: Error pausing';
            } else if (errorEvent.message.startsWith('Error resuming playback')) {
              userMessage = 'Playback Error: Error resuming';
            } else if (errorEvent.message.startsWith('Error seeking')) {
              userMessage = 'Playback Error: Error seeking';
            } else if (errorEvent.message.startsWith('Error stopping playback')) {
              userMessage = 'Playback Error: Error stopping';
            } else if (errorEvent.message.contains('file')) {
              userMessage = 'Playback Error: File error';
            } else if (errorEvent.message.contains('platform')) {
              userMessage = 'Playback Error: Platform error';
            }

            // Show user-friendly message with error context
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Container(
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      userMessage,
                      style: TextStyle(color: ThemeColorsUtil.error),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
            break;
          // Handle other events as needed
        }
      });
    });

    _equalizerService.initialize();
    _initApp().then((_) {
      print('App initialized successfully');
      _initPlaylistState();
    }).catchError((error) {
      print('Error initializing app: $error');
    });
  }

  Future<void> _initApp() async {
    try {
      await ThemeManager().initialize();
      await _initDatabase();
      await _loadPreferences();
      await _libraryService.initializeLibrary();

      _libraryService.libraryStream.listen((library) {
        if (mounted) {
          setState(() {
            _library = library;
          });
        }
      });
      _libraryService.favoritesStream.listen((favorites) {
        if (mounted) {
          setState(() {
            _favorites = favorites;
          });
        }
      });

      _library = _libraryService.library;
      _favorites = _libraryService.favorites;
    } catch (e) {
      print('Error in _initApp: $e');
    }
  }

  Future<void> _initDatabase() async {
    await _databaseService.database;
  }

  Future<void> _loadPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _audioPlayer.toggleShuffle(); // Will implement preferences loading later
          _audioPlayer.toggleRepeat();
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _initPlaylistState() async {
    try {
      final db = await _databaseService.database;
      _playlistState = PlaylistState();
      _playlistState!.setDatabase(db);
      _playlistState!.setCallbacks(
        PlaylistCallbacks(
          addToPlaylist: (song) => _audioPlayer.addToQueue(song),
          addToPlayNext: (song, showSnackbar) => _audioPlayer.addToPlayNext(song),
          playSong: _playSong,
          clearQueue: () => _audioPlayer.clearQueue(),
          addSongsToQueue: (songs) => songs.forEach((song) => _audioPlayer.addToQueue(song)),
          showSnackBar: (message) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Container(
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      message,
                      style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
        ),
      );
      await _playlistState!.loadUserPlaylists(_library);
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing playlist state: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _prefs?.setBool('isShuffling', _audioPlayer.isShuffling);
      await _prefs?.setBool('isRepeating', _audioPlayer.isRepeating);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  Future<void> _pickFiles() async {
    await _fileImportService.importFiles(context);
  }

  Future<void> _playSong(Song song) async {
    List<Song>? context;
    switch (_selectedIndex) {
      case 0:
        context = _library.isNotEmpty ? _library : null;
        break;
      case 1:
        if (_playlistState != null && !_playlistState!.isManagingPlaylists && _playlistState!.playlist.isNotEmpty) {
          context = _playlistState!.playlist;
        }
        break;
      case 4:
        context = _favorites.isNotEmpty ? _favorites : null;
        break;
    }
    _audioPlayer.playSong(song, context: context);
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer.currentSong != null) {
      _audioPlayer.togglePlayPause();
      return;
    }
    if (_selectedIndex == 1 && _playlistState != null && !_playlistState!.isManagingPlaylists && _playlistState!.playlist.isNotEmpty) {
      _playFromIndex(_playlistState!.playlist, 0);
      return;
    }
    if (_selectedIndex == 0 && _library.isNotEmpty) {
      _playFromIndex(_library, 0);
      return;
    }
    if (_selectedIndex == 4 && _favorites.isNotEmpty) {
      _playFromIndex(_favorites, 0);
      return;
    }
    _audioPlayer.togglePlayPause();
  }

  void _playNext() => _audioPlayer.next();
  void _playPrevious() => _audioPlayer.previous();
  void _addToQueue(Song song) => _audioPlayer.addToQueue(song);
  void _addToPlayNext(Song song) => _audioPlayer.addToPlayNext(song);

  void _playFromIndex(List<Song> songs, int startIndex) {
    _audioPlayer.startPlaylist(songs, startIndex: startIndex);
  }

  Future<void> _toggleFavorite(Song song) async {
    await _libraryService.toggleFavorite(song);
  }

  Future<void> _addSelectedSongsToPlaylist(Set<Song> selectedSongs) async {
    if (_playlistState == null || selectedSongs.isEmpty) return;
    await _playlistState!.addSelectedSongsToPlaylist(selectedSongs, context, _library);
  }

  Future<void> _removeSong(Song song) async {
    await _libraryService.removeSong(song);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}" from library', style: TextStyle(color: ThemeColorsUtil.textColorPrimary)),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
    }
  }

  void _scrollToCurrentSong() {
    final currentSong = _audioPlayer.currentSong;
    if (currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No song is currently playing', style: TextStyle(color: ThemeColorsUtil.textColorPrimary)), backgroundColor: ThemeColorsUtil.surfaceColor),
      );
      return;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _libraryService.dispose();
    super.dispose();
  }

  Widget _buildPlaylist() {
    if (_playlistState != null) {
      return PlaylistWidget(
        playlistState: _playlistState!,
        addToPlaylist: (song) => _audioPlayer.addToQueue(song),
        addToPlayNext: (song, showSnackbar) => _audioPlayer.addToPlayNext(song),
        playSong: _playSong,
        playFromIndex: _playFromIndex,
        currentSong: _audioPlayer.currentSong,
        showSnackBar: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message, style: TextStyle(color: ThemeColorsUtil.textColorPrimary)), backgroundColor: ThemeColorsUtil.surfaceColor),
          );
        },
      );
    }
    return const Center(child: CircularProgressIndicator());
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ThemeColorsUtil.textColorPrimary),
        ),
        actions: [
          if (_selectedIndex == 0) ...[
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _pickFiles,
                  icon: Icon(Icons.add, color: ThemeColorsUtil.scaffoldBackgroundColor),
                  style: IconButton.styleFrom(backgroundColor: ThemeColorsUtil.primaryColor),
                  tooltip: 'Add Music',
                ),
              ),
            if (isMobile)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: ThemeColorsUtil.textColorSecondary),
                onSelected: (value) => value == 'clear' ? _clearLibrary() : null,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(children: [
                      Icon(Icons.clear_all, color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D), size: 18),
                      const SizedBox(width: 8),
                      Text('Clear Library', style: TextStyle(color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D))),
                    ]),
                  ),
                ],
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: _clearLibrary,
                  icon: Icon(Icons.clear_all, color: ThemeManager().getCurrentColors()?.error ?? const Color(0xFFCC241D)),
                  tooltip: 'Clear Library',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _pickFiles,
                  icon: Icon(Icons.add, color: ThemeColorsUtil.scaffoldBackgroundColor),
                  style: IconButton.styleFrom(backgroundColor: ThemeColorsUtil.primaryColor),
                  tooltip: 'Add Music',
                ),
              ),
            ],
          ],
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: ThemeColorsUtil.textColorPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      // BEAUTIFUL BLURRED TRANSPARENT DRAWER
     drawer: SizedBox(
  width: isMobile ? 280.0 : 300.0, // Slightly wider looks better with blur
  child: Drawer(
    backgroundColor: Colors.transparent, // Important!
    elevation: 0,
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // Blur intensity
        child: Container(
          decoration: BoxDecoration(
            color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(0.4), // Semi-transparent
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeColorsUtil.appBarBackgroundColor.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Tunes4R',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ThemeColorsUtil.textColorPrimary,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _buildDrawerItem(Icons.library_music, 'Library', 0),
                      _buildDrawerItem(Icons.playlist_play, 'Playlist', 1),
                      _buildDrawerItem(Icons.play_circle, 'Now Playing', 2),
                      _buildDrawerItem(Icons.album, 'Albums', 3),
                      _buildDrawerItem(Icons.favorite, 'Favorites', 4),
                      _buildDrawerItem(Icons.cloud_download, 'Download', 5),
                      _buildDrawerItem(Icons.settings, 'Settings', 6),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Made by Silverio / Qualitas',
                          style: TextStyle(
                            color: ThemeColorsUtil.textColorSecondary.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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
    ),
  ),
),

      body: Column(
        children: [
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
                          SnackBar(content: Text(message, style: TextStyle(color: ThemeColorsUtil.textColorPrimary)), backgroundColor: ThemeColorsUtil.surfaceColor),
                        );
                      }
                    },
                    onToggleFavorite: _toggleFavorite,
                    onRemoveSong: _removeSong,
                    onPickFiles: _pickFiles,
                    onClearLibrary: _clearLibrary,
                    onSongsSelected: _addSelectedSongsToPlaylist,
                    currentSong: _audioPlayer.currentSong,
                  )
                : _selectedIndex == 1
                    ? _buildPlaylist()
                    : _selectedIndex == 2
                        ? NowPlayingTab(
                            playbackManager: _audioPlayer,
                            onTogglePlayPause: _togglePlayPause,
                            onPlayNext: _playNext,
                            onPlayPrevious: _playPrevious,
                          )
                        : _selectedIndex == 3
                            ? AlbumsTab(library: _library, onPlaySong: _playSong, playbackManager: _audioPlayer)
                            : _selectedIndex == 4
                                ? FavoritesTab(favorites: _favorites, onPlaySong: _playSong, onAddToQueue: _addToQueue, playbackManager: _audioPlayer)
                                : _selectedIndex == 5
                                    ? DownloadTab()
                                    : _selectedIndex == 6
                                        ? SettingsTab()
                                        : const Placeholder(),
          ),
          MusicPlayerControls(
            playbackManager: _audioPlayer,
            equalizerService: _equalizerService,
            onSavePreferences: _savePreferences,
            onTogglePlayPause: _togglePlayPause,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? ThemeColorsUtil.primaryColor.withOpacity(0.35) : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: ThemeColorsUtil.primaryColor.withOpacity(0.5), width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              size: 24,
              shadows: isSelected ? [const Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))] : null,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.95),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
                shadows: isSelected ? [const Shadow(blurRadius: 6, color: Colors.black38)] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearLibrary() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorsUtil.surfaceColor,
        title: Text('Clear Library', style: TextStyle(color: ThemeColorsUtil.textColorPrimary)),
        content: Text('Are you sure you want to delete all songs from your library?\n\nThis action cannot be undone.', style: TextStyle(color: ThemeColorsUtil.textColorSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: ThemeColorsUtil.error), child: const Text('Clear Library')),
        ],
      ),
    );

    if (result == true) {
      try {
        await _libraryService.clearLibrary();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Library cleared successfully!', style: TextStyle(color: ThemeColorsUtil.textColorPrimary)), backgroundColor: ThemeColorsUtil.surfaceColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing library: $e', style: TextStyle(color: ThemeColorsUtil.textColorPrimary)), backgroundColor: ThemeColorsUtil.error),
        );
      }
    }
  }
}
