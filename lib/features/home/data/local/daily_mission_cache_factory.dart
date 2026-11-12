import '../../domain/daily_mission.dart';
import '../../../library/data/local/library_database_factory.dart';
import 'sqlite_daily_mission_cache.dart';

Future<DailyMissionCache> createDefaultDailyMissionCache() async {
  return SqliteDailyMissionCache(await openDefaultLibraryDatabase());
}
