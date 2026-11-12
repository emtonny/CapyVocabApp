import 'weekly_yuzu_leaderboard.dart';

enum YuzuLeaderboardPeriod {
  total('Tổng'),
  day('Hôm nay'),
  week('Tuần này'),
  month('Tháng này');

  const YuzuLeaderboardPeriod(this.label);
  final String label;
}

final class PeriodYuzuLeaderboard {
  PeriodYuzuLeaderboard({
    required this.entries,
    required this.updatedAt,
  });

  // The existing entry DTO's weeklyYuzu field holds the selected period score.
  final List<WeeklyYuzuLeaderboardEntry> entries;
  final DateTime updatedAt;
}
