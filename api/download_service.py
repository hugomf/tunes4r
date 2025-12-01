#!/opt/homebrew/bin/python3.12

from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
import asyncio
import os
import uuid
import requests
from typing import List, Optional, Dict, Any
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
import uvicorn
import json

app = FastAPI(title="Tunes4R Download Service", version="1.0.0")

# Global download status tracking
download_status_db = {}

class SongRequest(BaseModel):
    title: str
    artist: str
    album: Optional[str] = None

class AlbumRequest(BaseModel):
    artist: str
    album: str

class DownloadResponse(BaseModel):
    message: str
    download_id: str
    status: str
    songs_info: Optional[List[Dict[str, str]]] = None

class SearchResponse(BaseModel):
    query: str
    results: List[Dict[str, Any]] = []

class SearchResult(BaseModel):
    title: str
    artist: str
    duration: str
    video_id: str
    thumbnail_url: Optional[str] = None
    uploader: Optional[str] = None

class AlbumSearchResponse(BaseModel):
    query: str
    artist: str
    album: str
    track_count: int
    tracks: List[Dict[str, str]] = []
    release_year: Optional[str] = None
    cover_url: Optional[str] = None

class StatusResponse(BaseModel):
    download_id: str
    status: str
    progress: Optional[int] = None
    total_songs: Optional[int] = None
    completed_songs: Optional[int] = None
    songs: Optional[List[Dict[str, Any]]] = None
    error: Optional[str] = None

def update_download_status(download_id: str, status: str, **kwargs):
    """Update download status in global store"""
    download_status_db[download_id] = {
        "status": status,
        "updated_at": time.time(),
        **kwargs
    }

def cancel_download_status(download_id: str) -> bool:
    """Cancel a download if it's in progress"""
    status_data = get_download_status(download_id)
    if status_data and status_data.get('status') in ['starting', 'downloading']:
        update_download_status(download_id, 'cancelled')
        print(f"🛑 Cancelled download: {download_id}")
        return True
    return False

def get_download_status(download_id: str) -> Optional[Dict]:
    """Get download status from global store"""
    return download_status_db.get(download_id)

async def download_song_async(song: Dict[str, str], output_dir: str, download_id: str, song_index: int = 0):
    """Download a single song asynchronously using yt-dlp with fallback search queries"""

    filename = f"{song['artist']} - {song['title']}.mp3"
    output_path = os.path.join(output_dir, filename)

    print(f"⬇️ Starting download: '{song['artist']} - {song['title']}' -> {output_path}")

    # Try multiple search strategies for better results
    search_queries = []

    # Strategy 1: Use custom query if provided, otherwise basic format
    if song.get('query'):
        search_queries.append(song['query'])
    else:
        # Clean and prepare the basic search query
        artist_clean = song['artist'].strip()
        title_clean = song['title'].strip()

        # Try different search patterns in order of preference
        search_queries.append(f"{artist_clean} {title_clean} official")
        search_queries.append(f"{artist_clean} {title_clean}")
        search_queries.append(f"{title_clean} {artist_clean}")
        search_queries.append(f"{artist_clean} {title_clean} audio")
        search_queries.append(f"{artist_clean} {title_clean} official audio lyrics")

    success = False
    last_error = "No search queries succeeded"

    for i, query in enumerate(search_queries):
        print(f"🔍 Trying search query {i+1}/{len(search_queries)}: '{query}'")

        # Enhanced yt-dlp command with better headers and options to avoid 403
        cmd = [
            "yt-dlp",
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "192K",
            "--output", output_path,
            "--force-overwrites",
            "--no-playlist",
            "--quiet",
            # Add user agent to avoid bot detection
            "--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            # Add referer
            "--referer", "https://www.youtube.com/",
            # Use cookies if available (helps with rate limiting)
            # "--cookies-from-browser", "chrome",  # Uncomment if you have Chrome with YouTube login
            # Add more retries
            "--retries", "3",
            "--fragment-retries", "3",
            # Add sleep between requests
            "--sleep-requests", "1",
            # Match filters
            "--match-filter", "!is_live & duration < 900 & duration > 30",
            f"ytsearch:{query}"
        ]

        try:
            # Run in thread pool to avoid blocking async
            loop = asyncio.get_event_loop()
            with ThreadPoolExecutor() as executor:
                result = await loop.run_in_executor(executor,
                    lambda: subprocess.run(cmd, capture_output=True, text=True, timeout=600))

            if result.returncode == 0 and os.path.exists(output_path):
                # Verify the file was actually created and has content
                file_size = os.path.getsize(output_path)
                if file_size > 0:
                    print(f"✅ Download succeeded with query: '{query}'")
                    # Fix and validate metadata with enhanced enrichment
                    enhanced_song = enrich_metadata(song, output_path)
                    metadata_success = fix_metadata(output_path, enhanced_song)
                    return metadata_success, output_path if metadata_success else "Metadata fix failed"
                else:
                    print(f"⚠️ Download appeared to succeed but file is empty ({file_size} bytes)")
                    try:
                        os.remove(output_path)
                    except:
                        pass
            else:
                # Better error reporting
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                stdout = result.stdout.strip() if result.stdout else "No output"
                returncode = result.returncode

                detailed_error = f"yt-dlp failed (exit code: {returncode}): {error_msg}"
                if stdout and len(stdout) > 0:
                    detailed_error += f" | stdout: {stdout[:200]}..."

                print(f"❌ Search query {i+1} failed: {detailed_error}")
                last_error = detailed_error

                # If it's a 403 error, add delay before next attempt
                if "403" in error_msg or "Forbidden" in error_msg:
                    print(f"⏰ 403 detected, waiting 5 seconds before retry...")
                    await asyncio.sleep(5)

            # Clean up any partial files between attempts
            if os.path.exists(output_path):
                try:
                    os.remove(output_path)
                except:
                    pass

        except subprocess.TimeoutExpired:
            print(f"⏰ Search query {i+1} timed out")
            last_error = "Download timeout (10 minutes)"
        except Exception as e:
            print(f"❌ Search query {i+1} error: {str(e)}")
            last_error = str(e)
        
        # Add delay between search attempts to avoid rate limiting
        if i < len(search_queries) - 1:  # Don't sleep after last attempt
            await asyncio.sleep(2)

    print(f"💥 All search strategies failed. Last error: {last_error}")
    return False, f"No suitable video found after trying {len(search_queries)} different search queries. Last error: {last_error}"

