import 'package:flutter/material.dart';
import 'package:tunes4r/models/playlist.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/utils/theme_colors.dart';
import 'package:tunes4r/widgets/playlist_state.dart';

class PlaylistWidget extends StatelessWidget {
  final PlaylistState playlistState;
  final Function(Song song) addToPlaylist;
  final Function(Song song, bool showSnackbar) addToPlayNext;
  final Function(Song song) playSong;
  final Function(String message) showSnackBar;

  const PlaylistWidget({
    Key? key,
    required this.playlistState,
    required this.addToPlaylist,
    required this.addToPlayNext,
    required this.playSong,
    required this.showSnackBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playlistState,
      builder: (context, child) {
        // Playlist Management View
        if (playlistState.isManagingPlaylists) {
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
                          await playlistState.createPlaylist(result);
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
                      onTap: () => playlistState.showPlaylistImportDialog(context, []),
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
                          final bool isActive = playlistState.currentPlaylist == playlist;
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
                                      await playlistState.loadPlaylist(playlist);
                                      playlistState.setManagingPlaylists(false);
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
                                        await playlistState.loadPlaylist(playlist);
                                        playlistState.setManagingPlaylists(false);
                                        break;
                                      case 'delete':
                                        await playlistState.deletePlaylist(playlist, context);
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
                      onPressed: () => playlistState.setManagingPlaylists(true),
                      tooltip: 'Back to Playlists',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlistState.currentPlaylist?.name ?? 'Current Playlist',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeColorsUtil.textColorPrimary,
                            ),
                          ),
                          Text(
                            '${playlistState.playlist.length} ${playlistState.playlist.length == 1 ? 'song' : 'songs'}',
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
                          playlistState.reorderPlaylist(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final song = playlistState.playlist[index];
                          bool isCurrent = false; // This will need to be passed from main state
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
                                  onPressed: () => playlistState.removeFromPlaylist(song),
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
      },
    );
  }
}
