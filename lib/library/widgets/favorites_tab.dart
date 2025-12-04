import 'package:flutter/material.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/library/library.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class FavoritesTab extends StatelessWidget {
  final Library libraryContext;
  final PlaybackManager playbackManager;

  const FavoritesTab({
    super.key,
    required this.libraryContext,
    required this.playbackManager,
  });

  // Get favorites from Library BC - no external dependencies
  List<Song> get favorites => libraryContext.favorites;

  /// Owns favorites playback context
  void _playSongFromFavorites(Song song) {
    playbackManager.playSong(song, context: favorites);
  }

  void _addSongToQueue(Song song) {
    playbackManager.addToQueue(song);
  }

  @override
  Widget build(BuildContext context) {
    return favorites.isEmpty
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
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final song = favorites[index];
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
                      onPressed: () => _playSongFromFavorites(song),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_to_queue,
                        color: ThemeColorsUtil.textColorSecondary,
                      ),
                      onPressed: () => _addSongToQueue(song),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
