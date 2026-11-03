import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum SortOption { date, name, size, recent }
enum FilterOption { all, favorites, recent }

class PdfDoc {
  final int? id;
  final String title;
  final String filePath;
  final String? thumbPath;
  final int pageCount;
  final int lastPage;
  final bool isFavorite;
  final int addedAt;
  final int? lastOpenedAt;
  final int fileSize;

  PdfDoc({
    this.id,
    required this.title,
    required this.filePath,
    this.thumbPath,
    this.pageCount = 0,
    this.lastPage = 0,
    this.isFavorite = false,
    required this.addedAt,
    this.lastOpenedAt,
    this.fileSize = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'thumbPath': thumbPath,
        'pageCount': pageCount,
        'lastPage': lastPage,
        'isFavorite': isFavorite ? 1 : 0,
        'addedAt': addedAt,
        'lastOpenedAt': lastOpenedAt,
        'fileSize': fileSize,
      };

  factory PdfDoc.fromMap(Map<String, dynamic> m) => PdfDoc(
        id: m['id'] as int?,
        title: m['title'] as String,
        filePath: m['filePath'] as String,
        thumbPath: m['thumbPath'] as String?,
        pageCount: m['pageCount'] as int? ?? 0,
        lastPage: m['lastPage'] as int? ?? 0,
        isFavorite: (m['isFavorite'] as int? ?? 0) == 1,
        addedAt: m['addedAt'] as int,
        lastOpenedAt: m['lastOpenedAt'] as int?,
        fileSize: m['fileSize'] as int? ?? 0,
      );
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'pdf_vault.db'),
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE pdfs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            filePath TEXT NOT NULL,
            thumbPath TEXT,
            pageCount INTEGER NOT NULL DEFAULT 0,
            lastPage INTEGER NOT NULL DEFAULT 0,
            isFavorite INTEGER NOT NULL DEFAULT 0,
            addedAt INTEGER NOT NULL,
            lastOpenedAt INTEGER,
            fileSize INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_added ON pdfs(addedAt DESC)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE pdfs ADD COLUMN lastOpenedAt INTEGER');
          await db.execute(
              'ALTER TABLE pdfs ADD COLUMN fileSize INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
    return _db!;
  }

  Future<int> insert(PdfDoc doc) async {
    final d = await db;
    return d.insert('pdfs', doc.toMap()..remove('id'));
  }

  Future<List<PdfDoc>> getAll({
    String? search,
    SortOption sort = SortOption.date,
    FilterOption filter = FilterOption.all,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      where.add('title LIKE ?');
      args.add('%$search%');
    }
    if (filter == FilterOption.favorites) {
      where.add('isFavorite = 1');
    } else if (filter == FilterOption.recent) {
      final weekAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      where.add('lastOpenedAt IS NOT NULL AND lastOpenedAt >= ?');
      args.add(weekAgo);
    }

    String orderBy;
    switch (sort) {
      case SortOption.date:
        orderBy = 'addedAt DESC';
        break;
      case SortOption.name:
        orderBy = 'title COLLATE NOCASE ASC';
        break;
      case SortOption.size:
        orderBy = 'fileSize DESC';
        break;
      case SortOption.recent:
        orderBy = 'COALESCE(lastOpenedAt, 0) DESC, addedAt DESC';
        break;
    }

    final rows = await d.query(
      'pdfs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(PdfDoc.fromMap).toList();
  }

  Future<Map<String, int>> getStats() async {
    final d = await db;
    final count = Sqflite.firstIntValue(
            await d.rawQuery('SELECT COUNT(*) FROM pdfs')) ??
        0;
    final pages = Sqflite.firstIntValue(await d
            .rawQuery('SELECT COALESCE(SUM(pageCount), 0) FROM pdfs')) ??
        0;
    final size = Sqflite.firstIntValue(
            await d.rawQuery('SELECT COALESCE(SUM(fileSize), 0) FROM pdfs')) ??
        0;
    return {'count': count, 'pages': pages, 'size': size};
  }

  Future<void> updateLastPage(int id, int page) async {
    final d = await db;
    await d.update('pdfs', {'lastPage': page},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markOpened(int id) async {
    final d = await db;
    await d.update(
        'pdfs', {'lastOpenedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(int id, bool fav) async {
    final d = await db;
    await d.update('pdfs', {'isFavorite': fav ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final d = await db;
    await d.delete('pdfs', where: 'id = ?', whereArgs: [id]);
  }
}