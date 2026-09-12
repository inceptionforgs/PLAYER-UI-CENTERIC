import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import '../config/media_config.dart';
import '../models/song.dart';

class DownloadsService {
  static final DownloadsService _instance = DownloadsService._internal();
  factory DownloadsService() => _instance;
  DownloadsService._internal();

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, Function(double progress, int total)?> _progressCallbacks = {};
  final Set<String> _inFlightTaskIds = {};

  Future<void>? _startFuture;

  Future<void> _ensureStarted() {
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    try {
      await FileDownloader().start();
    } catch (e) {
      _startFuture = null;
      if (kDebugMode) {
        debugPrint('FileDownloader.start error: $e');
      }
    }
  }

  Future<String> _getDownloadDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  String _getExtensionFromUrl(String audioUrl) {
    try {
      final uri = Uri.parse(audioUrl);
      final path = uri.path;
      if (path.contains('.')) {
        final ext = path.split('.').last;
        const allowed = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg'];
        if (allowed.contains(ext.toLowerCase())) {
          return ext.toLowerCase();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to parse extension from audio URL "$audioUrl": $e');
      }
    }
    return 'm4a';
  }

  Future<String> getLocalSongPath(String songId, {String? audioUrl}) async {
    final dirPath = await _getDownloadDirectory();
    final ext = audioUrl != null ? _getExtensionFromUrl(audioUrl) : 'm4a';
    return '$dirPath/MewatiOfflineSongs/song_$songId.$ext';
  }

  Future<bool> isSongDownloaded(String songId, {String? audioUrl}) async {
    final filePath = await getLocalSongPath(songId, audioUrl: audioUrl);
    final file = File(filePath);
    if (!await file.exists()) return false;
    return await file.length() > 0;
  }

  void _emitProgress(String taskId, double progress) {
    if (progress < 0.0 || progress > 1.0) return;
    _progressCallbacks[taskId]?.call(progress, 0);
  }

  Future<void> downloadSong(
    Song song, {
    Function(double progress, int total)? onProgress,
  }) async {
    if (!MediaConfig.isAllowedAudioUrl(song.audioUrl)) {
      if (kDebugMode) {
        debugPrint(
            'DownloadsService: rejecting download for "${song.title}" — audio URL host not in CDN allowlist.');
      }
      throw Exception('Download rejected: audio URL host is not allowed.');
    }

    final ext = _getExtensionFromUrl(song.audioUrl);
    final filename = 'song_${song.id}.$ext';
    final taskId = 'song_${song.id}';

    if (!_inFlightTaskIds.add(taskId)) return;

    try {
      if (await isSongDownloaded(song.id, audioUrl: song.audioUrl)) return;

    await _ensureStarted();

    final task = DownloadTask(
      taskId: taskId,
      url: song.audioUrl,
      filename: filename,
      directory: 'MewatiOfflineSongs',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      allowPause: true,
    );

    if (onProgress != null) {
      _progressCallbacks[taskId] = onProgress;
    }
    _tasks[taskId] = task;

    try {
      // Progress must be taken from download()'s own onProgress.
      // FileDownloader.updates only emits for tasks WITHOUT a registered
      // callback — and download() always registers one internally, so the
      // old stream listener never fired. That's why the UI sat at 0%
      // until the green check appeared.
      final result = await FileDownloader().download(
        task,
        onProgress: (progress) => _emitProgress(taskId, progress),
      );

      _progressCallbacks.remove(taskId);
      _tasks.remove(taskId);

      if (result.status != TaskStatus.complete) {
        throw Exception('Download did not complete: ${result.status}');
      }

      final localPath = await getLocalSongPath(song.id, audioUrl: song.audioUrl);
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found on disk.');
      }
      if (await file.length() <= 0) {
        await file.delete();
        throw Exception('Downloaded file is empty.');
      }
    } catch (e) {
      _progressCallbacks.remove(taskId);
      _tasks.remove(taskId);
      try {
        await deleteSong(song.id, audioUrl: song.audioUrl);
      } catch (cleanupError) {
        if (kDebugMode) {
          debugPrint('Failed to clean up partial download for ${song.id}: $cleanupError');
        }
      }
      throw Exception('Download failed: ${e.toString()}');
    }
    } finally {
      _inFlightTaskIds.remove(taskId);
    }
  }

  Future<void> cancelDownload(String songId) async {
    final taskId = 'song_$songId';
    if (_tasks.containsKey(taskId)) {
      await FileDownloader().cancelTaskWithId(taskId);
      _tasks.remove(taskId);
      _progressCallbacks.remove(taskId);
    }
  }

  Future<void> deleteSong(String songId, {String? audioUrl}) async {
    final filePath = await getLocalSongPath(songId, audioUrl: audioUrl);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void dispose() {
    _progressCallbacks.clear();
    _tasks.clear();
  }
}