def enrich_metadata(song: Dict[str, str], filepath: str) -> Dict[str, str]:
    """Enrich metadata using MusicBrainz API for better accuracy"""
    enhanced_song = song.copy()

    try:
        # Search for recording on MusicBrainz
        artist_clean = song['artist'].replace(' ft.', '').replace(' feat.', '').replace(' & ', '').strip()
        title_clean = song['title'].replace(' - live', '').replace(' (live)', '').strip()

        search_url = "http://musicbrainz.org/ws/2/recording/"
        params = {
            "query": f'artist:"{artist_clean}" AND recording:"{title_clean}"',
            "fmt": "json",
            "limit": 1
        }

        headers = {"User-Agent": "Tunes4R-Download-Service/2.0"}
        response = requests.get(search_url, params=params, headers=headers, timeout=8)

        if response.status_code == 200:
            data = response.json()

            if data.get('recordings') and len(data['recordings']) > 0:
                recording = data['recordings'][0]

                # Extract accurate metadata
                if recording.get('title'):
                    enhanced_song['title'] = recording['title']

                # Get artist from release-artists or recording artist
                if recording.get('artist-credit'):
                    artist_credit = recording['artist-credit'][0]
                    artist_name = artist_credit.get('name', '') if isinstance(artist_credit, dict) else str(artist_credit)
                    if artist_name:
                        enhanced_song['artist'] = artist_name

                # Get release info for album
                if recording.get('releases') and len(recording['releases']) > 0:
                    release = recording['releases'][0]
                    if release.get('title'):
                        enhanced_song['album'] = release['title']

                    # Get release ID for cover art
                    release_id = release.get('id')
                    if release_id:
                        cover_url = get_album_cover_art(release_id)
                        if cover_url:
                            enhanced_song['cover_url'] = cover_url

                # Get genre information
                if recording.get('tags'):
                    # Look for genre tags
                    genre_tags = [tag['name'] for tag in recording['tags'] if tag.get('count', 0) > 0]
                    if genre_tags:
                        enhanced_song['genre'] = ', '.join(genre_tags[:3])  # Top 3 genres

                # Get track number and disc number
                if recording.get('releases'):
                    for release in recording['releases']:
                        if release.get('media'):
                            for medium in release['media']:
                                if medium.get('tracks'):
                                    for track in medium['tracks']:
                                        if track.get('recording') and track['recording'].get('id') == recording.get('id'):
                                            if track.get('number'):
                                                enhanced_song['track_number'] = track['number']
                                            if track.get('length'):
                                                enhanced_song['duration_ms'] = track['length']
                                            break

                print(f"✅ Enhanced metadata: '{enhanced_song['title']}' by {enhanced_song['artist']} ({enhanced_song.get('album', 'N/A')})")

        # Try to get lyrics - multiple sources
        lyrics = get_song_lyrics(enhanced_song['artist'], enhanced_song['title'])
        if lyrics:
            enhanced_song['lyrics'] = lyrics
            print(f"✅ Found lyrics ({len(lyrics)} chars)")
        else:
            print(f"⚠️ No lyrics found for '{enhanced_song['title']}'")

    except Exception as e:
        print(f"⚠️ Metadata enrichment failed: {e}")
        return song  # Return original if enrichment fails

    return enhanced_song

