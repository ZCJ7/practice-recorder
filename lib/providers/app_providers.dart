import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/archive_folder.dart';
import '../models/session.dart';
import '../models/video_clip.dart';
import '../models/video_status.dart';
import '../services/media_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());

/// null = 全部；'' = 未归档；其他 = 文件夹 id
final historyFolderFilterProvider = StateProvider<String?>((ref) => null);

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);

class HomeState {
  final Session? activeSession;
  final List<Session> history;
  final List<ArchiveFolder> archives;
  final Map<String, int> archiveCounts;
  final int unfiledCount;
  final String? filter;

  const HomeState({
    this.activeSession,
    this.history = const [],
    this.archives = const [],
    this.archiveCounts = const {},
    this.unfiledCount = 0,
    this.filter,
  });

  HomeState copyWith({
    Session? activeSession,
    List<Session>? history,
    List<ArchiveFolder>? archives,
    Map<String, int>? archiveCounts,
    int? unfiledCount,
    String? filter,
    bool clearActive = false,
    bool clearFilter = false,
  }) {
    return HomeState(
      activeSession:
          clearActive ? null : (activeSession ?? this.activeSession),
      history: history ?? this.history,
      archives: archives ?? this.archives,
      archiveCounts: archiveCounts ?? this.archiveCounts,
      unfiledCount: unfiledCount ?? this.unfiledCount,
      filter: clearFilter ? null : (filter ?? this.filter),
    );
  }
}

class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    // Read once — filter changes go through setHistoryFilter to avoid
    // AsyncLoading rebuilds that dispose chips/sheets mid-gesture.
    return _load(ref.read(historyFolderFilterProvider));
  }

  Future<HomeState> _load(String? filter) async {
    final db = ref.read(databaseProvider);
    final active = await db.getActiveSession();
    final archives = await db.getArchives();
    final counts = await db.getArchiveSessionCounts();
    final unfiled = await db.getUnfiledPastSessions();

    final List<Session> history;
    if (filter == null) {
      history = await db.getPastSessions();
    } else if (filter.isEmpty) {
      history = unfiled;
    } else {
      history = await db.getPastSessions(folderId: filter);
    }

    return HomeState(
      activeSession: active,
      history: history,
      archives: archives,
      archiveCounts: counts,
      unfiledCount: unfiled.length,
      filter: filter,
    );
  }

  Future<void> setHistoryFilter(String? filter) async {
    ref.read(historyFolderFilterProvider.notifier).state = filter;
    state = AsyncData(await _load(filter));
  }

  Future<Session> startSession() async {
    final db = ref.read(databaseProvider);
    final existing = await db.getActiveSession();
    if (existing != null) return existing;

    final session = Session(
      id: const Uuid().v4(),
      startTime: DateTime.now(),
    );
    await db.upsertSession(session);
    await refresh();
    return session;
  }

  Future<void> refresh() async {
    // Keep previous UI mounted — switching to AsyncLoading unmounts chips /
    // sheets mid-gesture and triggers '_dependents.isEmpty'.
    state = AsyncData(await _load(ref.read(historyFolderFilterProvider)));
  }

  Future<ArchiveFolder> createArchive(String name) async {
    final db = ref.read(databaseProvider);
    final folder = ArchiveFolder(
      id: const Uuid().v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    await db.upsertArchive(folder);
    await refresh();
    return folder;
  }

  Future<void> renameArchive(String id, String name) async {
    final db = ref.read(databaseProvider);
    await db.renameArchive(id, name.trim());
    await refresh();
  }

  Future<void> deleteArchive(String id) async {
    final db = ref.read(databaseProvider);
    await db.deleteArchive(id);
    final filter = ref.read(historyFolderFilterProvider);
    if (filter == id) {
      ref.read(historyFolderFilterProvider.notifier).state = null;
    }
    await refresh();
  }

  Future<void> moveSessionToFolder({
    required String sessionId,
    String? folderId,
  }) async {
    final db = ref.read(databaseProvider);
    await db.setSessionFolder(sessionId: sessionId, folderId: folderId);
    await refresh();
  }

  Future<void> deleteSession(String sessionId) async {
    final db = ref.read(databaseProvider);
    final media = ref.read(mediaServiceProvider);
    await media.deleteSessionFiles(sessionId);
    await db.deleteSession(sessionId);
    await refresh();
  }
}

final sessionControllerProvider = AsyncNotifierProvider.family<
    SessionController, SessionViewState, String>(SessionController.new);

class SessionViewState {
  final Session session;
  final SessionStats stats;
  final VideoClip? best;
  final List<VideoClip> videos;
  final bool compareNextRecording;

  const SessionViewState({
    required this.session,
    required this.stats,
    required this.videos,
    this.best,
    this.compareNextRecording = false,
  });

  SessionViewState copyWith({
    Session? session,
    SessionStats? stats,
    VideoClip? best,
    List<VideoClip>? videos,
    bool? compareNextRecording,
    bool clearBest = false,
  }) {
    return SessionViewState(
      session: session ?? this.session,
      stats: stats ?? this.stats,
      best: clearBest ? null : (best ?? this.best),
      videos: videos ?? this.videos,
      compareNextRecording:
          compareNextRecording ?? this.compareNextRecording,
    );
  }
}

