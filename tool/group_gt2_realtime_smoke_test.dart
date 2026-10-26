import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('Missing required GT2 smoke environment: $name');
  }
  return value;
}

void main() {
  test('exact-Staging announcement reaches an authenticated Realtime client',
      () async {
    final url = _required('CAPY_GT2_SUPABASE_URL');
    final anonKey = _required('CAPY_GT2_ANON_KEY');
    final teacherEmail = _required('CAPY_GT2_TEACHER_EMAIL');
    final teacherPassword = _required('CAPY_GT2_TEACHER_PASSWORD');
    final studentEmail = _required('CAPY_GT2_STUDENT_EMAIL');
    final studentPassword = _required('CAPY_GT2_STUDENT_PASSWORD');
    final groupId = _required('CAPY_GT2_GROUP_ID');
    final marker = _required('CAPY_GT2_REALTIME_MARKER');
    final requestId = _required('CAPY_GT2_REALTIME_REQUEST_ID');
    final subscriber = SupabaseClient(url, anonKey);
    final publisher = SupabaseClient(url, anonKey);
    RealtimeChannel? channel;

    try {
      final studentAuth = await subscriber.auth.signInWithPassword(
        email: studentEmail,
        password: studentPassword,
      );
      final teacherAuth = await publisher.auth.signInWithPassword(
        email: teacherEmail,
        password: teacherPassword,
      );
      expect(studentAuth.user, isNotNull);
      expect(teacherAuth.user, isNotNull);

      final subscribed = Completer<void>();
      final received = Completer<void>();
      final statuses = <RealtimeSubscribeStatus>[];
      channel = subscriber
          .channel('gt2-smoke-${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'learning_group_announcements',
            callback: (payload) {
              if (payload.newRecord['group_id'] == groupId &&
                  payload.newRecord['body'] == marker &&
                  !received.isCompleted) {
                received.complete();
              }
            },
          );
      channel.subscribe((status, error) {
        statuses.add(status);
        if (status == RealtimeSubscribeStatus.subscribed &&
            !subscribed.isCompleted) {
          subscribed.complete();
        }
        if (status != RealtimeSubscribeStatus.subscribed &&
            !subscribed.isCompleted) {
          subscribed.completeError(
            StateError('Realtime subscription ended with status $status.'),
          );
        }
      });

      await subscribed.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'Realtime subscription timeout; statuses=$statuses.',
        ),
      );
      final announcementId = await publisher.rpc<Object?>(
        'create_learning_group_announcement',
        params: {
          'p_group_id': groupId,
          'p_body': marker,
          'p_request_id': requestId,
        },
      );
      expect(announcementId, isA<String>());
      expect((announcementId! as String).length, 36);
      await received.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'Realtime event timeout after a successful subscription.',
        ),
      );
    } finally {
      if (channel != null) await subscriber.removeChannel(channel);
      await subscriber.auth.signOut();
      await publisher.auth.signOut();
      await subscriber.dispose();
      await publisher.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
