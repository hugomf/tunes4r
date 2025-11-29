import 'dart:io';
import 'dart:convert';
import '../models/playlist_import.dart';

// Parser for different playlist formats
class PlaylistParser {
  // Parse M3U format (most common)
  static Future<ImportablePlaylist> parseM3U(File file) async {
    final content = await file.readAsString();
    final lines = LineSplitter.split(content).toList();

    final tracks = <ImportableTrack>[];
    String? playlistName;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip empty lines
      if (line.isEmpty) continue;

      // Parse extended M3U header
      if (line == '#EXTM3U') continue;

      // Parse playlist name
      if (line.startsWith('#PLAYLIST:')) {
        playlistName = line.substring(10).trim();
        continue;
      }

      // Parse track info line
      if (line.startsWith('#EXTINF:')) {
        final trackInfo = _parseExtInf(line);
        if (trackInfo != null) {
          tracks.add(trackInfo);
        }
        continue;
      }

      // Parse track path (skip comments)
      if (!line.startsWith('#')) {
        // If we have a track from EXTINF, add the path
        if (tracks.isNotEmpty && tracks.last.duration != null) {
          // EXTINF already parsed, this line is the path
          continue;
        } else {
          // Simple M3U entry
          try {
            final track = ImportableTrack.fromM3U(line);
            tracks.add(track);
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
    }

    return ImportablePlaylist(
      name: playlistName ?? _extractNameFromPath(file.path),
      tracks: tracks,
    );
  }

  // Parse PLS format
  static Future<ImportablePlaylist> parsePLS(File file) async {
    final content = await file.readAsString();
    final lines = LineSplitter.split(content).toList();

    final tracks = <ImportableTrack>[];
    String? playlistName;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        continue; // Header section
      }

      if (trimmed.startsWith('Title1=')) {
        playlistName = trimmed.substring(7);
        continue;
      }

      // Parse track entries
      final titleMatch = RegExp(r'Title(\d+)=(.*)').firstMatch(trimmed);
      final fileMatch = RegExp(r'File(\d+)=(.*)').firstMatch(trimmed);

      if (titleMatch != null) {
        final index = int.parse(titleMatch.group(1)!);
        final title = titleMatch.group(2)!;

        // Simple parsing - extract artist from title if present
        final parts = title.split(' - ');
        if (parts.length >= 2) {
          final track = ImportableTrack(
            title: parts.last.trim(),
            artist: parts.first.trim(),
            originalLine: title,
          );
          tracks.add(track);
        } else {
          final track = ImportableTrack(
            title: title,
            originalLine: title,
          );
          tracks.add(track);
        }
      }
    }

    return ImportablePlaylist(
      name: playlistName ?? _extractNameFromPath(file.path),
      tracks: tracks,
    );
  }

  // Auto-detect format and parse
  static Future<ImportablePlaylist> parseFile(File file) async {
    final extension = file.path.toLowerCase().split('.').last;

    switch (extension) {
      case 'm3u':
      case 'm3u8':
        return parseM3U(file);
      case 'pls':
        return parsePLS(file);
      default:
        // Try to detect by content
        final content = await file.readAsString();
        if (content.contains('#EXTM3U')) {
          return parseM3U(file);
        } else if (content.contains('[playlist]')) {
          return parsePLS(file);
        } else {
          throw UnsupportedError('Unsupported playlist format');
        }
    }
  }

  // Parse extended M3U track info
  static ImportableTrack? _parseExtInf(String line) {
    // Format: #EXTINF:duration,artist - title
    if (!line.startsWith('#EXTINF:')) return null;

    final content = line.substring(8); // Remove #EXTINF:
    final commaIndex = content.indexOf(',');

    if (commaIndex == -1) return null;

    final durationStr = content.substring(0, commaIndex);
    final infoStr = content.substring(commaIndex + 1);

    Duration? duration;
    if (durationStr != '-1') {
      final seconds = int.tryParse(durationStr);
      if (seconds != null) {
        duration = Duration(seconds: seconds);
      }
    }

    // Parse artist - title format
    final parts = infoStr.split(' - ');
    if (parts.length >= 2) {
      return ImportableTrack(
        title: parts.last.trim(),
        artist: parts.first.trim(),
        duration: duration,
        originalLine: line,
      );
    } else {
      return ImportableTrack(
        title: infoStr,
        duration: duration,
        originalLine: line,
      );
    }
  }

  // Extract playlist name from file path
  static String _extractNameFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1) {
      return fileName.substring(0, dotIndex);
    }
    return fileName;
  }
}

// Utility functions for playlist validation
class PlaylistValidator {
  static bool isValidPlaylistFile(File file) {
    // Check file extension
    final extension = file.path.toLowerCase().split('.').last;
    if (!['m3u', 'm3u8', 'pls'].contains(extension)) {
      return false;
    }

    // Check file exists and readable
    if (!file.existsSync()) return false;

    try {
      final content = file.readAsStringSync();
      return content.isNotEmpty &&
             (content.contains('#EXTM3U') ||
              content.contains('[playlist]') ||
              content.split('\n').any((line) => !line.startsWith('#') && line.trim().isNotEmpty));
    } catch (e) {
      return false;
    }
  }
}
