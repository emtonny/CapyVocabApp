import 'package:sqflite/sqflite.dart';

DatabaseFactory get libraryDatabaseFactory => databaseFactory;

Future<String> libraryDatabasePath() async {
  final databaseDirectory = await getDatabasesPath();
  return '$databaseDirectory/capy_vocab.db';
}
