// FR-CHAT-01, FR-CHAT-02, FR-CHAT-03, UC-CHAT-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-CHAT-01, FR-CHAT-02, FR-CHAT-03, UC-CHAT-01
class ChatState {
  const ChatState();
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-CHAT-01, FR-CHAT-02, FR-CHAT-03, UC-CHAT-01
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(),
);
