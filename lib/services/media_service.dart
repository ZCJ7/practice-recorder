import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaService {
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

  /// Save recorded file into system gallery album and return gallery-friendly path.
  Future<String> saveToGallery(String filePath) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      await Gal.requestAccess(toAlbum: true);
    }
    await Gal.putVideo(filePath, album: 'Practice Recorder');
    return filePath;
  }

  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // Gallery-managed copies may not be deletable via File API on all Android versions.
    }
    return false;
  }
}
