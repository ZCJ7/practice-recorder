class Session {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;

  const Session({
    required this.id,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
  });

  bool get isActive => endTime == null;

  Session copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    bool clearEndTime = false,
  }) {
    return Session(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'duration': durationSeconds,
    };
  }

  factory Session.fromMap(Map<String, Object?> map) {
    return Session(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      durationSeconds: (map['duration'] as int?) ?? 0,
    );
  }
}
