import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'bookmark.dart';

class BookmarkRepository {
  BookmarkRepository._internal();

  static final BookmarkRepository instance = BookmarkRepository._internal();

  Database? _database;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Stream<void> get changes => _changeController.stream;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = await _databasePath();
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bookmarks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT,
            thumbnail_url TEXT,
            external_url TEXT NOT NULL,
            published_at TEXT
          )
        ''');
      },
    );

    _database = database;
    return database;
  }

  Future<String> _databasePath() async {
    final dbPath = await getDatabasesPath();
    return '$dbPath/techmoa_bookmarks.db';
  }

  Future<bool> saveBookmark(Bookmark bookmark) async {
    try {
      final db = await _db;
      await db.insert(
        'bookmarks',
        bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _notifyChanged();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeBookmark(String id) async {
    try {
      final db = await _db;
      final removed = await db.delete(
        'bookmarks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (removed > 0) {
        _notifyChanged();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBookmarked(String id) async {
    final db = await _db;
    final result = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Bookmark>> fetchBookmarks() async {
    final db = await _db;
    final rows = await db.query('bookmarks', orderBy: 'published_at DESC');
    return rows.map((row) => Bookmark.fromMap(row)).toList();
  }

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  Future<void> dispose() async {
    await _database?.close();
    await _changeController.close();
  }
}
