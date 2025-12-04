import 'package:tunes4r/models/song.dart';

/// Domain events emitted by the Library bounded context
abstract class LibraryEvent {
  const LibraryEvent();
}

/// Base command interface for Library bounded context
abstract class LibraryCommand {
  const LibraryCommand();
}

/// Command to initialize/load the library and favorites
class InitializeLibraryCommand extends LibraryCommand {}

/// Command to save a song to the library
class SaveSongCommand extends LibraryCommand {
  final Song song;
  const SaveSongCommand(this.song);
}

/// Command to remove a song from the library
class RemoveSongCommand extends LibraryCommand {
  final Song song;
  const RemoveSongCommand(this.song);
}

/// Command to clear all songs from the library
class ClearLibraryCommand extends LibraryCommand {}

/// Command to toggle favorite status for a song
class ToggleFavoriteCommand extends LibraryCommand {
  final Song song;
  const ToggleFavoriteCommand(this.song);
}

/// Command to search songs by query
class SearchSongsCommand extends LibraryCommand {
  final String query;
  const SearchSongsCommand(this.query);
}

/// Command to clear search and show all songs
class ClearSearchCommand extends LibraryCommand {}

/// Command to start selection mode for playlist operations
class StartSelectionCommand extends LibraryCommand {
  final Song initialSong;
  const StartSelectionCommand(this.initialSong);
}

/// Command to toggle selection of a song in selection mode
class ToggleSelectionCommand extends LibraryCommand {
  final Song song;
  const ToggleSelectionCommand(this.song);
}

/// Command to select all songs in selection mode
class SelectAllCommand extends LibraryCommand {}

/// Command to deselect all songs in selection mode
class DeselectAllCommand extends LibraryCommand {}

/// Command to finish selection and get selected songs
class FinishSelectionCommand extends LibraryCommand {}

/// Events emitted by the Library bounded context
class SongSavedEvent extends LibraryEvent {
  final Song song;
  const SongSavedEvent(this.song);
}

class SongRemovedEvent extends LibraryEvent {
  final Song song;
  const SongRemovedEvent(this.song);
}

class LibraryClearedEvent extends LibraryEvent {}

class FavoriteToggledEvent extends LibraryEvent {
  final Song song;
  final bool isFavorite;
  const FavoriteToggledEvent(this.song, this.isFavorite);
}

class SearchResultsEvent extends LibraryEvent {
  final List<Song> results;
  final String query;
  const SearchResultsEvent(this.results, this.query);
}

class SelectionModeChangedEvent extends LibraryEvent {
  final bool isActive;
  final Set<Song> selectedSongs;
  const SelectionModeChangedEvent(this.isActive, this.selectedSongs);
}

class LibraryErrorEvent extends LibraryEvent {
  final String userMessage;
  final String technicalDetails;
  const LibraryErrorEvent(this.userMessage, this.technicalDetails);
}

/// Event emitted when multiple files are imported at once
class FilesImportedEvent extends LibraryEvent {
  final int importedCount;
  const FilesImportedEvent(this.importedCount);
}
