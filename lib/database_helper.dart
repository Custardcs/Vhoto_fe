import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 1;
  static const table = 'uploads';

  static const columnId = '_id';
  static const columnHash = 'hash';
  static const columnPath = 'path';
  static const columnUploaded = 'uploaded';

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
            $columnHash TEXT NOT NULL,
            $columnPath TEXT NOT NULL,
            $columnUploaded BOOLEAN NOT NULL
          )
          ''');
  }

  // Helper methods

  // Inserts a row in the database
  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row);
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  // All uploads that haven't been backed up yet
  Future<List<Map<String, dynamic>>> queryPendingUploads() async {
    Database db = await instance.database;
    return await db.query(table, where: '$columnUploaded = ?', whereArgs: [false]);
  }

  // Update an uploaded file's status
  Future<int> updateUploadStatus(int id, int uploaded) async {
    Database db = await instance.database;
    return await db.update(table, {columnUploaded: uploaded}, where: '$columnId = ?', whereArgs: [id]);
  }

  // Delete a record
  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<void> clearDatabase() async {
    Database db = await instance.database;
    await db.execute('DROP TABLE IF EXISTS $table');
    await _onCreate(db, _databaseVersion);
  }
}
