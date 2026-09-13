import 'video_status.dart';

class VideoClip {
  final String id;
  final String sessionId;
  final String localUri;
  final int durationSeconds;
  final VideoStatus status;
  final String? note;
  final DateTime createdAt;
  final int versionIndex;
  final bool inGallery;

  const VideoClip({
    required this.id,
    required this.sessionId,
    required this.localUri,
    required this.durationSeconds,
    required this.status,
    required this.createdAt,
    required this.versionIndex,
    this.note,
    this.inGallery = false,
  });

  VideoClip copyWith({
    String? id,
    String? sessionId,
    String? localUri,
    int? durationSeconds,
    VideoStatus? status,
    String? note,
    DateTime? createdAt,
    int? versionIndex,
    bool? inGallery,
    bool clearNote = false,
  }) {
    return VideoClip(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      localUri: localUri ?? this.localUri,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      versionIndex: versionIndex ?? this.versionIndex,
      inGallery: inGallery ?? this.inGallery,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'local_uri': localUri,
      'duration': durationSeconds,
      'status': status.dbValue,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
      'version_index': versionIndex,
      'in_gallery': inGallery ? 1 : 0,
    };
  }

  factory VideoClip.fromMap(Map<String, Object?> map) {
    return VideoClip(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      localUri: map['local_uri'] as String,
      durationSeconds: (map['duration'] as int?) ?? 0,
      status: VideoStatus.fromDb(map['status'] as String? ?? 'DELETE'),
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      versionIndex: (map['version_index'] as int?) ?? 0,
      inGallery: ((map['in_gallery'] as int?) ?? 0) == 1,
    );
  }
}

class SessionStats {
  final int recordCount;
  final int bestCount;
  final int keepCount;
  final int deleteCount;
  final int totalDurationSeconds;

  const SessionStats({
    required this.recordCount,
    required this.bestCount,
    required this.keepCount,
    required this.deleteCount,
    required this.totalDurationSeconds,
  });

  factory SessionStats.empty() => const SessionStats(
        recordCount: 0,
        bestCount: 0,
        keepCount: 0,
        deleteCount: 0,
        totalDurationSeconds: 0,
      );
}
