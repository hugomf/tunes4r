import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../services/playback_manager.dart';
import '../../utils/theme_colors.dart';

class AlbumsTab extends StatefulWidget {
  final List<Song> library;
  final Function(Song) onPlaySong;
  final PlaybackManager playbackManager;

  const AlbumsTab({
    super.key,
    required this.library,
    required this.onPlaySong,
    required this.playbackManager,
  });

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab> {
  int get albumCount {
    return widget.library.map((song) => song.album).toSet().length;
  }

  List<String> get albums {
    return widget.library.map((song) => song.album).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final albums = this.albums;

    return albums.isEmpty
        ? Center(
            child: Text(
              '📀 No albums in your library yet.\nAdd some music with album metadata.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeColorsUtil.textColorSecondary,
                fontSize: 16,
              ),
            ),
          )
        : ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Albums ($albumCount)',
                  style: TextStyle(
                    color: ThemeColorsUtil.textColorPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final albumName = albums[index];
                  final albumSongs = widget.library.where((song) => song.album == albumName).toList();
                  final firstSongWithArt = albumSongs.firstWhere(
                    (song) => song.albumArt != null,
                    orElse: () => albumSongs.first,
                  );

                  return GestureDetector(
                    onTap: () => _navigateToAlbum(albumName, albumSongs),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ThemeColorsUtil.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                gradient: firstSongWithArt.albumArt != null
                                    ? null
                                    : LinearGradient(
                                        colors: ThemeColorsUtil.albumGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                              ),
                              child: firstSongWithArt.albumArt != null
                                  ? ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                      child: Image.memory(
                                        firstSongWithArt.albumArt!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.album,
                                      color: ThemeColorsUtil.scaffoldBackgroundColor,
                                      size: 40,
                                    ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    albumName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: ThemeColorsUtil.textColorPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${albumSongs.length} ${albumSongs.length == 1 ? 'track' : 'tracks'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ThemeColorsUtil.textColorSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
  }

  void _navigateToAlbum(String albumName, List<Song> albumSongs) {
    // Sort album songs by track number when available, otherwise by title
    final sortedAlbumSongs = List<Song>.from(albumSongs)..sort((a, b) {
      if (a.trackNumber != null && b.trackNumber != null) {
        return a.trackNumber!.compareTo(b.trackNumber!);
      } else if (a.trackNumber != null) {
        return -1; // a comes first
      } else if (b.trackNumber != null) {
        return 1; // b comes first
      } else {
        return a.title.compareTo(b.title); // alphabetical fallback
      }
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: ThemeColorsUtil.appBarBackgroundColor,
            title: Text(
              albumName,
              style: TextStyle(
                color: ThemeColorsUtil.textColorPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Container(
            color: ThemeColorsUtil.scaffoldBackgroundColor,
            child: ListView.builder(
              itemCount: sortedAlbumSongs.length,
              itemBuilder: (context, idx) {
                final song = sortedAlbumSongs[idx];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ThemeColorsUtil.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: song.albumArt != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              song.albumArt!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            color: ThemeColorsUtil.primaryColor,
                            size: 20,
                          ),
                  ),
                  title: Row(
                    children: [
                      if (song.trackNumber != null) ...[
                        Text(
                          '${song.trackNumber}. ',
                          style: TextStyle(
                            color: ThemeColorsUtil.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          song.title,
                          style: TextStyle(color: ThemeColorsUtil.textColorPrimary),
                        ),
                      ),
                    ],
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
                        onPressed: () {
                          widget.playbackManager.addToQueue(song);
                          widget.onPlaySong(song);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_to_queue,
                          color: ThemeColorsUtil.textColorSecondary,
                        ),
                        onPressed: () => widget.playbackManager.addToQueue(song),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
