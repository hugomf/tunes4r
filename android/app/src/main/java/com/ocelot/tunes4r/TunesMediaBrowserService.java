package com.ocelot.tunes4r;

import android.app.PendingIntent;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import androidx.media.MediaBrowserServiceCompat;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;

public class TunesMediaBrowserService extends MediaBrowserServiceCompat {

    private static final String TAG = "TunesMediaBrowser";

    private static final String MEDIA_ROOT_ID = "root";
    private static final String RECENTLY_PLAYED_ID = "recently_played";
    private static final String PLAYLISTS_ID = "playlists";
    private static final String ARTISTS_ID = "artists";
    private static final String ALBUMS_ID = "albums";
    private static final String SONGS_ID = "songs";

    // Shared MediaSession from MainActivity
    private static MediaSessionCompat mediaSession;
    private static TunesMediaBrowserService instance;

    public static void setMediaSession(MediaSessionCompat session) {
        mediaSession = session;
        if (instance != null) {
            instance.setSessionToken(session.getSessionToken());
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        Log.d(TAG, "🎵 TunesMediaBrowserService created");

        // Set session token if already available
        if (mediaSession != null) {
            setSessionToken(mediaSession.getSessionToken());
        }

        // Create notification intent
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        );
    }

    @Override
    public BrowserRoot onGetRoot(String clientPackageName, int clientUid, Bundle rootHints) {
        Log.d(TAG, "🔍 onGetRoot called - Client: " + clientPackageName);

        // Verify that the specified package is allowed to browse media
        // For Android Auto, we should allow automotive apps
        if ("com.google.android.gms".equals(clientPackageName) ||
            clientPackageName.startsWith("com.google.android.projection")) {
            Log.d(TAG, "✅ Allowing Android Auto/Automotive client");
        } else {
            Log.d(TAG, "⚠️ Non-automotive client requesting access: " + clientPackageName);
        }

        // Allow browsing for all clients (adjust as needed for security)
        Bundle extras = new Bundle();
        return new BrowserRoot(MEDIA_ROOT_ID, extras);
    }

    @Override
    public void onLoadChildren(String parentId, Result<List<MediaBrowserCompat.MediaItem>> result) {
        Log.d(TAG, "📂 onLoadChildren called - ParentId: " + parentId);

        // Ensure empty result is returned if media loading fails
        result.detach();

        List<MediaBrowserCompat.MediaItem> mediaItems = new ArrayList<>();

        try {
            switch (parentId) {
                case MEDIA_ROOT_ID:
                    mediaItems.addAll(getRootItems());
                    break;
                case RECENTLY_PLAYED_ID:
                    mediaItems.addAll(getRecentlyPlayedItems());
                    break;
                case PLAYLISTS_ID:
                    mediaItems.addAll(getPlaylistItems());
                    break;
                case ARTISTS_ID:
                    mediaItems.addAll(getArtistItems());
                    break;
                case ALBUMS_ID:
                    mediaItems.addAll(getAlbumItems());
                    break;
                case SONGS_ID:
                    mediaItems.addAll(getSongItems());
                    break;
                default:
                    // Handle dynamic categories like specific playlists, artists, albums
                    if (parentId.startsWith("playlist_")) {
                        String playlistId = parentId.substring("playlist_".length());
                        mediaItems.addAll(getSongsForPlaylist(playlistId));
                    } else if (parentId.startsWith("artist_")) {
                        String artistId = parentId.substring("artist_".length());
                        mediaItems.addAll(getAlbumsForArtist(artistId));
                    } else if (parentId.startsWith("album_")) {
                        String albumId = parentId.substring("album_".length());
                        mediaItems.addAll(getSongsForAlbum(albumId));
                    }
                    break;
            }

            Log.d(TAG, "📋 Returning " + mediaItems.size() + " items for " + parentId);
            result.sendResult(mediaItems);

        } catch (Exception e) {
            Log.e(TAG, "💥 Error loading children for " + parentId, e);
            result.sendResult(new ArrayList<>());
        }
    }

