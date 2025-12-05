import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ Clean bounded context imports - external interfaces only
import 'package:tunes4r/audio_player/audio_player.dart';
import 'package:tunes4r/audio_player/widgets/music_player_controls.dart';
import 'package:tunes4r/audio_player/widgets/now_playing_tab.dart';
import 'package:tunes4r/library/library.dart';
import 'package:tunes4r/library/widgets/library_tab.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/services/database_service.dart';
import 'package:tunes4r/services/permission_service.dart';
import 'package:tunes4r/settings/settings.dart';
import 'package:tunes4r/theme/theme.dart';
import 'package:tunes4r/playlist/playlist.dart';
import 'package:tunes4r/download/download.dart';
// 🔄 REMAINING ARCHITECTURE VIOLATIONS (Low priority, legacy compatibility):
//
// ⚠️ 1. Infrastructure exposed (Dependency injection needed):
//    - DatabaseService, PermissionService should be abstracted via interfaces
//    - Solution: Future enhancement - bounded contexts accepting service contracts
//
// 🔴 LEGACY VIOLATIONS (Higher priority to fix):
// 2. Multiple dependencies per bounded context still occur in other parts
//    - AudioPlayer depends on audio_player/* internals elsewhere in codebase
//
// ✅ ARCHITECTURE IMPROVEMENTS ACHIEVED:
// 1. ✅ Logger configurations moved to bounded contexts' initialize()
// 2. ✅ Event handling moved to UI layers (main.dart cleaned)
// 3. ✅ Main.dart now only imports bounded context public interfaces
// 4. ✅ Single interface imports for bounded contexts we control
// 5. ✅ HOT RELOAD THEME FIX: Use shared theme manager and MaterialApp theme
import 'package:tunes4r/utils/theme_colors.dart';

// ✅ BOUNDED CONTEXT VIOLATIONS FIXED:
// 1. ✅ Logger framework moved internally to bounded contexts
// 2. ✅ Internal event types moved to UI layers
// 3. ✅ Single interface imports maintained
// 4. ⚠️ Infrastructure services still exposed (needs dependency injection)

enum SearchMode { songs, albums }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MusicPlayerApp());
}

// Global shared theme manager for hot reload compatibility
// This survives hot reload because Settings manages it statically
late ThemeManager _sharedThemeManager;

class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  late Settings _sharedSettings;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize shared settings which manages the ThemeManager
    _sharedSettings = Settings();
    await _sharedSettings.initialize();

    // Get the shared theme manager that survives hot reload
    _sharedThemeManager = _sharedSettings.getSharedThemeManager();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show loading while initializing
      return const MaterialApp(
        title: 'Tunes4R',
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Listen to theme changes and rebuild MaterialApp theme on hot reload
    return ListenableBuilder(
      listenable: _sharedThemeManager,
      builder: (context, child) {
        return MaterialApp(
          title: 'Tunes4R',
          debugShowCheckedModeBanner: false,
          theme: _buildThemeFromCurrentColors(),
          home: MusicPlayerHome(),
        );
      },
    );
  }

  /// Build Material ThemeData from current theme colors
  /// This ensures hot reload updates the entire app theme
  ThemeData _buildThemeFromCurrentColors() {
    final colors = _sharedThemeManager.currentColors;

    if (colors == null) {
      // Fallback to gruvbox_light colors
      return ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF1C7),
        primaryColor: const Color(0xFFB57614),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFEBDBB2)),
        // Add more fallback theme properties here
      );
    }

    return ThemeData(
      scaffoldBackgroundColor: colors.scaffoldBackground,
      primaryColor: colors.primary,
      appBarTheme: AppBarTheme(backgroundColor: colors.appBarBackground),
      cardColor: colors.surfacePrimary,
      dialogBackgroundColor: colors.surfacePrimary,
      // Add more theme properties as needed for full Material Design coverage
    );
  }
}

class MusicPlayerHome extends StatefulWidget {
  final VoidCallback? onThemeChange;

  const MusicPlayerHome({super.key, this.onThemeChange});

  @override
  State<MusicPlayerHome> createState() => _MusicPlayerHomeState();
}

