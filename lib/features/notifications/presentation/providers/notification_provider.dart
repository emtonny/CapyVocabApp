// FR-NOTIF-01: 4 loại thông báo + badge chưa đọc
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-NOTIF-01: 4 loại thông báo + badge chưa đọc
class NotificationState {
  const NotificationState();
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-NOTIF-01: 4 loại thông báo + badge chưa đọc
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);
