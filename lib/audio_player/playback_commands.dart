import '../../models/song.dart';
import 'playback_state.dart';

/// Base class for all playback commands that can change state
abstract class PlaybackCommand {
  const PlaybackCommand();
}

/// Song playback commands
class PlaySongCommand extends PlaybackCommand {
  final Song song;
  final List<Song>? context; // Optional playlist context

  const PlaySongCommand(this.song, {this.context});
}

class PauseCommand extends PlaybackCommand {
  const PauseCommand();
}

class ResumeCommand extends PlaybackCommand {
  const ResumeCommand();
}

class StopCommand extends PlaybackCommand {
  const StopCommand();
}

class TogglePlayPauseCommand extends PlaybackCommand {
  const TogglePlayPauseCommand();
}

class SeekToCommand extends PlaybackCommand {
  final Duration position;

  const SeekToCommand(this.position);
}

/// Queue management commands
class AddToQueueCommand extends PlaybackCommand {
  final Song song;

  const AddToQueueCommand(this.song);
}

class AddToPlayNextCommand extends PlaybackCommand {
  final Song song;

  const AddToPlayNextCommand(this.song);
}

class ClearQueueCommand extends PlaybackCommand {
  const ClearQueueCommand();
}

class RemoveFromQueueCommand extends PlaybackCommand {
  final Song song;

  const RemoveFromQueueCommand(this.song);
}

/// Playlist commands
class StartPlaylistCommand extends PlaybackCommand {
  final List<Song> playlist;
  final int startIndex;

  const StartPlaylistCommand(this.playlist, {this.startIndex = 0});
}

class EndPlaylistCommand extends PlaybackCommand {
  const EndPlaylistCommand();
}

class NextSongCommand extends PlaybackCommand {
  const NextSongCommand();
}

class PreviousSongCommand extends PlaybackCommand {
  const PreviousSongCommand();
}

/// Playback mode commands
class ToggleShuffleCommand extends PlaybackCommand {
  const ToggleShuffleCommand();
}

class ToggleRepeatCommand extends PlaybackCommand {
  const ToggleRepeatCommand();
}

/// Equalizer commands
class SetEqualizerEnabledCommand extends PlaybackCommand {
  final bool enabled;

  const SetEqualizerEnabledCommand(this.enabled);
}

class ApplyEqualizerBandsCommand extends PlaybackCommand {
  final List<double> bands;

  const ApplyEqualizerBandsCommand(this.bands);
}

class ResetEqualizerCommand extends PlaybackCommand {
  const ResetEqualizerCommand();
}

/// Advanced commands
class SetPlaybackSpeedCommand extends PlaybackCommand {
  final double speed;

  const SetPlaybackSpeedCommand(this.speed);
}

class LoadSongCommand extends PlaybackCommand {
  final Song song;

  const LoadSongCommand(this.song);
}

/// Domain events that represent significant state changes
/// These are published for inter-bounded-context communication
abstract class PlaybackEvent {
  const PlaybackEvent();

  DateTime get timestamp => DateTime.now();
}

/// Events for external observers
class SongStartedEvent extends PlaybackEvent {
  final Song song;
  final List<Song>? playlist;

  const SongStartedEvent(this.song, {this.playlist});
}

class SongCompletedEvent extends PlaybackEvent {
  final Song song;
  final Song? nextSong;

  const SongCompletedEvent(this.song, {this.nextSong});
}

class PlaybackStateChangedEvent extends PlaybackEvent {
  final PlaybackStatus oldStatus;
  final PlaybackStatus newStatus;

  const PlaybackStateChangedEvent(this.oldStatus, this.newStatus);
}

class QueueChangedEvent extends PlaybackEvent {
  final List<Song> queue;
  final QueueChangeType changeType;
  final Song? affectedSong;

  const QueueChangedEvent(this.queue, this.changeType, {this.affectedSong});
}

class PlaylistChangedEvent extends PlaybackEvent {
  final List<Song>? playlist;
  final bool hasEnded;

  const PlaylistChangedEvent(this.playlist, {this.hasEnded = false});
}

class PlaybackModeChangedEvent extends PlaybackEvent {
  final bool shuffleEnabled;
  final bool repeatEnabled;

  const PlaybackModeChangedEvent(this.shuffleEnabled, this.repeatEnabled);
}

class EqualizerChangedEvent extends PlaybackEvent {
  final bool enabled;
  final List<double>? bands;

  const EqualizerChangedEvent(this.enabled, {this.bands});
}

class PlaybackErrorEvent extends PlaybackEvent {
  final String message;
  final PlaybackErrorType type;

  const PlaybackErrorEvent(this.message, this.type);
}

/// Helper types
enum QueueChangeType {
  added,
  removed,
  cleared,
  reordered,
}
