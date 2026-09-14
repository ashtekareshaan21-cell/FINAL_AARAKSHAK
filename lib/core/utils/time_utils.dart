import 'package:intl/intl.dart';

/// Utilities for human-friendly time and relative duration formatting
class TimeUtils {
  static String formatRelativeTime(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  static String formatTimestamp(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }
}
