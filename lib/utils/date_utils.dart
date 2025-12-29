class DateUtils {
  // IST timezone offset: +5:30 hours
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Convert UTC DateTime to IST DateTime
  static DateTime toIST(DateTime utcDateTime) {
    return utcDateTime.add(istOffset);
  }

  /// Format DateTime in 12-hour format with AM/PM
  static String format12Hour(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Format DateTime in 12-hour format with date
  static String format12HourWithDate(DateTime dateTime) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[dateTime.month - 1];
    return '$month ${dateTime.day.toString().padLeft(2, '0')}, ${dateTime.year} ${format12Hour(dateTime)}';
  }

  /// Format DateTime in 12-hour format with day
  static String format12HourWithDay(DateTime dateTime) {
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dayNames[dateTime.weekday - 1];
    final month = monthNames[dateTime.month - 1];
    return '$day, $month ${dateTime.day.toString().padLeft(2, '0')} ${format12Hour(dateTime)}';
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  /// Check if a date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.day == tomorrow.day &&
        date.month == tomorrow.month &&
        date.year == tomorrow.year;
  }

  /// Format relative date with IST conversion and 12-hour format
  static String formatRelativeToIST(DateTime utcDateTime) {
    final istDateTime = toIST(utcDateTime);
    final now = DateTime.now();
    final difference = istDateTime.difference(now);

    if (isToday(istDateTime)) {
      return 'Today at ${format12Hour(istDateTime)}';
    } else if (isTomorrow(istDateTime)) {
      return 'Tomorrow at ${format12Hour(istDateTime)}';
    } else if (difference.inDays > 0) {
      return 'In ${difference.inDays} days at ${format12Hour(istDateTime)}';
    } else if (difference.inDays < 0) {
      return 'Overdue by ${(-difference.inDays)} days at ${format12Hour(istDateTime)}';
    } else {
      return format12HourWithDate(istDateTime);
    }
  }

  /// Format date for metadata display with IST conversion
  static String formatMetadataDate(DateTime utcDateTime) {
    final istDateTime = toIST(utcDateTime);
    final now = DateTime.now();
    final difference = now.difference(istDateTime);

    if (difference.inDays == 0) {
      return 'Today at ${format12Hour(istDateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${format12Hour(istDateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return format12HourWithDate(istDateTime);
    }
  }

  /// Format call history time with IST conversion
  /// Handles both UTC and local timezone DateTime objects
  static String formatCallTime(DateTime dateTime) {
    // Check if DateTime is in UTC (has UTC timezone indicator)
    // If it's already in local time, use it directly; otherwise convert from UTC to IST
    DateTime istDateTime;
    if (dateTime.isUtc) {
      istDateTime = toIST(dateTime);
    } else {
      // DateTime is already in local timezone, use it directly
      istDateTime = dateTime;
    }
    return format12Hour(istDateTime);
  }

  /// Format call history date with IST conversion
  /// Handles both UTC and local timezone DateTime objects
  static String formatCallDate(DateTime dateTime) {
    // Check if DateTime is in UTC (has UTC timezone indicator)
    // If it's already in local time, use it directly; otherwise convert from UTC to IST
    DateTime istDateTime;
    if (dateTime.isUtc) {
      istDateTime = toIST(dateTime);
    } else {
      // DateTime is already in local timezone, use it directly
      istDateTime = dateTime;
    }
    // Compare with current local time (not IST) for accurate day calculation
    final now = DateTime.now();
    final difference = now.difference(istDateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${istDateTime.day}/${istDateTime.month}/${istDateTime.year}';
    }
  }
}
