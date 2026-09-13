import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/archive_folder.dart';
import '../models/session.dart';
import '../models/video_clip.dart';
import '../models/video_status.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'practice_recorder.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE archives (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            duration INTEGER NOT NULL DEFAULT 0,
            folder_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE videos (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            local_uri TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL,
            version_index INTEGER NOT NULL,
            in_gallery INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(session_id) REFERENCES sessions(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_videos_session ON videos(session_id)',
        );
        await db.execute(
          'CREATE INDEX idx_sessions_folder ON sessions(folder_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE videos ADD COLUMN in_gallery INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS archives (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'ALTER TABLE sessions ADD COLUMN folder_id TEXT',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sessions_folder ON sessions(folder_id)',
          );
        }
      },
    );
  }

  Future<List<ArchiveFolder>> getArchives() async {
    final db = await database;
    final rows = await db.query('archives', orderBy: 'created_at ASC');
    return rows.map(ArchiveFolder.fromMap).toList();
  }

  Future<void> upsertArchive(ArchiveFolder folder) async {
    final db = await database;
    await db.insert(
      'archives',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameArchive(String id, String name) async {
    final db = await database;
    await db.update(
      'archives',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteArchive(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'sessions',
        {'folder_id': null},
        where: 'folder_id = ?',
        whereArgs: [id],
      );
      await txn.delete('archives', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setSessionFolder({
    required String sessionId,
    String? folderId,
  }) async {
    final db = await database;
    await db.update(
      'sessions',
      {'folder_id': folderId},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> upsertSession(Session session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Session?> getSession(String id) async {
    final db = await database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  Future<Session?> getActiveSession() async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  Future<List<Session>> getPastSessions({String? folderId}) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: folderId == null
          ? 'end_time IS NOT NULL'
          : 'end_time IS NOT NULL AND folder_id = ?',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: 'start_time DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  Future<List<Session>> getUnfiledPastSessions() async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'end_time IS NOT NULL AND folder_id IS NULL',
      orderBy: 'start_time DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  Future<Map<String, int>> getArchiveSessionCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT folder_id, COUNT(*) as cnt
      FROM sessions
      WHERE end_time IS NOT NULL AND folder_id IS NOT NULL
      GROUP BY folder_id
    ''');
    final map = <String, int>{};
    for (final row in rows) {
      final id = row['folder_id'] as String?;
      if (id != null) {
        map[id] = (row['cnt'] as int?) ?? 0;
      }
    }
    return map;
  }

  Future<void> insertVideo(VideoClip video) async {
    final db = await database;
    await db.insert('videos', video.toMap());
  }

  Future<void> updateVideo(VideoClip video) async {
    final db = await database;
    await db.update(
      'videos',
      video.toMap(),
      where: 'id = ?',
      whereArgs: [video.id],
    );
  }

  Future<List<VideoClip>> getVideosForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'version_index ASC',
    );
    return rows.map(VideoClip.fromMap).toList();
  }

  Future<VideoClip?> getBestVideo(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'session_id = ? AND status = ?',
      whereArgs: [sessionId, VideoStatus.best.dbValue],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VideoClip.fromMap(rows.first);
  }

  Future<VideoClip?> getVideo(String id) async {
    final db = await database;
    final rows = await db.query('videos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return VideoClip.fromMap(rows.first);
  }

  Future<int> nextVersionIndex(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(version_index) as max_v FROM videos WHERE session_id = ?',
      [sessionId],
    );
    final max = result.first['max_v'] as int?;
    return (max ?? 0) + 1;
  }

  Future<SessionStats> getSessionStats(String sessionId) async {
    final videos = await getVideosForSession(sessionId);
    var best = 0;
    var keep = 0;
    var delete = 0;
    var totalDuration = 0;
    for (final v in videos) {
      totalDuration += v.durationSeconds;
      switch (v.status) {
        case VideoStatus.best:
          best++;
        case VideoStatus.keep:
          keep++;
        case VideoStatus.delete:
          delete++;
      }
    }
    return SessionStats(
      recordCount: videos.length,
      bestCount: best,
      keepCount: keep,
      deleteCount: delete,
      totalDurationSeconds: totalDuration,
    );
  }

  /// Demote existing BEST to KEEP, then set target as BEST.
  Future<void> setAsBest({
    required String sessionId,
    required String videoId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'videos',
        {'status': VideoStatus.keep.dbValue},
        where: 'session_id = ? AND status = ?',
        whereArgs: [sessionId, VideoStatus.best.dbValue],
      );
      await txn.update(
        'videos',
        {'status': VideoStatus.best.dbValue},
        where: 'id = ?',
        whereArgs: [videoId],
      );
    });
  }

  Future<List<VideoClip>> getVideosByStatus(
    String sessionId,
    VideoStatus status,
  ) async {
    final db = await database;
    final rows = await db.query(
      'videos',
      where: 'session_id = ? AND status = ?',
      whereArgs: [sessionId, status.dbValue],
    );
    return rows.map(VideoClip.fromMap).toList();
  }

  Future<void> deleteVideoRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'videos',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete('videos', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}
