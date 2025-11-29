# Tunes4R Download Service

A REST API service for downloading songs and entire albums using yt-dlp and YouTube as the audio source.

## Features

- 🎵 Download individual songs by artist/title
- 📀 Download entire albums automatically
- 🎯 MusicBrainz integration for accurate tracklists
- 📊 Real-time download progress tracking
- 🎵 Automatic M3U playlist generation
- 🔄 Async downloads with concurrent processing
- 📱 REST API with JSON responses

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Ensure yt-dlp is installed and in your PATH:
```bash
# If using pipx (recommended)
pipx install yt-dlp
# Or globally
pip install yt-dlp
```

## Quick Start

1. Start the service:
```bash
python download_service.py
```

2. The API will be available at `http://localhost:8000`

## API Endpoints

### POST `/download/song`
Download a single song.

**Request Body:**
```json
{
  "title": "bad guy",
  "artist": "Billie Eilish"
}
```

**Response:**
```json
{
  "message": "Started downloading song: bad guy by Billie Eilish",
  "download_id": "uuid-here",
  "status": "started",
  "songs_info": [
    {
      "title": "bad guy",
      "artist": "Billie Eilish",
      "album": null,
      "query": "Billie Eilish bad guy official audio lyrics"
    }
  ]
}
```

### POST `/download/album`
Download an entire album. The service will automatically find the tracklist using MusicBrainz API.

**Request Body:**
```json
{
  "artist": "Radiohead",
  "album": "OK Computer"
}
```

### GET `/status/{download_id}`
Check download progress and results.

**Response:**
```json
{
  "download_id": "uuid-here",
  "status": "completed",
  "progress": 100,
  "total_songs": 12,
  "completed_songs": 12,
  "songs": [
    {
      "title": "Airbag",
      "artist": "Radiohead",
      "album": "OK Computer",
      "filepath": "/path/to/downloaded_music/Radiohead - Airbag.mp3",
      "status": "completed"
    }
  ]
}
```

### GET `/`
Service health check and documentation.

## Usage Examples

### Download a Single Song
```bash
curl -X POST http://localhost:8000/download/song \
  -H "Content-Type: application/json" \
  -d '{"title": "Bohemian Rhapsody", "artist": "Queen"}'
```

### Download an Album
```bash
curl -X POST http://localhost:8000/download/album \
  -H "Content-Type: application/json" \
  -d '{"artist": "Pink Floyd", "album": "The Wall"}'
```

### Check Download Status
```bash
curl http://localhost:8000/status/your-download-id-here
```

## Album Download How It Works

1. **Search**: Queries MusicBrainz API for the exact album and artist
2. **Tracklist**: Retrieves the official tracklist from the release
3. **Download**: Downloads each track concurrently with rate limiting
4. **Metadata**: Fixes MP3 tags and creates M3U playlist
5. **Complete**: Returns download summary and playlist location

## MusicBrainz Integration

The service uses MusicBrainz API for accurate album information:
- Release IDs and track listings
- Proper track ordering
- Artist and album verification

Fallback mechanisms if MusicBrainz fails:
- Generates plausible track patterns
- Uses broader YouTube search terms

## File Output

Downloads are saved to `downloaded_music/` directory:
- Individual songs: `Artist - Title.mp3`
- Album playlists: `{download_id}.m3u`

## Configuration

The service includes built-in rate limiting and timeout protection:
- 2-second delay between downloads (YouTube-friendly)
- 10-minute timeout per download
- 50MB max file size limit
- 20-track max per album (configurable)

## Integration with Tunes4R

Files downloaded through this service can be directly imported into your Flutter Tunes4R app:

1. Copy downloaded files to your music directory
2. Use the existing playlist import feature
3. Import M3U files generated for albums

## Dependencies

- **FastAPI**: Modern async web framework
- **yt-dlp**: YouTube audio downloader
- **MusicBrainz API**: Official tracklist data
- **ffmpeg**: Metadata fixing (optional)
- **uvicorn**: ASGI server

## Error Handling

The API provides detailed error messages:
- 404: Album/track not found
- 400: Invalid requests or too many tracks
- Download failures include specific error messages

## Development

Run in development mode with auto-reload:
```bash
uvicorn download_service:app --reload --host 0.0.0.0 --port 8000
```

Interactive API docs available at: `http://localhost:8000/docs`

## License

Same as Tunes4R main project.
