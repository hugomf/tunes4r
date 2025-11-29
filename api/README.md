# Tunes4R API Services

This directory contains backend services for Tunes4R.

## 📥 Download Service (`download_service.py`)

A REST API for downloading individual songs and entire albums using YouTube as the audio source.

### Features
- 🎵 Download individual songs
- 📀 Download entire albums automatically
- 🎯 MusicBrainz integration for accurate tracklists
- 📊 Real-time progress tracking
- 🎵 Auto-generated M3U playlists for albums

### Quick Start
```bash
cd api
pip install -r requirements.txt
python download_service.py
```

### Documentation
See `DOWNLOAD_SERVICE_README.md` for complete API documentation and usage examples.

### API Endpoints
- `POST /download/song` - Download individual songs
- `POST /download/album` - Download entire albums
- `GET /status/{id}` - Check download progress
- `GET /docs` - Interactive API documentation

## 🚀 For Production

The download service can be deployed as a standalone microservice and integrated with:
- Web interfaces
- Mobile apps
- Command-line clients
- Other music applications

Files downloaded through this service can be directly imported into the main Tunes4R Flutter app.
