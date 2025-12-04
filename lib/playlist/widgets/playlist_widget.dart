import 'package:flutter/material.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/playlist/models/playlist.dart';
import 'package:tunes4r/playlist/widgets/playlist_state.dart';

class PlaylistWidget extends StatelessWidget {
  final PlaylistState playlistState;
  final Function(Song song) addToPlaylist;
  final Function(Song song, bool showSnackbar) addToPlayNext;
  final Function(Song song) playSong;
  final Function(List<Song> songs, int startIndex) playFromIndex;
  final Function(String message) showSnackBar;
  final Song? currentSong; // Currently playing song for visual feedback

  /// Public playback methods - each UI context knows its own playlist
  void contextPlaySong(Song song) {
    // If we have a current playlist, play with its context
    if (playlistState.playlist.isNotEmpty) {
      final context = playlistState.playlist;
      playSong(song); // Call the callback
    } else {
      // Fallback - just play the song without context
      playSong(song);
    }
  }

  Future<void> contextTogglePlayPause() async {
    // If nothing is playing and we have a playlist, start from the beginning
    if (currentSong == null && playlistState.playlist.isNotEmpty) {
      playFromIndex(playlistState.playlist, 0);
    }
    // Otherwise, just toggle (this would be handled by the controls)
    // Note: This would typically be handled by the MusicPlayerControls widget
  }