def get_song_lyrics(artist: str, title: str) -> Optional[str]:
    """Get song lyrics from multiple sources"""

    # Clean inputs
    artist_clean = artist.lower().replace(' ft.', '').replace(' feat.', '').strip()
    title_clean = title.lower().replace(' - live', '').replace(' (live)', '').strip()

    # Try lyrics.ovh API first (good for common songs)
    try:
        lyrics_url = f"https://api.lyrics.ovh/v1/{artist_clean}/{title_clean}"
        response = requests.get(lyrics_url, timeout=5)

        if response.status_code == 200:
            data = response.json()
            if data.get('lyrics') and len(data['lyrics']) > 10:
                lyrics = data['lyrics'].strip()
                if lyrics:
                    print(f"🎵 Got lyrics from lyrics.ovh ({len(lyrics)} chars)")
                    return lyrics
    except Exception as e:
        print(f"⚠️ lyrics.ovh failed: {e}")

    # Try lrclib.net as fallback (better for newer songs)
    try:
        search_url = f"https://lrclib.net/api/search?q={artist_clean} {title_clean}"
        response = requests.get(search_url, timeout=5)

        if response.status_code == 200:
            results = response.json()
            if results and len(results) > 0:
                # Look for best match
                for result in results:
                    # Check if it's reasonably close match
                    result_artist = result.get('artistName', '').lower()
                    result_title = result.get('trackName', '').lower()

                    if (artist_clean.replace('&', '').replace('and', '') in result_artist.replace('&', '').replace('and', '')) and \
                       (title_clean in result_title or result_title in title_clean):
                        lyrics = result.get('plainLyrics')
                        if lyrics and len(lyrics) > 20:
                            print(f"🎵 Got lyrics from lrclib.net ({len(lyrics)} chars)")
                            return lyrics

    except Exception as e:
        print(f"⚠️ lrclib.net failed: {e}")

    # Try azlyrics.com as another fallback (but it's reliable but slower)
    try:
        # This is more complex and would need proper scraping implementation
        # For now, just return None
        pass
    except Exception as e:
        print(f"⚠️ azlyrics failed: {e}")

    print(f"⚠️ No lyrics found for '{title}' by {artist}")
    return None

