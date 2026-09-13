import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/video_status.dart';

class MediaService {
  static const _galleryChannel = MethodChannel('com.practicerecorder/gallery');

  Future<void> setKeepScreenOn(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _galleryChannel.invokeMethod<void>('setKeepScreenOn', {'on': on});
    } catch (_) {}
  }

  Future<bool> ensurePermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    // Android < 13 storage fallback
    final storage = await Permission.storage.request();

    final camOk = camera.isGranted;
    final micOk = mic.isGranted;
    final mediaOk =
        photos.isGranted || videos.isGranted || storage.isGranted || Platform.isIOS;
    return camOk && micOk && (mediaOk || await Gal.hasAccess());
  }

  Future<Directory> sessionVideoDir(String sessionId) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'sessions', sessionId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> buildRecordingPath(String sessionId, String videoId) async {
    final dir = await sessionVideoDir(sessionId);
    return p.join(dir.path, '$videoId.mp4');
  }

  /// Unique across sessions — never delete by version alone.
  static String galleryDisplayName({
    required String videoId,
    required VideoStatus status,
    required int versionIndex,
    String? note,
  }) {
    final tag = switch (status) {
      VideoStatus.best => 'BEST',
      VideoStatus.keep => 'KEEP',
      VideoStatus.delete => 'TAKE',
    };
    final compact = videoId.replaceAll('-', '');
    final idPart = compact.length >= 8 ? compact.substring(0, 8) : compact;
    var notePart = (note ?? '').trim();
    notePart = notePart.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]+'), '_');
    if (notePart.length > 24) {
      notePart = notePart.substring(0, 24);
    }
    final suffix = notePart.isEmpty ? '' : '_$notePart';
    return '${tag}_${idPart}_v$versionIndex$suffix.mp4';
  }

  static String galleryAlbum(VideoStatus status) {
    return switch (status) {
      VideoStatus.best => 'Practice Recorder 最佳',
      VideoStatus.keep => 'Practice Recorder 保留',
      VideoStatus.delete => 'Practice Recorder',
    };
  }

  /// Export KEEP / BEST into the matching album. Returns display name.
  Future<String> saveToGallery({
    required String videoId,
    required String filePath,
    required VideoStatus status,
    required int versionIndex,
    String? note,
  }) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      await Gal.requestAccess(toAlbum: true);
    }

    final displayName = galleryDisplayName(
      videoId: videoId,
      status: status,
      versionIndex: versionIndex,
      note: note,
    );
    final labeled = await _labeledTempCopy(
      filePath: filePath,
      displayName: displayName,
    );
    try {
      await Gal.putVideo(
        labeled.path,
        album: galleryAlbum(status),
      );
    } finally {
      try {
        if (await labeled.exists()) await labeled.delete();
      } catch (_) {}
    }
    return displayName;
  }

  Future<File> _labeledTempCopy({
    required String filePath,
    required String displayName,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final out = File(p.join(tmpDir.path, displayName));
    await File(filePath).copy(out.path);
    return out;
  }

  Future<int> deleteFromGalleryByNames(List<String> displayNames) async {
    if (!Platform.isAndroid || displayNames.isEmpty) return 0;
    final names = displayNames.where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return 0;
    try {
      final result = await _galleryChannel.invokeMethod<int>(
        'deleteVideosByNames',
        {'names': names},
      );
      return result ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Remove this clip's BEST_/KEEP_ copies only, then write into the target album.
  Future<void> syncClipToGalleryAlbum({
    required String videoId,
    required String filePath,
    required VideoStatus status,
    required int versionIndex,
    String? note,
  }) async {
    await deleteFromGalleryByNames([
      galleryDisplayName(
        videoId: videoId,
        status: VideoStatus.best,
        versionIndex: versionIndex,
        note: note,
      ),
      galleryDisplayName(
        videoId: videoId,
        status: VideoStatus.keep,
        versionIndex: versionIndex,
        note: note,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await saveToGallery(
      videoId: videoId,
      filePath: filePath,
      status: status,
      versionIndex: versionIndex,
      note: note,
    );
  }

  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> deleteSessionFiles(String sessionId) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(root.path, 'sessions', sessionId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