class SessionController extends FamilyAsyncNotifier<SessionViewState, String> {
  @override
  Future<SessionViewState> build(String sessionId) async {
    final db = ref.read(databaseProvider);
    final session = await db.getSession(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }
    final videos = await db.getVideosForSession(sessionId);
    final stats = await db.getSessionStats(sessionId);
    final best = await db.getBestVideo(sessionId);
    return SessionViewState(
      session: session,
      stats: stats,
      videos: videos,
      best: best,
    );
  }

  Future<void> refresh({bool? compareNextRecording}) async {
    final currentFlag =
        compareNextRecording ?? state.value?.compareNextRecording ?? false;
    final next = await build(arg);
    state = AsyncData(
      next.copyWith(compareNextRecording: currentFlag),
    );
  }

  void setCompareNext(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(compareNextRecording: value));
  }

  Future<VideoClip> registerRecording({
    required String filePath,
    required int durationSeconds,
  }) async {
    final db = ref.read(databaseProvider);
    final version = await db.nextVersionIndex(arg);
    final id = const Uuid().v4();

    // Keep takes app-local until classified; only KEEP/BEST go to gallery.
    final clip = VideoClip(
      id: id,
      sessionId: arg,
      localUri: filePath,
      durationSeconds: durationSeconds,
      status: VideoStatus.delete, // provisional until classified
      createdAt: DateTime.now(),
      versionIndex: version,
    );
    await db.insertVideo(clip);
    await refresh();
    return clip;
  }

  Future<void> _ensureInGallery(VideoClip video) async {
    if (video.inGallery) return;
    if (video.status != VideoStatus.best && video.status != VideoStatus.keep) {
      return;
    }
    final db = ref.read(databaseProvider);
    final media = ref.read(mediaServiceProvider);
    try {
      await media.syncClipToGalleryAlbum(
        videoId: video.id,
        filePath: video.localUri,
        status: video.status,
        versionIndex: video.versionIndex,
        note: video.note,
      );
      await db.updateVideo(video.copyWith(inGallery: true));
    } catch (_) {
      // Local file remains available in-app.
    }
  }

  /// New best →「最佳」; previous best → leave「最佳」and land in「保留」.
  Future<void> _reassignBestInGallery({
    required VideoClip newBest,
    VideoClip? previousBest,
  }) async {
    final db = ref.read(databaseProvider);
    final media = ref.read(mediaServiceProvider);

    if (previousBest != null && previousBest.id != newBest.id) {
      try {
        await media.syncClipToGalleryAlbum(
          videoId: previousBest.id,
          filePath: previousBest.localUri,
          status: VideoStatus.keep,
          versionIndex: previousBest.versionIndex,
          note: previousBest.note,
        );
        await db.updateVideo(previousBest.copyWith(inGallery: true));
      } catch (_) {}
    }

    try {
      await media.syncClipToGalleryAlbum(
        videoId: newBest.id,
        filePath: newBest.localUri,
        status: VideoStatus.best,
        versionIndex: newBest.versionIndex,
        note: newBest.note,
      );
      await db.updateVideo(newBest.copyWith(inGallery: true));
    } catch (_) {}
  }

  Future<void> classify({
    required String videoId,
    required VideoStatus status,
    String? note,
  }) async {
    final db = ref.read(databaseProvider);
    if (status == VideoStatus.best) {
      final previousBest = await db.getBestVideo(arg);
      await db.setAsBest(sessionId: arg, videoId: videoId);
      var video = await db.getVideo(videoId);
      if (video == null) return;
      if (note != null) {
        video = video.copyWith(note: note);
        await db.updateVideo(video);
      }
      await _reassignBestInGallery(
        newBest: video,
        previousBest: previousBest,
      );
    } else {
      final video = await db.getVideo(videoId);
      if (video == null) return;
      final updated = video.copyWith(status: status, note: note);
      await db.updateVideo(updated);
      if (status == VideoStatus.keep) {
        await _ensureInGallery(updated);
      }
    }
    await refresh(compareNextRecording: false);
  }

  Future<void> promoteToBest(String videoId) async {
    final db = ref.read(databaseProvider);
    final previousBest = await db.getBestVideo(arg);
    await db.setAsBest(sessionId: arg, videoId: videoId);
    final video = await db.getVideo(videoId);
    if (video != null) {
      await _reassignBestInGallery(
        newBest: video,
        previousBest: previousBest,
      );
    }
    await refresh(compareNextRecording: false);
  }

  Future<SessionStats> endSession() async {
    final db = ref.read(databaseProvider);
    final current = await db.getSession(arg);
    if (current == null) throw StateError('Session not found');
    final now = DateTime.now();
    final duration = now.difference(current.startTime).inSeconds;
    final ended = current.copyWith(endTime: now, durationSeconds: duration);
    await db.upsertSession(ended);
    final stats = await db.getSessionStats(arg);
    await refresh();
    return stats;
  }

  Future<int> cleanupDeletes() async {
    final db = ref.read(databaseProvider);
    final media = ref.read(mediaServiceProvider);
    final doomed =
        await db.getVideosByStatus(arg, VideoStatus.delete);
    for (final v in doomed) {
      await media.deleteFile(v.localUri);
    }
    await db.deleteVideoRecords(doomed.map((e) => e.id).toList());
    await refresh();
    return doomed.length;
  }
}