    private List<MediaBrowserCompat.MediaItem> getRootItems() {
        List<MediaBrowserCompat.MediaItem> items = new ArrayList<>();

        // Recently Played (browsable)
        MediaMetadataCompat recentlyPlayedMetadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, RECENTLY_PLAYED_ID)
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Recently Played")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "Recently played songs")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(recentlyPlayedMetadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        // Playlists (browsable)
        MediaMetadataCompat playlistsMetadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, PLAYLISTS_ID)
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Playlists")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "Your playlists")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(playlistsMetadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        // Artists (browsable)
        MediaMetadataCompat artistsMetadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, ARTISTS_ID)
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Artists")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "Browse by artist")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(artistsMetadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        // Albums (browsable)
        MediaMetadataCompat albumsMetadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, ALBUMS_ID)
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Albums")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "Browse by album")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(albumsMetadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        // All Songs (browsable)
        MediaMetadataCompat songsMetadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, SONGS_ID)
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "All Songs")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "All songs in library")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(songsMetadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        return items;
    }

    private List<MediaBrowserCompat.MediaItem> getRecentlyPlayedItems() {
        // For Android Auto testing - return some dummy songs to make app discoverable
        List<MediaBrowserCompat.MediaItem> items = new ArrayList<>();

        MediaMetadataCompat metadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, "demo_recent_song")
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Demo Song - Recently Played")
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "Tunes4R Demo Artist")
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Demo Album")
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, 200000L) // 200 seconds
                .build();
        items.add(new MediaBrowserCompat.MediaItem(metadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_PLAYABLE));

        return items;
    }

    private List<MediaBrowserCompat.MediaItem> getPlaylistItems() {
        // For Android Auto testing - return demo playlists
        List<MediaBrowserCompat.MediaItem> items = new ArrayList<>();

        MediaMetadataCompat metadata = new MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, "demo_playlist_1")
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "My Favorites")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, "3 songs")
                .build();
        items.add(new MediaBrowserCompat.MediaItem(metadata.getDescription(),
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE));

        return items;
    }

    private List<MediaBrowserCompat.MediaItem> getArtistItems() {
        // TODO: Implement with actual artist data from Flutter/Dart side
        return new ArrayList<>(); // Return empty for now
    }

    private List<MediaBrowserCompat.MediaItem> getAlbumItems() {
        // TODO: Implement with actual album data from Flutter/Dart side
        return new ArrayList<>(); // Return empty for now
    }

    private List<MediaBrowserCompat.MediaItem> getSongItems() {
        // For Android Auto testing - return demo songs
        List<MediaBrowserCompat.MediaItem> items = new ArrayList<>();

        String[] demoSongs = {"Shape of You", "Blinding Lights", "Watermelon Sugar", "Bohemian Rhapsody", "Hotel California"};
        String[] demoArtists = {"Ed Sheeran", "The Weeknd", "Harry Styles", "Queen", "Eagles"};

        for (int i = 0; i < demoSongs.length; i++) {
            MediaMetadataCompat metadata = new MediaMetadataCompat.Builder()
                    .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, "demo_song_" + i)
                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, demoSongs[i])
                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, demoArtists[i])
                    .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Demo Album")
                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, 180000L) // 3 minutes
                    .build();
            items.add(new MediaBrowserCompat.MediaItem(metadata.getDescription(),
                    MediaBrowserCompat.MediaItem.FLAG_PLAYABLE));
        }

        return items;
    }

    private List<MediaBrowserCompat.MediaItem> getSongsForPlaylist(String playlistId) {
        // TODO: Implement playlist song loading
        return new ArrayList<>(); // Return empty for now
    }

    private List<MediaBrowserCompat.MediaItem> getAlbumsForArtist(String artistId) {
        // TODO: Implement artist album loading
        return new ArrayList<>(); // Return empty for now
    }

    private List<MediaBrowserCompat.MediaItem> getSongsForAlbum(String albumId) {
        // TODO: Implement album song loading
        return new ArrayList<>(); // Return empty for now
    }

    @Override
    public void onDestroy() {
        Log.d(TAG, "🛑 TunesMediaBrowserService destroyed");
        instance = null;
        super.onDestroy();
    }
}
