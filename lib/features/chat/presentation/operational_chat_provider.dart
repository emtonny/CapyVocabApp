import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../language_profile/presentation/language_profile_provider.dart';
import '../application/operational_chat_coordinator.dart';
import '../data/chat_network_status_native.dart'
    if (dart.library.js_interop) '../data/chat_network_status_web.dart'
    as network;
import '../data/operational_chat_database.dart';
import '../data/operational_chat_store.dart';
import '../data/operational_chat_supabase_gateway.dart';
import '../domain/operational_chat.dart';

final operationalChatEnabledProvider = Provider<bool>((_) =>
    const bool.fromEnvironment('CHAT_RELAY_ENABLED', defaultValue: false));
final operationalChatClientProvider =
    Provider<SupabaseClient>((_) => SupabaseService.client);

bool operationalChatRuntimeActiveForLifecycle(
  AppLifecycleState? state, {
  bool web = kIsWeb,
}) =>
    web || state == null || state == AppLifecycleState.resumed;

final operationalChatForegroundProvider = StateProvider<bool>((_) {
  return operationalChatRuntimeActiveForLifecycle(
    WidgetsBinding.instance.lifecycleState,
  );
});
final operationalChatNetworkProvider =
    Provider<Future<bool> Function()>((_) => network.chatNetworkAvailable);

final operationalChatSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(operationalChatClientProvider);
  return Stream.multi((controller) {
    final subscription = client.auth.onAuthStateChange.listen(
        (state) => controller.add(state.session),
        onError: (Object _) => controller.add(null),
        onDone: controller.close);
    controller.onCancel = subscription.cancel;
    controller.add(client.auth.currentSession);
  });
});

bool _staging(SupabaseClient client) {
  final url = Uri.tryParse(client.rest.url);
  return url?.scheme == 'https' &&
      url?.host == '${OperationalChatSupabaseGateway.stagingRef}.supabase.co';
}

final operationalChatOwnerProvider = Provider<ChatOwner?>((ref) {
  final client = ref.watch(operationalChatClientProvider);
  if (!_staging(client)) return null;
  ref.watch(operationalChatSessionProvider);
  // The actual SDK session is authoritative: never reuse AsyncValue's old A
  // data during B's loading/signout/token refresh.
  final session = client.auth.currentSession;
  if (session == null) return null;
  return ChatOwner(
      projectRef: OperationalChatSupabaseGateway.stagingRef,
      userId: session.user.id);
});

final operationalChatDatabaseProvider =
    FutureProvider<OperationalChatDatabase>((ref) async {
  var live = true;
  OperationalChatDatabase? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.close());
  });
  final database = await createOperationalChatDatabase();
  resource = database;
  if (!live) {
    await database.close();
    throw StateError('Chat database disposed.');
  }
  return database;
});

/// Owner-keyed reads stay independent of token refresh and network/runtime.
final operationalChatStoreProvider = FutureProvider.autoDispose
    .family<OperationalChatStore?, ChatOwner>((ref, owner) async {
  if (ref.watch(operationalChatOwnerProvider) != owner) return null;
  var live = true;
  OperationalChatStore? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.dispose());
  });
  final local = await ref.watch(operationalChatDatabaseProvider.future);
  if (!live) return null;
  final database = await local.open();
  if (!live || ref.read(operationalChatOwnerProvider) != owner) {
    return null;
  }
  final store = OperationalChatStore(database: database, owner: owner);
  resource = store;
  return store;
});

final operationalChatCoordinatorProvider =
    FutureProvider.autoDispose<OperationalChatCoordinator?>((ref) async {
  if (!ref.watch(operationalChatEnabledProvider) ||
      !ref.watch(operationalChatForegroundProvider)) {
    return null;
  }
  final client = ref.watch(operationalChatClientProvider);
  if (!_staging(client)) return null;
  ref.watch(operationalChatSessionProvider);
  final session = client.auth.currentSession;
  final owner = ref.watch(operationalChatOwnerProvider);
  if (session == null || owner == null) return null;
  final profileStore = ref.watch(languageProfileStoreProvider); // cache only
  final networkAvailable = ref.watch(operationalChatNetworkProvider);
  var live = true;
  OperationalChatCoordinator? resource;
  void profileChanged() => resource?.requestRefresh();
  ref.onDispose(() {
    live = false;
    profileStore.removeListener(profileChanged);
    unawaited(resource?.dispose());
  });
  bool current() =>
      live &&
      client.auth.currentSession?.user.id == owner.userId &&
      client.auth.currentSession?.accessToken == session.accessToken;
  final store = await ref.watch(operationalChatStoreProvider(owner).future);
  if (!current() || store == null) return null;
  final key = client.realtime.params['apikey'];
  if (key is! String || key.isEmpty) {
    throw StateError('Chat public key unavailable.');
  }
  final gateway = OperationalChatSupabaseGateway.staging(
      owner: owner,
      session: session,
      publishableKey: key,
      isCurrentSession: current);
  final coordinator = OperationalChatCoordinator(
      store: store,
      remote: gateway,
      isCurrentSession: current,
      networkAvailable: () async =>
          !session.isExpired && await networkAvailable(),
      cachedSourceLanguageCode: () {
        final profile = profileStore.profileFor(owner.userId);
        return profile?.isValid == true && profile?.userId == owner.userId
            ? profile!.nativeLanguageCode
            : null;
      });
  resource = coordinator;
  profileStore.addListener(profileChanged);
  coordinator.start();
  return coordinator;
});

final operationalChatInboxProvider = StreamProvider.autoDispose
    .family<List<ChatConversation>, ChatOwner>((ref, owner) async* {
  final store = await ref.watch(operationalChatStoreProvider(owner).future);
  if (store == null) {
    yield [];
    return;
  }
  yield* store.watchConversations();
});

