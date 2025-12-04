// lib/widgets/albums_tab.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:tunes4r/models/album.dart';
import 'package:tunes4r/models/song.dart';
import 'package:tunes4r/library/library.dart';
import 'package:tunes4r/services/playback_manager.dart';
import 'package:tunes4r/utils/theme_colors.dart';

class AlbumsTab extends StatefulWidget {
  final Library libraryContext;
  final PlaybackManager playbackManager;

  const AlbumsTab({
    super.key,
    required this.libraryContext,
    required this.playbackManager,
  });

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab> {
  // Use Library BC to get albums - no domain logic here
  List<Album> get albums => widget.libraryContext.getAlbums();
  int get albumCount => albums.length;

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 840) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double _aspectRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 500) return 0.78;
    if (width < 840) return 0.92;
    return 1.05;
  }

  @override
  Widget build(BuildContext context) {
    final albums = this.albums;

    return albums.isEmpty
        ? const Center(
            child: Text(
              'No albums in your library yet.\nAdd some music with album metadata.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          )
        : ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Albums',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount(context),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: _aspectRatio(context),
                ),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  final coverSong = album.coverSong;

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _navigateToAlbum(album),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColorsUtil.primaryColor.withOpacity(
                              0.3,
                            ),
                            blurRadius: 20,
                            spreadRadius: -5,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Album art or gradient fallback with scale effect
                            Positioned.fill(
                              child: Transform.scale(
                                scale: 1.1,
                                child: coverSong?.albumArt != null
                                    ? Image.memory(
                                        coverSong!.albumArt!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors:
                                                ThemeColorsUtil.albumGradient,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.album,
                                          size: 56,
                                          color: Colors.white70,
                                        ),
                                      ),
                              ),
                            ),

                            // Enhanced gradient overlay with blur effect
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.85),
                                    ],
                                    stops: const [0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Album info with improved styling
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      album.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.3,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 12,
                                            color: Colors.black,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeColorsUtil.primaryColor
                                            .withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: ThemeColorsUtil.primaryColor
                                              .withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${album.trackCount} ${album.trackCount == 1 ? 'track' : 'tracks'}',
                                        style: TextStyle(
                                          color: ThemeColorsUtil.primaryColor
                                              .withOpacity(0.9),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 90),
            ],
          );
  }

  void _navigateToAlbum(Album album) {
    // Albums Tab owns its playback context - uses album songs
    final sortedSongs = album.sortedSongs;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumDetailPage(
          album: album,
          songs: sortedSongs,
          playbackManager: widget.playbackManager,
          onPlaySong: (Song song) {
            widget.playbackManager.playSong(song, context: sortedSongs);
          }, // Owns playback context
        ),
      ),
    );
  }
}

// Enhanced Album Detail Page with Blended Background
class _AlbumDetailPage extends StatelessWidget {
  final Album album;
  final List<Song> songs;
  final PlaybackManager playbackManager;
  final Function(Song) onPlaySong;

  const _AlbumDetailPage({
    required this.album,
    required this.songs,
    required this.playbackManager,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: BackButton(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Blended background with album art
          if (album.coverSong?.albumArt != null)
            Positioned.fill(
              child: Stack(
                children: [
                  // Blurred and scaled album art background
                  Transform.scale(
                    scale: 1.2,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Image.memory(
                        album.coverSong!.albumArt!,
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.4),
                      ),
                    ),
                  ),
                  // Dark overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ThemeColorsUtil.appBarBackgroundColor.withOpacity(
                            0.7,
                          ),
                          ThemeColorsUtil.appBarBackgroundColor.withOpacity(
                            0.95,
                          ),
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Gradient fallback
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ThemeColorsUtil.primaryColor.withOpacity(0.3),
                      ThemeColorsUtil.appBarBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),

          // Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Album header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      children: [
                        // Album artwork with shadow
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeColorsUtil.primaryColor.withOpacity(
                                  0.5,
                                ),
                                blurRadius: 40,
                                spreadRadius: -10,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: album.coverSong?.albumArt != null
                                ? Image.memory(
                                    album.coverSong!.albumArt!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: ThemeColorsUtil.albumGradient,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.album,
                                      size: 80,
                                      color: Colors.white70,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Album name
                        Text(
                          album.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Track count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColorsUtil.primaryColor.withOpacity(
                              0.2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ThemeColorsUtil.primaryColor.withOpacity(
                                0.5,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${album.trackCount} ${album.trackCount == 1 ? 'Track' : 'Tracks'}',
                            style: TextStyle(
                              color: ThemeColorsUtil.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Song list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final song = songs[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColorsUtil.primaryColor
                                      .withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: song.albumArt != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      song.albumArt!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: ThemeColorsUtil.albumGradient,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white70,
                                    ),
                                  ),
                          ),
                          title: Row(
                            children: [
                              if (song.trackNumber != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: ThemeColorsUtil.primaryColor
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${song.trackNumber}',
                                    style: TextStyle(
                                      color: ThemeColorsUtil.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  song.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            song.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_arrow,
                                  color: ThemeColorsUtil.primaryColor,
                                ),
                                onPressed: () {
                                  playbackManager.addToQueue(song);
                                  onPlaySong(song);
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_to_queue,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                onPressed: () =>
                                    playbackManager.addToQueue(song),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: songs.length),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
