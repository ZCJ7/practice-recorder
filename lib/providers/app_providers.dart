import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/session.dart';
import '../models/video_clip.dart';
import '../models/video_status.dart';
import '../services/media_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);

class HomeState {
  final Session? activeSession;
  final List<Session> history;

  const HomeState({this.activeSession, this.history = const []});

  HomeState copyWith({Session? activeSession, List<Session>? history}) {
    return HomeState(
      activeSession: activeSession ?? this.activeSession,
      history: history ?? this.history,
    );
  }
}

class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    final db = ref.read(databaseProvider);
    final active = await db.getActiveSession();
    final history = await db.getPastSessions();
    return HomeState(activeSession: active, history: history);
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
    state = AsyncData(HomeState(
      activeSession: session,
      history: state.value?.history ?? const [],
    ));
    return session;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
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
    final media = ref.read(mediaServiceProvider);
    final version = await db.nextVersionIndex(arg);
    final id = const Uuid().v4();

    // Persist into gallery album; keep app-local path as source of truth.
    try {
      await media.saveToGallery(filePath);
    } catch (_) {
      // Still keep local file if gallery write fails.
    }

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

  Future<void> classify({
    required String videoId,
    required VideoStatus status,
    String? note,
  }) async {
    final db = ref.read(databaseProvider);
    if (status == VideoStatus.best) {
      await db.setAsBest(sessionId: arg, videoId: videoId);
      final video = await db.getVideo(videoId);
      if (video != null && note != null) {
        await db.updateVideo(video.copyWith(note: note));
      }
    } else {
      final video = await db.getVideo(videoId);
      if (video == null) return;
      await db.updateVideo(video.copyWith(status: status, note: note));
    }
    await refresh(compareNextRecording: false);
  }

  Future<void> promoteToBest(String videoId) async {
    final db = ref.read(databaseProvider);
    await db.setAsBest(sessionId: arg, videoId: videoId);
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
