import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static const String appVersion = '1.0.0';
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
      version: 2,
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
            last_opened_at INTEGER,
            is_favorite INTEGER DEFAULT 0,
            tag_color INTEGER,
            tag_label TEXT,
            auto_category TEXT,
            FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE files ADD COLUMN last_opened_at INTEGER;');
            await db.execute('ALTER TABLE files ADD COLUMN is_favorite INTEGER DEFAULT 0;');
            await db.execute('ALTER TABLE files ADD COLUMN tag_color INTEGER;');
            await db.execute('ALTER TABLE files ADD COLUMN tag_label TEXT;');
            await db.execute('ALTER TABLE files ADD COLUMN auto_category TEXT;');
          } catch (_) {}
        }
      },
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
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

  Future<Map<String, dynamic>?> getGroupById(int id) async {
    final db = await database;
    final r = await db.query('groups', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
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
    String? autoCategory,
  }) async {
    final db = await database;
    return db.insert('files', {
      'name': name,
      'path': path,
      'size': size,
      'group_id': groupId,
      'added_at': DateTime.now().millisecondsSinceEpoch,
      'auto_category': autoCategory ?? _guessCategory(name),
    });
  }

  String _guessCategory(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('invoice') || lower.contains('فاتورة') || lower.contains('receipt')) {
      return 'فواتير';
    }
    if (lower.contains('book') || lower.contains('كتاب') || lower.contains('course') || lower.contains('كورس')) {
      return 'كتب وكورسات';
    }
    if (lower.contains('certificate') || lower.contains('شهادة') || lower.contains('cert')) {
      return 'شهادات';
    }
    if (lower.contains('research') || lower.contains('بحث') || lower.contains('paper')) {
      return 'بحوث';
    }
    return 'عام';
  }

  Future<List<Map<String, dynamic>>> getFiles({
    int? groupId,
    bool favoritesOnly = false,
    String? autoCategory,
    bool allGroups = false,
    String sortBy = 'added_at DESC',
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (!allGroups) {
      if (groupId != null) {
        where.add('group_id = ?');
        args.add(groupId);
      } else {
        where.add('group_id IS NULL');
      }
    }
    if (favoritesOnly) where.add('is_favorite = 1');
    if (autoCategory != null &&
        autoCategory.isNotEmpty &&
        autoCategory != 'الكل') {
      where.add('auto_category = ?');
      args.add(autoCategory);
    }
    final whereStr = where.isEmpty ? null : where.join(' AND ');
    return db.query(
      'files',
      where: whereStr,
      whereArgs: args.isEmpty ? null : args,
      orderBy: sortBy,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentFiles({int limit = 50}) async {
    final db = await database;
    return db.query(
      'files',
      where: 'last_opened_at IS NOT NULL',
      orderBy: 'last_opened_at DESC',
      limit: limit,
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

  Future<void> updateFile(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('files', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markOpened(int id) async {
    final db = await database;
    await db.update(
      'files',
      {'last_opened_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleFavorite(int id, bool isFav) async {
    final db = await database;
    await db.update(
      'files',
      {'is_favorite': isFav ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFile(int id) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveFile(int fileId, int? newGroupId) async {
    final db = await database;
    await db.update(
      'files',
      {'group_id': newGroupId},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  Future<Directory> getBackupDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final dir = Directory('${downloads.path}/PdfVault');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/PdfVaultBackups');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/PdfVaultBackups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> exportDatabaseBackup() async {
    final db = await database;
    await db.close();
    _db = null;
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, 'pdf_vault.db'));
      if (!await sourceFile.exists()) {
        await database;
        throw Exception('قاعدة البيانات غير موجودة');
      }
      final backupDir = await getBackupDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File(
          join(backupDir.path, 'pdf_vault_v${appVersion}_$timestamp.db'));
      await sourceFile.copy(backupFile.path);
      await database;
      return backupFile;
    } catch (e) {
      await database;
      rethrow;
    }
  }

  Future<void> restoreDatabaseFromBackup(String backupPath) async {
    final db = await database;
    await db.close();
    _db = null;
    try {
      final dbPath = await getDatabasesPath();
      final currentDb = File(join(dbPath, 'pdf_vault.db'));
      if (await currentDb.exists()) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        await currentDb.copy('${currentDb.path}.safety_$ts');
      }
      await File(backupPath).copy(currentDb.path);
      await database;
    } catch (e) {
      await database;
      rethrow;
    }
  }
}