final operationalChatMessagesProvider = StreamProvider.autoDispose
    .family<List<OperationalChatMessage>, (ChatOwner, String)>(
        (ref, key) async* {
  final store = await ref.watch(operationalChatStoreProvider(key.$1).future);
  if (store == null) {
    yield [];
    return;
  }
  yield* store.watchMessages(key.$2);
});

final operationalChatPeerProfilesProvider = StreamProvider.autoDispose
    .family<List<ChatPeerProfile>, ChatOwner>((ref, owner) async* {
  final store = await ref.watch(operationalChatStoreProvider(owner).future);
  if (store == null) {
    yield [];
    return;
  }
  yield* store.watchProfiles();
});

/// Refreshes the approved public projection in one bounded request. The UI
/// always reads the local cache, so a network failure never blanks known names.
final operationalChatProfileRefreshProvider =
    FutureProvider.autoDispose.family<void, ChatOwner>((ref, owner) async {
  if (!ref.watch(operationalChatEnabledProvider) ||
      ref.watch(operationalChatOwnerProvider) != owner) {
    return;
  }
  final storeFuture = ref.watch(operationalChatStoreProvider(owner).future);
  final friendsFuture = ref.watch(operationalChatFriendsProvider(owner).future);
  final store = await storeFuture;
  if (store == null) return;
  final conversations = await store.conversations();
  List<String> friends;
  try {
    friends = await friendsFuture;
  } catch (_) {
    friends = const [];
  }
  final ids = <String>{
    ...friends,
    ...conversations.map((conversation) => conversation.peerId),
  }.toList()
    ..sort();
  if (ids.isEmpty ||
      !await ref
          .read(operationalChatNetworkProvider)()
          .timeout(const Duration(seconds: 3))) {
    return;
  }
  final client = ref.watch(operationalChatClientProvider);
  final session = client.auth.currentSession;
  if (session == null || session.isExpired || session.user.id != owner.userId) {
    return;
  }
  try {
    final response = await client.rpc('get_public_profiles',
        params: {'profile_ids': ids}).timeout(const Duration(seconds: 12));
    if (ref.read(operationalChatOwnerProvider) != owner || response is! List) {
      return;
    }
    final allowed = ids.toSet();
    final profiles = <ChatPeerProfile>[];
    final seen = <String>{};
    for (final value in response) {
      if (value is! Map) throw const FormatException('Invalid profile list.');
      final profile =
          ChatPeerProfile.fromRemote(Map<String, dynamic>.from(value));
      if (!allowed.contains(profile.id) || !seen.add(profile.id)) {
        throw const FormatException('Invalid profile identity.');
      }
      profiles.add(profile);
    }
    if (ref.read(operationalChatOwnerProvider) == owner) {
      await store.cacheProfiles(profiles);
    }
  } catch (_) {
    // Cached labels remain usable; profile decoration is not chat-critical.
  }
});

/// Cache notifications only: opening a page must not fetch a profile.
final operationalChatSourceProvider =
    StreamProvider.autoDispose.family<String?, ChatOwner>((ref, owner) {
  final store = ref.watch(languageProfileStoreProvider);
  return Stream.multi((controller) {
    void emit() {
      final profile = store.profileFor(owner.userId);
      controller.add(profile?.isValid == true && profile?.userId == owner.userId
          ? profile!.nativeLanguageCode
          : null);
    }

    store.addListener(emit);
    controller.onCancel = () => store.removeListener(emit);
    emit();
  });
});

/// Watched by explicit Friends navigation/new-chat picker, not inbox/detail.
/// The open_direct_chat RPC remains authoritative for mutual acceptance.
final operationalChatFriendsProvider = FutureProvider.autoDispose
    .family<List<String>, ChatOwner>((ref, owner) async {
  if (!ref.watch(operationalChatEnabledProvider) ||
      ref.watch(operationalChatOwnerProvider) != owner) {
    return [];
  }
  final client = ref.watch(operationalChatClientProvider);
  final session = client.auth.currentSession;
  var live = true;
  ref.onDispose(() => live = false);
  bool current() =>
      live &&
      session != null &&
      client.auth.currentSession?.accessToken == session.accessToken &&
      client.auth.currentSession?.user.id == owner.userId;
  try {
    if (session == null ||
        session.isExpired ||
        !await ref
            .read(operationalChatNetworkProvider)()
            .timeout(const Duration(seconds: 3)) ||
        !current()) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    final ids = <String>{};
    String? after;
    for (var page = 0; page < 1000; page++) {
      if (!current()) throw const ChatRefreshSuperseded();
      var query = client
          .from('friends')
          .select('friend_id')
          .eq('user_id', owner.userId)
          .eq('status', 'accepted');
      if (after != null) query = query.gt('friend_id', after);
      final rows = await query
          .order('friend_id', ascending: true)
          .limit(100)
          .timeout(const Duration(seconds: 12));
      if (!current()) throw const ChatRefreshSuperseded();
      if (rows.isEmpty) return ids.toList()..sort();
      for (final row in rows) {
        final id = row['friend_id'];
        if (id is! String) {
          throw const FormatException('Invalid friend identity.');
        }
        validateChatUuid(id);
        if (after != null && id.compareTo(after) <= 0) {
          throw const FormatException('Invalid friend cursor.');
        }
        after = id;
        if (id != owner.userId) ids.add(id);
      }
    }
    throw const FormatException('Friend inventory limit exceeded.');
  } catch (_) {
    // Never surface provider payloads, keys or another account's response.
    throw const ChatRelayException(ChatRelayFailureKind.retryable);
  }
});
