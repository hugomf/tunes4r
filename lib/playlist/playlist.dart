// Playlist Bounded Context
//
// This module contains all functionality related to playlist management:
// - Playlist creation, editing, deletion
// - Playlist import from various file formats (M3U, PLS)
// - Song-to-playlist matching and adding
// - Playlist persistence and querying
//
// Public API exports for the Playlist bounded context.

// Models
export 'models/playlist.dart';
export 'models/playlist_import.dart';

// Services
export 'services/playlist_repository.dart';
export 'services/playlist_import_service.dart';
export 'services/playlist_parser.dart';

// Widgets (UI components)
export 'widgets/playlist_state.dart';
export 'widgets/playlist_widget.dart';
