/// Small formatting helpers for the UI. Kept hand-rolled (no `intl`
/// package) on purpose — it's instructive to see how a "3h ago" label is
/// actually computed, and it keeps dependencies minimal.
library;

/// Returns a compact relative time like "just now", "5m ago", "3h ago",
/// "2d ago", or a real date for anything older ("12 Aug").
String timeAgo(DateTime then) {
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  // For anything older, a plain date reads better than "14w ago".
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${then.day} ${months[then.month - 1]}';
}

/// "Welcome back" vs "Good morning" style greeting for the home header.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Title-cased long date, e.g. "Saturday, 3 October 2026", for the header.
String longDateFor(DateTime now) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}
