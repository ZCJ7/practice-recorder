class ArchiveFolder {
  final String id;
  final String name;
  final DateTime createdAt;

  const ArchiveFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  ArchiveFolder copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return ArchiveFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ArchiveFolder.fromMap(Map<String, Object?> map) {
    return ArchiveFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
