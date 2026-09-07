enum VideoStatus {
  best,
  keep,
  delete;

  String get dbValue => name.toUpperCase();

  static VideoStatus fromDb(String value) {
    switch (value.toUpperCase()) {
      case 'BEST':
        return VideoStatus.best;
      case 'KEEP':
        return VideoStatus.keep;
      case 'DELETE':
        return VideoStatus.delete;
      default:
        return VideoStatus.delete;
    }
  }

  String get label {
    switch (this) {
      case VideoStatus.best:
        return '最佳';
      case VideoStatus.keep:
        return '保留';
      case VideoStatus.delete:
        return '待删除';
    }
  }
}