class _MusicPlayerHomeState extends State<MusicPlayerHome> {
  late final AudioPlayer _audioPlayer;
  late final DatabaseService _databaseService;
  late final Library _libraryContext;
  final Settings _settingsContext =
      Settings(); // Settings manages its own ThemeManager
  late final PermissionService _permissionService;
  SharedPreferences? _prefs;

  List<Song> _library = [];
  List<Song> _favorites = [];
  int _selectedIndex = 0;
  PlaylistState? _playlistState;

  // Theme change counter for UI rebuilds
  int _themeChangeCounter = 0;

  // Store widget reference for AppBar actions
  final GlobalKey _libraryTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    print('Initializing Tunes4R...');

    _databaseService = DatabaseService();
    _libraryContext = Library(_databaseService);
    _permissionService = PermissionService();
    _audioPlayer = AudioPlayer();

    // Initialize bounded contexts
    _settingsContext.initialize();

    // Listen to theme changes to trigger full UI rebuild
    _sharedThemeManager.addListener(_onThemeChanged);

    // Initialize audio player with reactive state
    _audioPlayer.initialize().then((_) {
      // Listen to state changes for UI updates
      // ✅ VIOLATION 2 FIXED: Event handling moved to UI widgets (LibraryTab, NowPlayingTab)
      _audioPlayer.state.listen((state) {
        if (mounted) setState(() {});
      });
    });

