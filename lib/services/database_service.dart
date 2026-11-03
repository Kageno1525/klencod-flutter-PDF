import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pdf_vault.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            parent_id INTEGER,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES groups (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            size INTEGER NOT NULL,
            group_id INTEGER,
            added_at INTEGER NOT NULL,
            FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
          )
        ''');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<int> insertGroup(String name, {int? parentId}) async {
    final db = await database;
    return db.insert('groups', {
      'name': name,
      'parent_id': parentId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getGroups({int? parentId}) async {
    final db = await database;
    return db.query(
      'groups',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final db = await database;
    return db.query('groups', orderBy: 'name ASC');
  }

  Future<void> updateGroup(int id, String newName) async {
    final db = await database;
    await db.update('groups', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    final db = await database;
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertFile({
    required String name,
    required String path,
    required int size,
    int? groupId,
  }) async {
    final db = await database;
    return db.insert('files', {
      'name': name,
      'path': path,
      'size': size,
      'group_id': groupId,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getFiles({int? groupId}) async {
    final db = await database;
    return db.query(
      'files',
      where: groupId == null ? 'group_id IS NULL' : 'group_id = ?',
      whereArgs: groupId == null ? null : [groupId],
      orderBy: 'added_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchFiles(String query) async {
    final db = await database;
    return db.query(
      'files',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
  }

  Future<void> deleteFile(int id) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveFile(int fileId, int? newGroupId) async {
    final db = await database;
    await db.update('files', {'group_id': newGroupId}, where: 'id = ?', whereArgs: [fileId]);
  }
}