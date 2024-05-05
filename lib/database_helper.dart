import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 1;
  static const table = 'uploads';

  // Constants for column names
  static const columnId = '_id';
  static const columnPhoneHash = 'phone_hash';
  static const columnServerHash = 'server_hash';
  static const columnPath = 'path';
  static const columnStatus = 'status'; // Added column for status

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  // Open the database and create the table
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY,
            $columnPhoneHash TEXT NOT NULL,
            $columnServerHash TEXT NOT NULL,
            $columnPath TEXT NOT NULL,
            $columnStatus  INT NOT NULL
          )
          ''');
  }

  Future<int> insertMediaItem({required String phoneHash, required String serverHash, required String path, required int status}) async {
    Database db = await instance.database;

    // Check if a record with the same phoneHash already exists in the database
    List<Map<String, dynamic>> existingRecords = await db.query(
      table,
      where: '$columnPhoneHash = ?',
      whereArgs: [phoneHash],
    );

    if (existingRecords.isEmpty) {
      // If no record with the same phoneHash exists, insert the new record
      Map<String, dynamic> row = {
        columnPhoneHash: phoneHash,
        columnServerHash: serverHash,
        columnPath: path,
        columnStatus: status,
      };
      return await db.insert(table, row);
    } else {
      // If a record with the same phoneHash already exists, return 0 to indicate that no insertion was made
      return 0;
    }
  }

  Future<void> updateHashAndStatus(String phoneHash, String serverHash, int status) async {
    Database db = await instance.database;
    await db.update(
      table,
      {
        columnServerHash: serverHash,
        columnStatus: status,
      },
      where: '$columnPhoneHash = ?',
      whereArgs: [phoneHash],
    );
  }

  Future<void> updateStatus(String phoneHash, int status) async {
    Database db = await instance.database;
    await db.update(
      table,
      {
        columnStatus: status,
      },
      where: '$columnPhoneHash = ?',
      whereArgs: [phoneHash],
    );
  }

  Future<Map<int, int>> getStatusCounts() async {
    Database db = await instance.database;

    // Perform separate queries to count records for each status
    List<Map<String, dynamic>> doneCount = await db.rawQuery('SELECT COUNT(*) AS count FROM $table WHERE $columnStatus = 1');
    List<Map<String, dynamic>> busyCount = await db.rawQuery('SELECT COUNT(*) AS count FROM $table WHERE $columnStatus = 0');
    List<Map<String, dynamic>> errorCount = await db.rawQuery('SELECT COUNT(*) AS count FROM $table WHERE $columnStatus = -1');

    // Extract count values from the query results
    int done = doneCount.isNotEmpty ? doneCount[0]['count'] as int : 0;
    int busy = busyCount.isNotEmpty ? busyCount[0]['count'] as int : 0;
    int error = errorCount.isNotEmpty ? errorCount[0]['count'] as int : 0;

    // Return counts as a map
    return {1: done, 0: busy, -1: error};
  }

  Future<List<Map<String, dynamic>>> queryRowsByPath(String path) async {
    Database db = await instance.database;
    return await db.query(
      table,
      where: '$columnPath = ?',
      whereArgs: [path],
    );
  }

  Future<void> deleteAllRecords() async {
    final Database db = await instance.database;
    await db.delete('uploads');
  }
}