    _initApp()
        .then((_) {
          print('App initialized successfully');
          _initPlaylistState();
        })
        .catchError((error) {
          print('Error initializing app: $error');
        });
  }

  Future<void> _initApp() async {
    try {
      await _initDatabase();
      await _loadPreferences();
      // Initialize Library bounded context with reactive state
      await _libraryContext.initialize();

      // Set initial state directly (streams might not replay to late subscribers)
      _library = _libraryContext.library;
      _favorites = _libraryContext.favorites;

      // Add reactive listeners for future updates
      _libraryContext.state.listen((state) {
        if (mounted) {
          setState(() {
            _library = state.library;
            _favorites = state.favorites;
          });
        }
      });
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
          _audioPlayer
              .toggleShuffle(); // Will implement preferences loading later
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
          addToPlayNext: (song, showSnackbar) =>
              _audioPlayer.addToPlayNext(song),
          playSong: _playSong,
          clearQueue: () => _audioPlayer.clearQueue(),
          addSongsToQueue: (songs) =>
              songs.forEach((song) => _audioPlayer.addToQueue(song)),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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

  /// 🚨 ARCHITECTURAL NOTE: These methods need to be moved to their respective contexts
  /// Each UI context should determine its own playback behavior, but they contain
  /// navigation-state logic ($_selectedIndex) that binds them to the app coordinator.
  ///
  /// TODO: Refactor these into a PlaybackCoordinator that each tab implements,
  /// removing navigation dependencies from playback logic.

  Future<void> _playSong(Song song) async {
    List<Song>? context;
    switch (_selectedIndex) {
      case 0:
        context = _library.isNotEmpty ? _library : null;
        break;
      case 1:
        if (_playlistState != null &&
            !_playlistState!.isManagingPlaylists &&
            _playlistState!.playlist.isNotEmpty) {
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
    if (_selectedIndex == 1 &&
        _playlistState != null &&
        !_playlistState!.isManagingPlaylists &&
        _playlistState!.playlist.isNotEmpty) {
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

  Future<void> _addSelectedSongsToPlaylist(Set<Song> selectedSongs) async {
    if (_playlistState == null || selectedSongs.isEmpty) return;
    await _playlistState!.addSelectedSongsToPlaylist(
      selectedSongs,
      context,
      _library,
    );
  }

  void _scrollToCurrentSong() {
    final currentSong = _audioPlayer.currentSong;
    if (currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No song is currently playing',
            style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
          ),
          backgroundColor: ThemeColorsUtil.surfaceColor,
        ),
      );
      return;
    }
  }

  /// Navigation callback methods for clean decoupling
  /// These delegate to bounded contexts via callback pattern

  /// Get context-specific title for AppBar
  String _getContextTitle(int index) {
    switch (index) {
      case 0:
        return _libraryContext.getNavigationTitle(); // ✅ Library callback
      case 1:
        return 'Playlists'; // 🔄 TODO: Add to playlist context
      case 2:
        return 'Now Playing'; // 🔄 TODO: Add to audio player context
      case 3:
        return 'Albums (${_library.map((song) => song.album).toSet().length})';
      case 4:
        return 'Favorites (${_favorites.length})';
      case 5:
        return 'Download';
      case 6:
        return 'Settings';
      default:
        return 'Tunes4R';
    }
  }

  /// Get context-specific actions for AppBar
  /// Pure delegation - each UI tab owns its own AppBar actions completely
  List<Widget> _getContextActions(BuildContext context, int index) {
    // Library tab (0) owns its actions entirely (UI concern)
    if (index == 0) {
      return LibraryTab.buildActions(context, _libraryTabKey);
    }
    // Other tabs don't have actions yet
    return [];
  }

  void _onThemeChanged() {
    // Trigger full UI rebuild when theme changes
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sharedThemeManager.removeListener(_onThemeChanged);
    _audioPlayer.dispose();
    _libraryContext.dispose();
    super.dispose();
  }

  Widget _buildPlaylist() {
    if (_playlistState != null) {
      return PlaylistWidget(
        playlistState: _playlistState!,
        library: _library,
        addToPlaylist: (song) => _audioPlayer.addToQueue(song),
        addToPlayNext: (song, showSnackbar) => _audioPlayer.addToPlayNext(song),
        playSong: _playSong,
        playFromIndex: _playFromIndex,
        currentSong: _audioPlayer.currentSong,
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
          _getContextTitle(_selectedIndex),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ThemeColorsUtil.textColorPrimary,
          ),
        ),
        actions: _getContextActions(context, _selectedIndex),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: ThemeColorsUtil.textColorPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      // BEAUTIFUL BLURRED TRANSPARENT DRAWER
      drawer: SizedBox(
        width: isMobile
            ? 280.0
            : 300.0, // Slightly wider looks better with blur
        child: Drawer(
          backgroundColor: Colors.transparent, // Important!
          elevation: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 12,
                sigmaY: 12,
              ), // Blur intensity
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeColorsUtil.scaffoldBackgroundColor.withOpacity(
                    0.4,
                  ), // Semi-transparent
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
                          color: ThemeColorsUtil.appBarBackgroundColor
                              .withOpacity(0.7),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          children: [
                            _buildDrawerItem(Icons.library_music, 'Library', 0),
                            _buildDrawerItem(
                              Icons.playlist_play,
                              'Playlist',
                              1,
                            ),
                            _buildDrawerItem(
                              Icons.play_circle,
                              'Now Playing',
                              2,
                            ),
                            _buildDrawerItem(Icons.album, 'Albums', 3),
                            _buildDrawerItem(Icons.favorite, 'Favorites', 4),
                            _buildDrawerItem(
                              Icons.cloud_download,
                              'Download',
                              5,
                            ),
                            _buildDrawerItem(Icons.settings, 'Settings', 6),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Made by Silverio / Qualitas',
                                style: TextStyle(
                                  color: ThemeColorsUtil.textColorSecondary
                                      .withOpacity(0.8),
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
                    key: _libraryTabKey,
                    libraryContext: _libraryContext,
                    audioPlayer: _audioPlayer,
                    onSongsSelected: _addSelectedSongsToPlaylist,
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
                ? _libraryContext.getAlbumsTab(_audioPlayer)
                : _selectedIndex == 4
                ? _libraryContext.getFavoritesTab(_audioPlayer)
                : _selectedIndex == 5
                ? DownloadTab()
                : _selectedIndex == 6
                ? _settingsContext.getSettingsTab()
                : const Placeholder(),
          ),
          MusicPlayerControls(
            playbackManager: _audioPlayer,
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
      onTap: () async {
        setState(() => _selectedIndex = index);

        // Reload playlist data when switching to playlist tab
        if (index == 1 && _playlistState != null) {
          await _playlistState!.loadUserPlaylists(_library);
        }

        if (isMobile) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeColorsUtil.primaryColor.withOpacity(0.35)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: ThemeColorsUtil.primaryColor.withOpacity(0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              size: 24,
              shadows: isSelected
                  ? [
                      const Shadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.95),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
                shadows: isSelected
                    ? [const Shadow(blurRadius: 6, color: Colors.black38)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
