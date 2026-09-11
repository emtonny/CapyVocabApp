import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/local_account.dart';
import 'package:capy_vocab/features/settings/presentation/providers/cloud_backup_consent_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '20000000-0000-4000-8000-000000000001';
final _time = DateTime.utc(2026, 9, 4, 13);

void main() {
  late Directory temporaryDirectory;
  late LibraryDatabase libraryDatabase;
  late SqliteLibraryStore store;
  late _Ids ids;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('consent_ui_');
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: '${temporaryDirectory.path}${Platform.pathSeparator}store.db',
    );
    ids = _Ids();
    store = SqliteLibraryStore(
      database: await libraryDatabase.open(),
      idGenerator: ids.next,
      clock: () => _time,
    );
  });

  tearDown(() async {
    await store.dispose();
    await libraryDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('first opt-in bootstraps fail-closed account and appends audit event',
      () async {
    final controller = CloudBackupConsentController(
      userId: _userId,
      store: store,
      mediaLoader: const _AvailableMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time,
    );

    await controller.setEnabled(true);

    final account = await store.watchLocalAccount(userId: _userId).first;
    final history = await store.watchConsentHistory(userId: _userId).first;
    expect(account, isNotNull);
    expect(account!.cloudBackupEnabled, isTrue);
    expect(account.localPersonalizationEnabled, isFalse);
    expect(account.federatedContributionEnabled, isFalse);
    expect(history, hasLength(1));
    expect(history.single.consentType, ConsentType.cloudBackup);
    expect(history.single.oldValue, isFalse);
    expect(history.single.newValue, isTrue);
    expect(history.single.policyVersion, cloudBackupPolicyVersion);
    expect(history.single.sourceAction, cloudBackupConsentSourceAction);
    expect(
      history.single.enforcementState,
      ConsentEnforcementState.applied,
    );
  });

  test('disable appends a second audit event without changing other consent',
      () async {
    await store.saveLocalAccount(_account(cloudBackupEnabled: true));
    final controller = CloudBackupConsentController(
      userId: _userId,
      store: store,
      mediaLoader: const _AvailableMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time.add(const Duration(minutes: 1)),
    );

    await controller.setEnabled(false);

    final account = await store.watchLocalAccount(userId: _userId).first;
    final history = await store.watchConsentHistory(userId: _userId).first;
    expect(account!.cloudBackupEnabled, isFalse);
    expect(account.localPersonalizationEnabled, isTrue);
    expect(account.federatedContributionEnabled, isFalse);
    expect(history.single.oldValue, isTrue);
    expect(history.single.newValue, isFalse);
  });

  test('account bootstrap never overwrites existing consent', () async {
    await store.saveLocalAccount(_account(cloudBackupEnabled: true));

    await store.ensureLocalAccount(_account(cloudBackupEnabled: false));

    final account = await store.watchLocalAccount(userId: _userId).first;
    expect(account!.cloudBackupEnabled, isTrue);
    expect(account.localPersonalizationEnabled, isTrue);
  });
}

LocalAccount _account({required bool cloudBackupEnabled}) => LocalAccount(
      userId: _userId,
      accountState: AccountState.active,
      cloudBackupEnabled: cloudBackupEnabled,
      localPersonalizationEnabled: true,
      federatedContributionEnabled: false,
      lastAuthenticatedAt: _time,
      createdAt: _time,
      updatedAt: _time,
    );

final class _Ids {
  int _value = 1;

  String next() {
    final suffix = (_value++).toString().padLeft(12, '0');
    return '30000000-0000-4000-8000-$suffix';
  }
}

final class _AvailableMediaLoader implements LibraryMediaLoader {
  const _AvailableMediaLoader();

  @override
  Future<Uint8List> readBytes(String relativePath) async => Uint8List(1);

  @override
  Future<int> sizeBytes(String relativePath) async => 1;
}
