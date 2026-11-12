final class WeeklyYuzuLeaderboardEntry {
  WeeklyYuzuLeaderboardEntry({
    required this.userId,
    required String displayName,
    required this.weeklyYuzu,
    required this.rankPosition,
    this.avatarUrl,
  }) : displayName = displayName.trim() {
    if (userId.trim().isEmpty || this.displayName.isEmpty) {
      throw ArgumentError('Leaderboard identity must not be empty');
    }
    if (weeklyYuzu < 0 || rankPosition <= 0) {
      throw ArgumentError('Leaderboard score and rank are invalid');
    }
  }

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int weeklyYuzu;
  final int rankPosition;

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'weekly_yuzu': weeklyYuzu,
        'rank_position': rankPosition,
      };

  static WeeklyYuzuLeaderboardEntry? fromJson(Map<String, Object?> json) {
    final userId = json['user_id'];
    final displayName = json['display_name'];
    final weeklyYuzu = _exactInt(json['weekly_yuzu']);
    final rankPosition = _exactInt(json['rank_position']);
    final avatarUrl = json['avatar_url'];
    if (userId is! String ||
        displayName is! String ||
        weeklyYuzu == null ||
        rankPosition == null ||
        (avatarUrl != null && avatarUrl is! String)) {
      return null;
    }
    try {
      return WeeklyYuzuLeaderboardEntry(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl as String?,
        weeklyYuzu: weeklyYuzu,
        rankPosition: rankPosition,
      );
    } on ArgumentError {
      return null;
    }
  }
}

final class WeeklyYuzuLeaderboard {
  WeeklyYuzuLeaderboard({
    required this.ownerId,
    required DateTime weekStart,
    required List<WeeklyYuzuLeaderboardEntry> entries,
    required DateTime updatedAt,
    this.isOffline = false,
  })  : weekStart = _utcDay(weekStart),
        entries = List.unmodifiable(entries),
        updatedAt = updatedAt.toUtc() {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
    }
    if (!this.entries.any((entry) => entry.userId == ownerId)) {
      throw ArgumentError('Leaderboard must include its owner');
    }
    final uniqueIds = this.entries.map((entry) => entry.userId).toSet();
    if (uniqueIds.length != this.entries.length) {
      throw ArgumentError('Leaderboard contains duplicate accounts');
    }
  }

  final String ownerId;
  final DateTime weekStart;
  final List<WeeklyYuzuLeaderboardEntry> entries;
  final DateTime updatedAt;
  final bool isOffline;

  WeeklyYuzuLeaderboard copyWith({bool? isOffline}) {
    return WeeklyYuzuLeaderboard(
      ownerId: ownerId,
      weekStart: weekStart,
      entries: entries,
      updatedAt: updatedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  Map<String, Object?> toJson() => {
        'owner_id': ownerId,
        'week_start': _dateString(weekStart),
        'updated_at': updatedAt.toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  static WeeklyYuzuLeaderboard? fromJson(
    Map<String, Object?> json, {
    required String ownerId,
  }) {
    if (json['owner_id'] != ownerId) return null;
    final weekStart = DateTime.tryParse('${json['week_start']}T00:00:00.000Z');
    final updatedAt = DateTime.tryParse('${json['updated_at']}');
    final rawEntries = json['entries'];
    if (weekStart == null || updatedAt == null || rawEntries is! List) {
      return null;
    }
    final entries = <WeeklyYuzuLeaderboardEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) return null;
      final entry = WeeklyYuzuLeaderboardEntry.fromJson(
        Map<String, Object?>.from(raw),
      );
      if (entry == null) return null;
      entries.add(entry);
    }
    try {
      return WeeklyYuzuLeaderboard(
        ownerId: ownerId,
        weekStart: weekStart,
        entries: entries,
        updatedAt: updatedAt,
        isOffline: true,
      );
    } on ArgumentError {
      return null;
    }
  }
}

DateTime weekStartForDay(DateTime day) {
  final utcDay = DateTime.utc(day.year, day.month, day.day);
  return utcDay.subtract(Duration(days: utcDay.weekday - DateTime.monday));
}

DateTime _utcDay(DateTime value) {
  final day = DateTime.utc(value.year, value.month, value.day);
  if (!value.isUtc || value != day || day.weekday != DateTime.monday) {
    throw ArgumentError.value(
      value,
      'weekStart',
      'must be a UTC calendar Monday',
    );
  }
  return day;
}

int? _exactInt(Object? value) {
  if (value is! num) return null;
  final integer = value.toInt();
  return integer == value ? integer : null;
}

String _dateString(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
