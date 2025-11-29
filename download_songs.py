#!/opt/homebrew/bin/python3.12

import os
import sys
import subprocess
import time

# Test songs to download (using popular, widely available music)
songs = [
    {
        "title": "bad guy",
        "artist": "Billie Eilish",
        "query": "Billie Eilish bad guy official audio"
    },
    {
        "title": "Get Lucky",
        "artist": "Daft Punk",
        "query": "Daft Punk Get Lucky official audio"
    },
    {
        "title": "The Less I Know The Better",
        "artist": "Tame Impala",
        "query": "Tame Impala The Less I Know The Better official audio"
    },
    {
        "title": "SICKO MODE",
        "artist": "Travis Scott",
        "query": "Travis Scott SICKO MODE official audio"
    },
    {
        "title": "Thunder",
        "artist": "Imagine Dragons",
        "query": "Imagine Dragons Thunder official audio"
    }
]

def download_song(song, output_dir="test_music"):
    """Download a single song using yt-dlp"""

    # Create filename: Artist - Title.mp3
    filename = f"{song['artist']} - {song['title']}.mp3"
    output_path = os.path.join(output_dir, filename)

    # Get yt-dlp path - now installed globally via pipx
    ytdlp_path = "yt-dlp"  # It should be in PATH now

    # yt-dlp command
    cmd = [
        ytdlp_path,
        "--extract-audio",
        "--audio-format", "mp3",
        "--audio-quality", "192K",
        "--embed-metadata",
        "--embed-thumbnail",
        "--no-overwrites",
        "--output", output_path,
        "--default-search", "ytsearch",
        "--match-filter", "!is_live & duration < 600",  # Skip live streams and very long videos
        f"ytsearch:{song['query']}"
    ]

    print(f"🔄 Downloading: {song['artist']} - {song['title']}")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

        if result.returncode == 0:
            print(f"✅ Downloaded: {filename}")

            # Fix metadata if needed
            fix_metadata(output_path, song)
            return True
        else:
            print(f"❌ Failed to download: {song['artist']} - {song['title']}")
            print(f"Error: {result.stderr}")
            return False

    except subprocess.TimeoutExpired:
        print(f"⏰ Timeout downloading: {song['artist']} - {song['title']}")
        return False
    except Exception as e:
        print(f"💥 Error downloading {song['artist']} - {song['title']}: {e}")
        return False

def fix_metadata(filepath, song):
    """Fix metadata tags for better compatibility"""

    # Check if file exists
    if not os.path.exists(filepath):
        return

    # Use ffmpeg to add metadata tags (if available)
    try:
        # Only if ffmpeg is available and file exists
        cmd = [
            "ffmpeg", "-y", "-i", filepath,
            "-metadata", f"artist={song['artist']}",
            "-metadata", f"title={song['title']}",
            "-metadata", f"album={getattr(song, 'album', 'Test Music')}",
            "-c:a", "copy",
            f"{filepath}.tmp.mp3"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            # Replace original file
            os.replace(f"{filepath}.tmp.mp3", filepath)
            print(f"✨ Fixed metadata: {os.path.basename(filepath)}")

    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        # ffmpeg not available or other error, that's ok
        print(f"ℹ️  ffmpeg not available for metadata fix, file is fine")

def create_m3u_playlist(songs, output_dir="test_music", playlist_name="downloaded_music.m3u"):
    """Create an M3U playlist file from the downloaded songs"""

    playlist_path = os.path.join(output_dir, playlist_name)

    with open(playlist_path, 'w') as f:
        f.write("#EXTM3U\n")

        for song in songs:
            filename = f"{song['artist']} - {song['title']}.mp3"

            # Check duration (placeholder for now, you can enhance this)
            duration_seconds = 240  # default 4 minutes

            f.write(f"#EXTINF:{duration_seconds},{song['artist']} - {song['title']}\n")
            f.write(f"{filename}\n")

    print(f"📄 Created M3U playlist: {playlist_path}")
    return playlist_path

def main():
    print("🎵 Starting song download for Tunes4R testing...\n")

    # Create output directory
    output_dir = "test_music"
    os.makedirs(output_dir, exist_ok=True)

    downloaded_count = 0
    total_songs = len(songs)

    print(f"📥 Downloading {total_songs} test songs...\n")

    for i, song in enumerate(songs, 1):
        print(f"[{i}/{total_songs}] ", end="")
        if download_song(song, output_dir):
            downloaded_count += 1
        time.sleep(2)  # Be nice to YouTube

    print(f"\n🎉 Download complete! {downloaded_count}/{total_songs} songs downloaded\n")

    # Create M3U playlist
    if downloaded_count > 0:
        playlist_path = create_m3u_playlist(songs, output_dir)

        print("🚀 Ready for testing!")
        print(f"   Music folder: {output_dir}")
        print(f"   M3U playlist: {playlist_path}")
        print("\n🎯 Next steps:")
        print("   1. Run your Flutter app")
        print("   2. Add music from the 'test_music' folder")
        print("   3. Test playlist import with 'downloaded_music.m3u'")
        print("   4. Enjoy testing your playlist import feature!")

    else:
        print("❌ No songs were downloaded. Check your yt-dlp installation.")

if __name__ == "__main__":
    main()