  const PlaylistWidget({
    super.key,
    required this.playlistState,
    required this.addToPlaylist,
    required this.addToPlayNext,
    required this.playSong,
    required this.playFromIndex,
    required this.showSnackBar,
    required this.currentSong,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playlistState,
      builder: (context, child) {
        // Playlist Management View
        if (playlistState.isManagingPlaylists) {
          return Container(
            color: ThemeColorsUtil.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Create New Playlist Button and Import Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Create New Playlist - Floating-style Icon Button
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: "create_playlist",
                              backgroundColor: ThemeColorsUtil.primaryColor,
                              elevation: 6,
                              onPressed: () async {
                                final TextEditingController controller =
                                    TextEditingController();
                                final result = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor:
                                        ThemeColorsUtil.surfaceColor,
                                    title: Text(
                                      'Create Playlist',
                                      style: TextStyle(
                                        color: ThemeColorsUtil.textColorPrimary,
                                      ),
                                    ),
                                    content: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        hintText: 'Enter playlist name',
                                        hintStyle: TextStyle(
                                          color: ThemeColorsUtil
                                              .textColorSecondary,
                                        ),
                                      ),
                                      autofocus: true,
                                      style: TextStyle(
                                        color: ThemeColorsUtil.textColorPrimary,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: ThemeColorsUtil
                                                .textColorSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final name = controller.text.trim();
                                          if (name.isNotEmpty)
                                            Navigator.of(context).pop(name);
                                        },
                                        child: Text(
                                          'Create',
                                          style: TextStyle(
                                            color: ThemeColorsUtil.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != null && result.isNotEmpty) {
                                  await playlistState.createPlaylist(result);
                                }
                              },
                              child: Icon(
                                Icons.add,
                                color: ThemeColorsUtil.iconPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'New Playlist',
                              style: TextStyle(
                                color: ThemeColorsUtil.textColorSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 32),

                      // Import Playlist - Secondary style
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: "import_playlist",
                              backgroundColor: ThemeColorsUtil.secondary,
                              elevation: 6,
                              onPressed: () => playlistState
                                  .showPlaylistImportDialog(context, []),
                              child: Icon(
                                Icons.file_upload,
                                color: ThemeColorsUtil.iconPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Import',
                              style: TextStyle(
                                color: ThemeColorsUtil.textColorSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Playlists List
                Expanded(
                  child: playlistState.userPlaylists.isEmpty
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
                          itemCount: playlistState.userPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlistState.userPlaylists[index];
                            final bool isActive =
                                playlistState.currentPlaylist == playlist;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? ThemeColorsUtil.primaryColor.withOpacity(
                                        0.1,
                                      )
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
                                        await playlistState.loadPlaylist(
                                          playlist,
                                        );
                                        playlistState.setManagingPlaylists(
                                          false,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.playlist_play,
                                              color: isActive
                                                  ? ThemeColorsUtil.primaryColor
                                                  : ThemeColorsUtil
                                                        .textColorSecondary,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    playlist.name,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: isActive
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isActive
                                                          ? ThemeColorsUtil
                                                                .primaryColor
                                                          : ThemeColorsUtil
                                                                .textColorPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${playlist.songs.length} ${playlist.songs.length == 1 ? 'song' : 'songs'}',
                                                    style: TextStyle(
                                                      color: isActive
                                                          ? ThemeColorsUtil
                                                                .primaryColor
                                                                .withOpacity(
                                                                  0.8,
                                                                )
                                                          : ThemeColorsUtil
                                                                .textColorSecondary,
                                                    ),
                                                  ),
                                                  if (isActive) ...[
                                                    Text(
                                                      'Currently loaded',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: ThemeColorsUtil
                                                            .primaryColor,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                          await playlistState.loadPlaylist(
                                            playlist,
                                          );
                                          playlistState.setManagingPlaylists(
                                            false,
                                          );
                                          break;
                                        case 'delete':
                                          await playlistState.deletePlaylist(
                                            playlist,
                                            context,
                                          );
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
                                        color:
                                            ThemeColorsUtil.textColorSecondary,
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
            ),
          );
        }
        // Individual Playlist Editing View
        else {
          return Scaffold(
            backgroundColor: ThemeColorsUtil.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
              elevation: 0,
              title: Row(
                children: [
                  Text(
                    '${playlistState.playlist.length} ${playlistState.playlist.length == 1 ? 'song' : 'songs'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeColorsUtil.textColorSecondary,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: 130, // Same width as library icons
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: ThemeColorsUtil.primaryColor,
                          size: 18,
                        ),
                        onPressed: () async {
                          // Import playlist functionality
                          await playlistState.showPlaylistImportDialog(
                            context,
                            [],
                          );
                        },
                        tooltip: 'Import Playlist',
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: Icon(
                          Icons.playlist_add,
                          color: ThemeColorsUtil.secondary,
                          size: 18,
                        ),
                        onPressed: () async {
                          // Add songs to this playlist from library
                          // This would need to be implemented
                          showSnackBar(
                            'Add songs functionality - coming soon!',
                          );
                        },
                        tooltip: 'Add Songs',
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            color: ThemeColorsUtil.textColorSecondary,
                            size: 18,
                          ),
                          tooltip: 'More Options',
                          onSelected: (String value) {
                            switch (value) {
                              case 'clear':
                                playlistState.clearCurrentPlaylist();
                                break;
                              case 'delete':
                                if (playlistState.currentPlaylist != null) {
                                  playlistState.deletePlaylist(
                                    playlistState.currentPlaylist!,
                                    context,
                                  );
                                }
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'clear',
                                  child: Row(
                                    children: [
                                      Icon(Icons.clear_all, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Clear Playlist'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Delete Playlist'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: ThemeColorsUtil.textColorPrimary,
                ),
                onPressed: () => playlistState.setManagingPlaylists(true),
                tooltip: 'Back to Playlists',
              ),
            ),

            // Body uses theme background with proper container wrapping for the list
            body: Container(
              color: ThemeColorsUtil.scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Playlist Name Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: ThemeColorsUtil.surfaceColor,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlistState.currentPlaylist?.name ??
                                'Current Playlist',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ThemeColorsUtil.textColorPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Playlist Content with explicitly themed background
                  Expanded(
                    child: Container(
                      color: ThemeColorsUtil.scaffoldBackgroundColor,
                      child: playlistState.playlist.isEmpty
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
                              itemCount: playlistState.playlist.length,
                              onReorder: (oldIndex, newIndex) {
                                playlistState.reorderPlaylist(
                                  oldIndex,
                                  newIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final song = playlistState.playlist[index];
                                final bool isCurrent =
                                    currentSong != null &&
                                    song.path == currentSong!.path;
                                return GestureDetector(
                                  key: ValueKey(song.path),
                                  onDoubleTap: () => playFromIndex(
                                    playlistState.playlist,
                                    index,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? ThemeColorsUtil.primaryColor
                                                .withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? ThemeColorsUtil.primaryColor
                                                    .withOpacity(0.2)
                                              : ThemeColorsUtil.surfaceColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: isCurrent
                                              ? Border.all(
                                                  color: ThemeColorsUtil
                                                      .primaryColor,
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                        child: song.albumArt != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Stack(
                                                  children: [
                                                    Image.memory(
                                                      song.albumArt!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                    ),
                                                    if (isCurrent)
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color: ThemeColorsUtil
                                                              .primaryColor
                                                              .withOpacity(0.7),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.volume_up,
                                                          color: ThemeColorsUtil
                                                              .surfaceColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              )
                                            : Icon(
                                                Icons.music_note,
                                                size: 20,
                                                color: isCurrent
                                                    ? ThemeColorsUtil
                                                          .surfaceColor
                                                    : ThemeColorsUtil
                                                          .primaryColor,
                                              ),
                                      ),
                                      title: Text(
                                        song.title,
                                        style: TextStyle(
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCurrent
                                              ? ThemeColorsUtil.primaryColor
                                              : ThemeColorsUtil
                                                    .textColorPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        song.artist,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? ThemeColorsUtil.primaryColor
                                                    .withOpacity(0.8)
                                              : ThemeColorsUtil
                                                    .textColorSecondary,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrent) ...[
                                            Icon(
                                              Icons.volume_up,
                                              color:
                                                  ThemeColorsUtil.primaryColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          IconButton(
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: ThemeColorsUtil.error,
                                            ),
                                            onPressed: () => playlistState
                                                .removeFromPlaylist(
                                                  song,
                                                  currentSong: currentSong,
                                                ),
                                            tooltip: 'Remove from playlist',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
