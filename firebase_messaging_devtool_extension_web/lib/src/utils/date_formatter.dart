/// Format a DateTime to a standard string format
String formatDateTime(DateTime dateTime) {
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
}

/// Ensure a number is formatted as two digits with leading zero if needed
String twoDigits(int n) {
  return n.toString().padLeft(2, '0');
}
