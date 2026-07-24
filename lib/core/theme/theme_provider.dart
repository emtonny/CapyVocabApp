// FR-SETT-01: Đổi chế độ Sáng / Tối, lưu preference (SharedPreferences)
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<bool>((ref) => false); // false = light
