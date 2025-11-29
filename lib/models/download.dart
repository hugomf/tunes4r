
/// Status of a download operation
enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled
}

extension DownloadStatusExtension on DownloadStatus {
  String get displayName {
    switch (this) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get icon {
    switch (this) {
      case DownloadStatus.queued:
        return '⏳';
      case DownloadStatus.downloading:
        return '⬇️';
      case DownloadStatus.completed:
        return '✅';
      case DownloadStatus.failed:
        return '❌';
      case DownloadStatus.cancelled:
        return '🚫';
    }
  }

  bool get isActive => this == DownloadStatus.queued || this == DownloadStatus.downloading;
  bool get isFinished => this == DownloadStatus.completed || this == DownloadStatus.failed || this == DownloadStatus.cancelled;
}

/// Represents a download operation in the queue
class DownloadItem {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final DownloadStatus status;
  final int progress; // 0-100
  final int totalSongs; // For album downloads
  final int completedSongs;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? errorMessage;
  final List<Map<String, dynamic>>? songs; // Songs info from API
  final String? playlistPath; // For album downloads

  DownloadItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.status,
    this.progress = 0,
    this.totalSongs = 1,
    this.completedSongs = 0,
    required this.createdAt,
    this.updatedAt,
    this.errorMessage,
    this.songs,
    this.playlistPath,
  });

  /// Creates a copy with updated fields
  DownloadItem copyWith({
    String? title,
    String? artist,
    String? album,
    DownloadStatus? status,
    int? progress,
    int? totalSongs,
    int? completedSongs,
    DateTime? updatedAt,
    String? errorMessage,
    List<Map<String, dynamic>>? songs,
    String? playlistPath,
  }) {
    return DownloadItem(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalSongs: totalSongs ?? this.totalSongs,
      completedSongs: completedSongs ?? this.completedSongs,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      songs: songs ?? this.songs,
      playlistPath: playlistPath ?? this.playlistPath,
    );
  }

  /// Creates from API response
  factory DownloadItem.fromApiResponse(String downloadId, Map<String, dynamic> response) {
    final songsInfo = response['songs_info'] as List<dynamic>?;

    return DownloadItem(
      id: downloadId,
      title: songsInfo?.firstOrNull?['title'] ?? 'Unknown Title',
      artist: songsInfo?.firstOrNull?['artist'] ?? 'Unknown Artist',
      album: songsInfo?.firstOrNull?['album'],
      status: DownloadStatus.queued,
      progress: 0,
      totalSongs: songsInfo?.length ?? 1,
      completedSongs: 0,
      createdAt: DateTime.now(),
      songs: songsInfo?.cast<Map<String, dynamic>>(),
    );
  }

  /// Updates from status response
  DownloadItem updateFromStatusResponse(Map<String, dynamic> statusResponse) {
    final progress = statusResponse['progress'] as int? ?? 0;
    final completedSongs = statusResponse['completed_songs'] as int? ?? 0;
    final failedSongs = statusResponse['failed_songs'] as int? ?? 0;
    final totalSongs = statusResponse['total_songs'] as int? ?? 1;
    final songs = statusResponse['songs'] as List<dynamic>?;

    DownloadStatus newStatus;
    String? errorMessage;

    switch (statusResponse['status']) {
      case 'starting':
      case 'searching_tracks':
        newStatus = DownloadStatus.queued;
        break;
      case 'downloading':
        // Check if any songs have errors - if so, the download has failed
        if (songs != null && songs.isNotEmpty) {
          final hasErrors = songs.any((song) => (song as Map<String, dynamic>).containsKey('error') && song['error'] != null);
          print('🎯 DEBUG: songs.length = ${songs.length}, hasErrors = $hasErrors');
          for (final song in songs) {
            final songMap = song as Map<String, dynamic>;
            print('🎯 DEBUG: song error = ${songMap['error']}');
          }
          if (hasErrors) {
            print('🎯 DEBUG: Setting status to FAILED due to song errors');
            newStatus = DownloadStatus.failed;
            errorMessage = statusResponse['error'] as String? ?? 'Download failed due to song errors';
            break;
          }
        }
        newStatus = DownloadStatus.downloading;
        break;
      case 'completed':
        newStatus = DownloadStatus.completed;
        break;
      default:
        newStatus = DownloadStatus.failed;
        errorMessage = statusResponse['error'] as String?;
    }

    return copyWith(
      status: newStatus,
      progress: progress,
      totalSongs: totalSongs,
      completedSongs: completedSongs,
      updatedAt: DateTime.now(),
      errorMessage: errorMessage,
      songs: songs?.cast<Map<String, dynamic>>(),
      playlistPath: statusResponse['playlist_path'] as String?,
    );
  }

  /// Serializes to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'status': status.index,
      'progress': progress,
      'totalSongs': totalSongs,
      'completedSongs': completedSongs,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'errorMessage': errorMessage,
      'songs': songs,
      'playlistPath': playlistPath,
    };
  }

  /// Deserializes from JSON storage
  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      status: DownloadStatus.values[json['status']],
      progress: json['progress'],
      totalSongs: json['totalSongs'],
      completedSongs: json['completedSongs'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      errorMessage: json['errorMessage'],
      songs: json['songs']?.cast<Map<String, dynamic>>(),
      playlistPath: json['playlistPath'],
    );
  }

  @override
  String toString() {
    return 'DownloadItem(id: $id, title: $title, artist: $artist, status: ${status.displayName}, progress: $progress%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Manager for download queue persistence and operations
class DownloadManager {
  static const String _downloadsKey = 'downloads_queue';
  final List<DownloadItem> _downloads = [];
  DateTime? _lastStatusCheck;
  static const Duration _statusCheckInterval = Duration(seconds: 5);

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  List<DownloadItem> get activeDownloads =>
      _downloads.where((d) => d.status.isActive).toList();

  List<DownloadItem> get completedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.completed).toList();

  List<DownloadItem> get failedDownloads =>
      _downloads.where((d) => d.status == DownloadStatus.failed).toList();

  /// Adds a new download to the queue
  void addDownload(DownloadItem download) {
    // Remove any existing download with same ID
    _downloads.removeWhere((d) => d.id == download.id);
    _downloads.insert(0, download); // Add to front for immediate processing
  }

  /// Updates download status/progress
  void updateDownload(String downloadId, Map<String, dynamic> statusResponse) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      final updated = _downloads[index].updateFromStatusResponse(statusResponse);
      _downloads[index] = updated;
    }
  }

  /// Removes a download from queue
  void removeDownload(String downloadId) {
    _downloads.removeWhere((d) => d.id == downloadId);
  }

  /// Clears completed/failed downloads older than specified duration
  void clearOldDownloads({Duration maxAge = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _downloads.removeWhere((d) =>
        (d.status == DownloadStatus.completed || d.status == DownloadStatus.failed) &&
        d.createdAt.isBefore(cutoff));
  }

  /// Gets download by ID
  DownloadItem? getDownload(String downloadId) {
    try {
      return _downloads.firstWhere((d) => d.id == downloadId);
    } catch (e) {
      return null;
    }
  }

  /// Retries a failed download
  void retryDownload(String downloadId) {
    final download = getDownload(downloadId);
    if (download != null && download.status == DownloadStatus.failed) {
      final retried = download.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        errorMessage: null,
        updatedAt: DateTime.now(),
      );
      final index = _downloads.indexOf(download);
      _downloads[index] = retried;
    }
  }

  /// Cancels a download
  void cancelDownload(String downloadId) {
    final download = getDownload(downloadId);
    if (download != null && download.status.isActive) {
      final cancelled = download.copyWith(
        status: DownloadStatus.cancelled,
        updatedAt: DateTime.now(),
      );
      final index = _downloads.indexOf(download);
      _downloads[index] = cancelled;
    }
  }

  /// Loads downloads from persistent storage
  void loadFromStorage(List<Map<String, dynamic>> data) {
    _downloads.clear();
    final downloads = data.map((json) => DownloadItem.fromJson(json)).toList();
    // Sort by creation time, newer first
    downloads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _downloads.addAll(downloads);
  }

  /// Saves downloads to persistent storage
  List<Map<String, dynamic>> saveToStorage() {
    return _downloads.map((d) => d.toJson()).toList();
  }

  /// Checks if it's time to refresh status from API
  /// Allows frequent checks when downloads need attention (queued, downloading, failed)
  bool shouldRefreshStatus() {
    if (_lastStatusCheck == null) return true;

    // Allow frequent checks (3 seconds) if there are downloads that need attention
    final hasActiveDownloads = _downloads.any((d) =>
        d.status == DownloadStatus.queued ||
        d.status == DownloadStatus.downloading ||
        d.status == DownloadStatus.failed);

    if (hasActiveDownloads) {
      // Check every 3 seconds for active/failed downloads
      return DateTime.now().difference(_lastStatusCheck!) >= const Duration(seconds: 3);
    } else {
      // Throttle to 5 seconds for completed/cancelled downloads only
      return DateTime.now().difference(_lastStatusCheck!) >= _statusCheckInterval;
    }
  }

  /// Updates last status check time
  void markStatusRefreshed() {
    _lastStatusCheck = DateTime.now();
  }
}