def embed_lyrics_into_file(filepath: str, lyrics: str) -> bool:
    """Embed lyrics into MP3 file using ffmpeg"""
    if not os.path.exists(filepath) or not lyrics or len(lyrics.strip()) == 0:
        return False

    temp_path = f"{filepath}.lyrics.mp3"

    try:
        # Create a temporary lyrics file
        lyrics_file = f"{filepath}.txt"
        with open(lyrics_file, 'w', encoding='utf-8') as f:
            f.write(lyrics)

        # Use ffmpeg to embed lyrics as metadata
        cmd = [
            "ffmpeg", "-y",
            "-i", filepath,
            "-f", "lavfi", "-i", "anullsrc",
            "-map", "0:a",
            "-map_metadata", "0",
            "-metadata", f"lyrics={lyrics[:4000]}",  # Limit lyrics size (some players have limits)
            "-c:a", "copy",
            "-shortest",
            temp_path
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            os.replace(temp_path, filepath)

            # Clean up lyrics file
            try:
                os.remove(lyrics_file)
            except:
                pass

            print(f"✅ Lyrics embedded into {os.path.basename(filepath)}")
            return True
        else:
            print(f"❌ Failed to embed lyrics: {result.stderr}")

            # Clean up temp files
            try:
                os.remove(temp_path)
                os.remove(lyrics_file)
            except:
                pass

            return False

    except Exception as e:
        print(f"❌ Error embedding lyrics: {e}")

        # Clean up any temp files
        for temp_file in [temp_path, lyrics_file]:
            try:
                if os.path.exists(temp_file):
                    os.remove(temp_file)
            except:
                pass

        return True  # File is still valid even without embedded lyrics

def fix_metadata(filepath: str, song: Dict[str, str]) -> bool:
    """Fix metadata tags using ffmpeg"""
    if not os.path.exists(filepath):
        print(f"❌ Metadata fix skipped: file doesn't exist: {filepath}")
        return False

    temp_path = f"{filepath}.tmp.mp3"
    try:
        # Check if ffmpeg is available
        try:
            subprocess.run(["ffmpeg", "-version"], capture_output=True, timeout=5)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            print(f"⚠️ ffmpeg not found, attempting metadata fix with other tools")
            return True  # File is still valid without metadata fix

        # Clean metadata values
        artist = song['artist'].replace('"', '').replace("'", "").strip()
        title = song['title'].replace('"', '').replace("'", "").strip()
        album = song.get('album', 'Downloaded Music').replace('"', '').replace("'", "").strip()

        cmd = [
            "ffmpeg", "-y", "-i", filepath,
            "-metadata", f"artist={artist}",
            "-metadata", f"title={title}",
            "-metadata", f"album={album}",
            "-c:a", "copy", "-f", "mp3", temp_path
        ]

        print(f"🔧 Fixing metadata for {os.path.basename(filepath)}...")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            try:
                os.replace(temp_path, filepath)
                print(f"✅ Metadata fixed successfully")
                return True
            except Exception as e:
                print(f"❌ Failed to replace file: {e}")
                # Try to clean up temp file
                try:
                    os.remove(temp_path)
                except:
                    pass
                return False
        else:
            print(f"❌ ffmpeg failed: {result.stderr.strip()}")
            # Clean up temp file if it exists
            try:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
            except:
                pass
            return False

    except subprocess.TimeoutExpired:
        print("⏰ ffmpeg metadata fix timed out")
        # Clean up temp file if it exists
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except:
            pass
        return True  # File is still valid
    except Exception as e:
        print(f"❌ Unexpected error during metadata fix: {e}")
        # Clean up temp file if it exists
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except:
            pass
        return True  # File is still valid even without metadata fix

def get_album_tracks(artist: str, album: str) -> List[Dict[str, str]]:
    """Get album tracklist using MusicBrainz API with fallbacks"""

    try:
        # Clean and format query
        artist_clean = artist.strip()
        album_clean = album.strip()

        # Try MusicBrainz API first
        search_url = "http://musicbrainz.org/ws/2/release/"
        params = {
            "query": f'artist:"{artist_clean}" AND release:"{album_clean}"',
            "fmt": "json",
            "limit": 1
        }

        headers = {"User-Agent": "Tunes4R-Download-Service/1.0"}
        response = requests.get(search_url, params=params, headers=headers, timeout=10)

        if response.status_code == 200:
            data = response.json()

            if data.get('releases') and len(data['releases']) > 0:
                release = data['releases'][0]
                release_id = release['id']

                # Get detailed release info with recordings
                detail_url = f"http://musicbrainz.org/ws/2/release/{release_id}"
                detail_params = {"inc": "recordings", "fmt": "json"}
                detail_response = requests.get(detail_url, params=detail_params, headers=headers, timeout=10)

                if detail_response.status_code == 200:
                    detail_data = detail_response.json()
                    tracks = []

                    # Extract tracks from media
                    for medium in detail_data.get('media', []):
                        for track in medium.get('tracks', []):
                            if track.get('recording'):
                                # Create track-specific search to avoid album videos
                                track_title = track['recording']['title']
                                track_info = {
                                    'title': track_title,
                                    'artist': artist_clean,
                                    'album': album_clean,
                                    'query': f'{artist_clean} "{track_title}" song official audio',
                                    'track_number': track.get('number')
                                }
                                tracks.append(track_info)

                    if tracks:
                        return tracks

        # Fallback 1: Use Spotify API (would need API key)
        # This is commented out as it requires setup, but shows the pattern
        """
        spotify_search = search_spotify_album(artist_clean, album_clean)
        if spotify_search:
            return spotify_search
        """

        # Fallback 2: Generate common tracklist patterns with specific individual song searches
        # This creates dummy tracks that prioritize individual song downloads
        album_prefixes = ['track', 'song']
        common_suffixes = ['', ' (part 1)', ' (part 2)']

        tracks = []
        # Estimate typical album length (10-15 tracks)
        for i in range(1, 13):  # 1-12 tracks
            # Try different prefixes to avoid album compilations
            for prefix in album_prefixes:
                for suffix in common_suffixes:
                    track_title = f"{prefix.title()} {i}{suffix}"
                    # Use specific search query to avoid album videos
                    tracks.append({
                        'title': track_title,
                        'artist': artist_clean,
                        'album': album_clean,
                        'query': f'{artist_clean} "{album_clean}" song {i} -individual track-',
                    })
                    if len(tracks) >= 12:  # Limit to reasonable number
                        break
            if len(tracks) >= 12:
                break

        print(f"⚠️ MusicBrainz failed for '{album_clean}' - using individual track fallback")
        return tracks[:12]  # Return up to 12 tracks

    except Exception as e:
        print(f"Error getting album tracks: {e}")
        # Emergency fallback - return single track
        return [{
            'title': album,
            'artist': artist,
            'album': album,
            'query': f'{artist} {album} full album official'
        }]

def create_m3u_playlist(songs: List[Dict[str, str]], output_dir: str, filename: str):
    """Create an M3U playlist file"""
    playlist_path = os.path.join(output_dir, filename)

    with open(playlist_path, 'w', encoding='utf-8') as f:
        f.write("#EXTM3U\n")
        f.write("#PLAYLIST:Tunes4R Download Service\n")

        for song in songs:
            filename = f"{song['artist']} - {song['title']}.mp3"
            # Estimate duration (4 minutes default)
            duration_seconds = 240
            f.write(f"#EXTINF:{duration_seconds},{song['artist']} - {song['title']}\n")
            f.write(f"{filename}\n")

    return playlist_path

import re

def extract_youtube_video_id(url: str) -> Optional[str]:
    """Extract YouTube video ID from various URL formats"""
    patterns = [
        r'(?:https?://)?(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?youtu\.be/([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?(?:www\.)?youtube\.com/v/([a-zA-Z0-9_-]{11})',
    ]

    for pattern in patterns:
        match = re.search(pattern, url.strip())
        if match:
            return match.group(1)
    return None

def search_youtube_songs(query: str, max_results: int = 10) -> List[Dict[str, Any]]:
    """Search YouTube for songs or get direct URL info without downloading them"""

    # Check if query is a YouTube URL
    video_id = extract_youtube_video_id(query)
    if video_id:
        print(f"🔗 Detected YouTube URL with video ID: {video_id}")
        # Get info for specific video
        cmd = [
            "yt-dlp",
            "--print-json",
            "--no-download",
            "--skip-download",
            f"https://www.youtube.com/watch?v={video_id}",
            "--match-filter", "!is_live & duration < 1800"  # Skip live streams and very long videos
        ]
    else:
        # Normal search
        cmd = [
            "yt-dlp",
            "--flat-playlist",
            "--print-json",
            "--no-download",
            "--skip-download",
            f"ytsearch{max_results}:{query} official audio",
            "--match-filter", "!is_live & duration < 1800"  # Skip live streams and very long videos
        ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            results = []

            for line in lines:
                line = line.strip()
                if line and line.startswith('{'):
                    try:
                        data = json.loads(line)

                        # Extract relevant information
                        result_info = {
                            'title': data.get('title', 'Unknown'),
                            'artist': 'Unknown Artist',  # Will be parsed below
                            'duration': '0:00',
                            'video_id': data.get('id', ''),
                            'thumbnail_url': f"https://img.youtube.com/vi/{data.get('id', '')}/default.jpg",
                            'uploader': data.get('uploader', 'Unknown'),
                            'view_count': data.get('view_count', 0),
                            'upload_date': data.get('upload_date', ''),
                            'duration_seconds': data.get('duration', 0)
                        }

                        # Try to parse title into artist and title
                        title = result_info['title']
                        if ' - ' in title:
                            parts = title.split(' - ', 1)  # Split only on first occurrence
                            potential_artist = parts[0].strip()
                            song_title = parts[1].strip()
                            # Clean up common patterns
                            if any(keyword in potential_artist.lower() for keyword in ['official', 'audio', 'music video', 'lyrics']):
                                # Keep as is, might be just a title
                                pass
                            else:
                                result_info['artist'] = potential_artist
                                result_info['title'] = song_title

                        # Format duration
                        duration_seconds = result_info.get('duration_seconds', 0)
                        if duration_seconds:
                            minutes = int(duration_seconds // 60)
                            seconds = int(duration_seconds % 60)
                            result_info['duration'] = f"{minutes}:{seconds:02d}"

                        results.append(result_info)

                    except json.JSONDecodeError:
                        continue

            # For URL queries, return just the single result
            if video_id:
                return results[:1]
            else:
                return results[:max_results]

        else:
            print(f"YouTube search failed: {result.stderr}")
            return []

    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"YouTube search error: {e}")
        return []

def get_album_cover_art(release_id: str) -> Optional[str]:
    """Get album cover art from Cover Art Archive using MusicBrainz release ID"""

    try:
        cover_url = f"http://coverartarchive.org/release/{release_id}"
        headers = {"User-Agent": "Tunes4R-Download-Service/1.0"}

        response = requests.get(cover_url, headers=headers, timeout=5)

        if response.status_code == 200:
            data = response.json()
            images = data.get('images', [])

            if images:
                # Prefer front cover, fallback to any other image
                front_cover = next((img for img in images if img.get('front', False)), None)
                if front_cover:
                    return front_cover['thumbnails']['small']  # Use small thumbnail (250px)
                else:
                    # Use first available image
                    return images[0]['thumbnails']['small']

        return None

    except Exception as e:
        print(f"Error getting cover art for release {release_id}: {e}")
        return None

def search_musicbrainz_albums(query: str, max_results: int = 5) -> List[Dict[str, Any]]:
    """Search MusicBrainz for albums"""

    try:
        search_url = "http://musicbrainz.org/ws/2/release/"
        params = {
            "query": query,
            "fmt": "json",
            "limit": max_results
        }

        headers = {"User-Agent": "Tunes4R-Download-Service/1.0"}
        response = requests.get(search_url, params=params, headers=headers, timeout=10)

        if response.status_code == 200:
            data = response.json()
            albums = []

            for release in data.get('releases', []):
                album_info = {
                    'artist': release.get('artist-credit', [{}])[0].get('name', 'Unknown Artist') if release.get('artist-credit') else 'Unknown Artist',
                    'album': release.get('title', 'Unknown Album'),
                    'release_year': release.get('date', '')[:4] if release.get('date') else None,
                    'track_count': release.get('track-count', 0),
                    'country': release.get('country', None),
                    'release_id': release.get('id', '')
                }

                # Get detailed tracklist for this album
                if album_info['release_id']:
                    tracks = get_album_tracks_from_release(album_info['release_id'])
                    album_info['tracks'] = tracks
                    album_info['track_count'] = len(tracks)

                    # Try to get cover art for this album
                    cover_url = get_album_cover_art(album_info['release_id'])
                    album_info['cover_url'] = cover_url

                albums.append(album_info)

            return albums

        return []

    except Exception as e:
        print(f"MusicBrainz album search error: {e}")
        return []

def get_album_tracks_from_release(release_id: str) -> List[Dict[str, str]]:
    """Get detailed tracklist for a specific MusicBrainz release"""

    try:
        detail_url = f"http://musicbrainz.org/ws/2/release/{release_id}"
        params = {"inc": "recordings", "fmt": "json"}
        headers = {"User-Agent": "Tunes4R-Download-Service/1.0"}

        response = requests.get(detail_url, params=params, headers=headers, timeout=10)

        if response.status_code == 200:
            data = response.json()
            tracks = []

            # Extract tracks from media
            for medium in data.get('media', []):
                for track in medium.get('tracks', []):
                    if track.get('recording'):
                        track_info = {
                            'title': track['recording']['title'],
                            'artist': data.get('artist-credit', [{}])[0].get('name', data['artist-credit'][0].get('artist', {}).get('name', 'Unknown Artist')) if data.get('artist-credit') else 'Unknown Artist',
                            'album': data.get('title', 'Unknown Album'),
                        }
                        tracks.append(track_info)

            return tracks

        return []

    except Exception as e:
        print(f"Error getting tracks for release {release_id}: {e}")
        return []

@app.get("/search/songs", response_model=SearchResponse)
async def search_songs_endpoint(q: str, limit: int = 10):
    """Search for songs on YouTube"""
    if not q or len(q.strip()) == 0:
        raise HTTPException(status_code=400, detail="Query parameter is required")

    print(f"🔍 SONG SEARCH: '{q}' (limit: {limit})")

    results = search_youtube_songs(q.strip(), max_results=min(limit, 20))  # Max 20 results

    return SearchResponse(
        query=q.strip(),
        results=results
    )

@app.get("/search/albums", response_model=List[AlbumSearchResponse])
async def search_albums_endpoint(q: str, limit: int = 5):
    """Search for albums using MusicBrainz"""
    if not q or len(q.strip()) == 0:
        raise HTTPException(status_code=400, detail="Query parameter is required")

    print(f"🔍 ALBUM SEARCH: '{q}' (limit: {limit})")

    albums = search_musicbrainz_albums(q.strip(), max_results=min(limit, 10))  # Max 10 results

    response = []
    for album in albums:
        response.append(AlbumSearchResponse(
            query=q.strip(),
            artist=album['artist'],
            album=album['album'],
            track_count=album['track_count'],
            tracks=album['tracks'],
            release_year=album.get('release_year'),
            cover_url=album.get('cover_url')
        ))

    return response

@app.post("/download/song", response_model=DownloadResponse)
async def download_song_endpoint(song: SongRequest, background_tasks: BackgroundTasks):
    """Download a single song"""
    album_display = song.album if song.album is not None and song.album.strip() else 'None'
    print(f"📥 SONG DOWNLOAD REQUEST: title='{song.title}', artist='{song.artist}', album='{album_display}'")

    download_id = str(uuid.uuid4())
    update_download_status(download_id, "starting", total_songs=1, completed_songs=0)

    song_dict = {
        'title': song.title.strip(),
        'artist': song.artist.strip(),
        'album': song.album.strip() if song.album else 'Unknown Album',
        'query': f'{song.artist.strip()} {song.title.strip()} official audio lyrics'
    }

    # Start background download
    background_tasks.add_task(process_song_download, download_id, [song_dict])

    return DownloadResponse(
        message=f"Started downloading song: {song.title} by {song.artist}",
        download_id=download_id,
        status="started",
        songs_info=[song_dict]
    )

@app.post("/download/album", response_model=DownloadResponse)
async def download_album_endpoint(album_req: AlbumRequest, background_tasks: BackgroundTasks):
    """Download an entire album"""
    print(f"📥 ALBUM DOWNLOAD REQUEST: artist='{album_req.artist}', album='{album_req.album}'")

    download_id = str(uuid.uuid4())
    update_download_status(download_id, "searching_tracks")

    # Get tracklist
    tracks = get_album_tracks(album_req.artist.strip(), album_req.album.strip())

    if not tracks:
        raise HTTPException(status_code=404, detail=f"Could not find tracks for album '{album_req.album}' by '{album_req.artist}'")

    if len(tracks) > 20:
        raise HTTPException(status_code=400, detail="Album has too many tracks (max 20). Try individual songs instead.")

    update_download_status(
        download_id,
        "starting",
        total_songs=len(tracks),
        completed_songs=0,
        songs=[]
    )

    # Start background download
    background_tasks.add_task(process_song_download, download_id, tracks)

    return DownloadResponse(
        message=f"Started downloading album '{album_req.album}' by {album_req.artist} ({len(tracks)} tracks)",
        download_id=download_id,
        status="started",
        songs_info=tracks
    )

@app.get("/status/{download_id}", response_model=StatusResponse)
async def get_download_status_endpoint(download_id: str):
    """Get download status"""
    status_data = get_download_status(download_id)
    if not status_data:
        raise HTTPException(status_code=404, detail="Download not found")

    return StatusResponse(
        download_id=download_id,
        **status_data
    )

@app.delete("/download/{download_id}")
async def cancel_download_endpoint(download_id: str):
    """Cancel a download if it's in progress"""
    if cancel_download_status(download_id):
        return {"message": f"Download {download_id} cancelled successfully"}
    else:
        status_data = get_download_status(download_id)
        if status_data:
            current_status = status_data.get('status')
            raise HTTPException(
                status_code=400,
                detail=f"Cannot cancel download in status '{current_status}'. Only starting/downloading downloads can be cancelled."
            )
        else:
            raise HTTPException(status_code=404, detail="Download not found")

@app.get("/download/{download_id}/playlist")
async def get_playlist_endpoint(download_id: str):
    """Get M3U playlist for completed album download"""
    status_data = get_download_status(download_id)
    if not status_data:
        raise HTTPException(status_code=404, detail="Download not found")

    if status_data.get('status') != 'completed':
        raise HTTPException(status_code=400, detail="Download not completed yet")

    songs = status_data.get('songs', [])
    if len(songs) <= 1:
        raise HTTPException(status_code=400, detail="No album playlist available (single song download)")

    # Serve the M3U file
    # In production, you'd want to store this differently
    return {"playlist_url": f"/static/playlists/{download_id}.m3u"}

async def process_song_download(download_id: str, songs: List[Dict[str, str]]):
    """Background task to process multiple song downloads"""

    # Output directory at project root level for easy import into Tunes4R app
    output_dir = os.path.join(os.path.dirname(__file__), "..", "downloaded_music")
    os.makedirs(output_dir, exist_ok=True)

    completed = 0
    failed = 0
    downloaded_songs = []

    # Update status to downloading immediately when we start processing
    update_download_status(
        download_id,
        "downloading",
        total_songs=len(songs),
        completed_songs=0,
        failed_songs=0,
        progress=0,
        songs=[]
    )

    for i, song in enumerate(songs):
        try:
            # For single songs, show intermediate progress for better UX
            if len(songs) == 1:
                # Show progress as downloading starts
                update_download_status(
                    download_id,
                    "downloading",
                    total_songs=1,
                    completed_songs=0,
                    failed_songs=0,
                    progress=10,  # Starting download
                    songs=[]
                )
                await asyncio.sleep(0.5)  # Small delay for visual effect

            # Show progress as download begins
            if len(songs) == 1:
                update_download_status(
                    download_id,
                    "downloading",
                    total_songs=1,
                    completed_songs=0,
                    failed_songs=0,
                    progress=25,  # Download in progress
                    songs=[]
                )

            success, result_msg = await download_song_async(song, output_dir, download_id, i)

            if success:
                completed += 1
                file_size = os.path.getsize(result_msg) if os.path.exists(result_msg) else 0
                file_size_mb = file_size / (1024 * 1024)

                # For single songs, show processing progress
                if len(songs) == 1:
                    update_download_status(
                        download_id,
                        "downloading",
                        total_songs=1,
                        completed_songs=0,
                        failed_songs=0,
                        progress=75,  # Processing metadata
                        songs=[]
                    )
                    await asyncio.sleep(0.5)  # Simulate processing time

                print(f"✅ Downloaded successfully: '{song['artist']} - {song['title']}' ({file_size_mb:.1f} MB) -> {result_msg}")
                downloaded_songs.append({
                    'title': song['title'],
                    'artist': song['artist'],
                    'album': song.get('album'),
                    'filepath': result_msg,
                    'status': 'completed'
                })
            else:
                failed += 1
                print(f"❌ Download failed: '{song['artist']} - {song['title']}' - Error: {result_msg}")
                downloaded_songs.append({
                    'title': song['title'],
                    'artist': song['artist'],
                    'album': song.get('album'),
                    'error': result_msg,
                    'status': 'failed'
                })

            # Update final progress
            progress = int(((i + 1) / len(songs)) * 100)
            total_processed = completed + failed
            if total_processed < len(songs):
                status = "downloading"  # Still in progress
            elif failed > 0:
                status = "error"  # All done but some failed
            else:
                status = "completed"  # All successful

            update_download_status(
                download_id,
                status,
                total_songs=len(songs),
                completed_songs=completed,
                failed_songs=failed,
                progress=progress,
                songs=downloaded_songs.copy()
            )

            # Rate limiting (2 second delay between downloads)
            if len(songs) > 1:  # Only add delay between multiple songs
                await asyncio.sleep(2)

        except Exception as e:
            failed += 1
            downloaded_songs.append({
                'title': song['title'],
                'artist': song['artist'],
                'album': song.get('album'),
                'error': str(e),
                'status': 'error'
            })

    # Log final completion status
    download_type = "album" if len(songs) > 1 else "song"
    print(f"🎵 {download_type.upper()} DOWNLOAD COMPLETED: {completed}/{len(songs)} successful, {failed} failed (ID: {download_id})")

    # Create M3U playlist if multiple songs (album download)
    if len(songs) > 1 and completed > 0:
        try:
            successful_songs = [s for s in downloaded_songs if s['status'] == 'completed']
            if successful_songs:
                playlist_path = create_m3u_playlist(successful_songs, output_dir, f"{download_id}.m3u")
                print(f"📝 Created playlist: {playlist_path} with {len(successful_songs)} tracks")
                update_download_status(
                    download_id,
                    "completed",
                    playlist_path=playlist_path,
                    songs=downloaded_songs
                )
        except Exception as e:
            print(f"Error creating playlist: {e}")

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "service": "Tunes4R Download Service",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "POST /download/song": "Download single song",
            "POST /download/album": "Download entire album",
            "GET /status/{id}": "Check download status",
            "GET /download/{id}/playlist": "Get album playlist"
        }
    }

if __name__ == "__main__":
    # Run with: python download_service.py
    print("🎵 Tunes4R Download Service")
    print("Starting on http://localhost:8000")
    uvicorn.run(
        "download_service:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
        log_level="info"
    )
