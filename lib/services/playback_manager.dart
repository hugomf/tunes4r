/// Legacy class for backward compatibility
/// AudioPlayer now provides the PlaybackManager interface

import 'package:tunes4r/audio_player/audio_player.dart';

// Export AudioPlayer as the main class
export '../audio_player/audio_player.dart';

// AudioPlayer provides the PlaybackManager interface
typedef PlaybackManager = AudioPlayer;
