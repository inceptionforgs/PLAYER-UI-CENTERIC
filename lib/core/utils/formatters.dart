String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 1000000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)}K';
  }
  if (count < 1000000000) {
    final value = count / 1000000;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)}M';
  }
  final value = count / 1000000000;
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)}B';
}

String formatDurationSeconds(int seconds) {
  if (seconds < 0) seconds = 0;
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
