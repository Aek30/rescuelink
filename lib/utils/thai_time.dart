/// Formats instants for display in Thailand, regardless of the phone timezone.
/// Stored timestamps and elapsed-time calculations must keep the original value.
abstract final class ThaiTime {
  static String format(DateTime instant) {
    final bangkok = instant.toUtc().add(const Duration(hours: 7));
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(bangkok.day)}/${two(bangkok.month)}/${bangkok.year} '
        '${two(bangkok.hour)}:${two(bangkok.minute)}:${two(bangkok.second)}';
  }
}
