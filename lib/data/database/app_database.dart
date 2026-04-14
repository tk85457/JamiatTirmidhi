import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Production database with asset-copy-on-first-launch pattern.
/// Data tables (chapters, hadiths) come from the pre-built asset.
/// User tables (bookmarks, collections, notes, reading_progress) are created on open.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  static const String _dbName = 'sunan_ibn_majah.db';
  static const int _dbVersion = 9;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await _getDatabasePath();

    // On web, we build in-memory (asset copy not supported)
    if (kIsWeb) {
      return _openWebDatabase();
    }

    // Copy from assets on first launch
    final exists = await File(dbPath).exists();
    if (!exists) {
      await _copyFromAssets(dbPath);
    }

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onOpen: _onOpen,
      onUpgrade: _onUpgrade,
    );
  }

  /// Update chapter titles with proper Arabic and Urdu names (v6 migration)
  Future<void> _updateChapterTitlesV6(Database db) async {
    final Map<int, List<String>> titles = {
      1:  ['كتاب المقدمة (السُّنَّة)', 'کتاب السنہ (مقدمہ)'],
      2:  ['كتاب الطهارة وسُنَنِها', 'کتاب الطہارت اور اس کے سنن'],
      3:  ['كتاب الصلاة', 'کتاب الصلاۃ'],
      4:  ['كتاب الأذان والسُّنَّة فيها', 'کتاب اذان اور اس کے سنن'],
      5:  ['كتاب المساجد والجماعات', 'کتاب مساجد اور جماعتوں کے بارے میں'],
      6:  ['كتاب إقامة الصلاة والسُّنَّة فيها', 'کتاب اقامت صلاۃ اور اس کے سنن'],
      7:  ['كتاب الجنائز', 'کتاب الجنائز'],
      8:  ['كتاب الصيام', 'کتاب الصیام (روزے)'],
      9:  ['كتاب الزكاة', 'کتاب الزکاۃ'],
      10: ['كتاب النكاح', 'کتاب النکاح'],
      11: ['كتاب الطلاق', 'کتاب الطلاق'],
      12: ['كتاب الكفارات', 'کتاب الکفارات'],
      13: ['كتاب التجارات', 'کتاب التجارات'],
      14: ['كتاب الأحكام', 'کتاب الاحکام'],
      15: ['كتاب الهبات', 'کتاب الہبات (تحائف)'],
      16: ['كتاب الصدقات', 'کتاب الصدقات'],
      17: ['كتاب الرُّهون', 'کتاب الرہون (گروی)'],
      18: ['كتاب الشُّفعة', 'کتاب الشفعہ'],
      19: ['كتاب اللقطة', 'کتاب اللقطہ (گری پڑی چیز)'],
      20: ['كتاب العتق', 'کتاب العتق (آزاد کرنا)'],
      21: ['كتاب الحدود', 'کتاب الحدود'],
      22: ['كتاب الديات', 'کتاب الدیات'],
      23: ['كتاب الوصايا', 'کتاب الوصایا (وصیت)'],
      24: ['كتاب الفرائض', 'کتاب الفرائض (وراثت)'],
      25: ['كتاب الجهاد', 'کتاب الجہاد'],
      26: ['كتاب المناسك', 'کتاب المناسک (حج)'],
      27: ['كتاب الأضاحي', 'کتاب الاضاحی (قربانی)'],
      28: ['كتاب الذبائح', 'کتاب الذبائح'],
      29: ['كتاب الصيد', 'کتاب الصید (شکار)'],
      30: ['كتاب الأطعمة', 'کتاب الاطعمہ (کھانے)'],
      31: ['كتاب الأشربة', 'کتاب الاشربہ (مشروبات)'],
      32: ['كتاب الطب', 'کتاب الطب (علاج)'],
      33: ['كتاب اللباس', 'کتاب اللباس (لباس)'],
      34: ['كتاب الأدب', 'کتاب الادب'],
      35: ['كتاب الدعاء', 'کتاب الدعاء'],
      36: ['كتاب تعبير الرؤيا', 'کتاب تعبیر الرؤیا (خوابوں کی تعبیر)'],
      37: ['كتاب الفتن', 'کتاب الفتن'],
      38: ['كتاب الزهد', 'کتاب الزہد'],
    };

    final batch = db.batch();
    for (final entry in titles.entries) {
      batch.rawUpdate(
        'UPDATE chapters SET title_arabic = ?, title_urdu = ? WHERE id = ?',
        [entry.value[0], entry.value[1], entry.key],
      );
    }
    await batch.commit(noResult: true);
    debugPrintError('Chapter titles updated to Arabic/Urdu (v6 migration).');
  }

  Future<String> _getDatabasePath() async {
    if (kIsWeb) return _dbName;
    final dir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(join(dir.path, 'databases'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    return join(dbDir.path, _dbName);
  }

  /// Copy the pre-built database from assets to the app directory.
  Future<void> _copyFromAssets(String targetPath) async {
    try {
      final data = await rootBundle.load('assets/db/$_dbName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(targetPath).writeAsBytes(bytes, flush: true);
    } catch (e) {
      // If copy fails, the database will be created from scratch
      debugPrintError('Failed to copy DB from assets: $e');
    }
  }

  /// Web full database initialization (loads full 26MB asset)
  Future<Database> _openWebDatabase() async {
    // We use a versioned name on web to force a clean IndexedDB copy
    const webDbName = 'sunan_ibn_majah_web_v1.db';

    // Check if DB already exists in IndexedDB
    bool exists = await databaseFactory.databaseExists(webDbName);

    if (!exists) {
      debugPrintError('Web database not found. Copying from assets... This may take a moment.');
      try {
        final data = await rootBundle.load('assets/db/$_dbName');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await databaseFactory.writeDatabaseBytes(webDbName, bytes);
        debugPrintError('Web database successfully copied from assets.');
      } catch (e) {
        debugPrintError('Failed to copy Web DB from assets: $e');
        // Fallback to empty creation
        return await openDatabase(
          webDbName,
          version: _dbVersion,
          onCreate: _createWebFallback,
          onOpen: _onOpen,
          onUpgrade: _onUpgrade,
        );
      }
    }

    return await openDatabase(
      webDbName,
      version: _dbVersion,
      onOpen: _onOpen,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createWebFallback(Database db, int version) async {
    await _createDataTables(db);
    await _createUserTables(db);
    await _createIndexes(db);
  }

  /// Create user-data tables (these are added on top of the pre-built asset DB)
  Future<void> _onOpen(Database db) async {
    await _createUserTables(db);
    await _createIndexes(db);
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await _createUserTables(db);
      await _createIndexes(db);
    }
    if (oldVersion < 6) {
      // v6: Update chapter titles with proper Arabic/Urdu names
      await _updateChapterTitlesV6(db);
    }
    if (oldVersion < 8) {
      if (!kIsWeb) {
        await _updateDatabaseV8(db);
      }
    }
    if (oldVersion < 9) {
      await _migrateToV9(db);
    }
  }

  /// Re-copy data tables from asset DB while preserving user data (v8 migration)
  Future<void> _updateDatabaseV8(Database db) async {
    try {
      final data = await rootBundle.load('assets/db/$_dbName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // Write asset DB to a temp file
      final dir = await getApplicationDocumentsDirectory();
      final tmpPath = join(dir.path, 'databases', 'temp_asset_v8.db');
      await File(tmpPath).writeAsBytes(bytes, flush: true);
      
      // Attach the asset DB and copy chapter/hadith data
      await db.execute("ATTACH DATABASE '$tmpPath' AS asset_db");
      
      // Update chapters from asset
      await db.execute('DELETE FROM chapters');
      await db.execute('INSERT INTO chapters SELECT * FROM asset_db.chapters');
      
      // Update hadiths from asset
      await db.execute('DELETE FROM hadiths');
      await db.execute('INSERT INTO hadiths SELECT * FROM asset_db.hadiths');
      
      await db.execute('DETACH DATABASE asset_db');
      
      // Clean up temp file
      await File(tmpPath).delete();
      
      debugPrintError('Data tables refreshed from asset DB v8 successfully.');
    } catch (e) {
      debugPrintError('Failed to refresh data from assets v8: $e');
    }
  }

  Future<void> _migrateToV9(Database db) async {
    // Standardize collection_hadiths table naming
    await db.execute('''
CREATE TABLE IF NOT EXISTS collection_hadiths (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection_id INTEGER NOT NULL,
  hadith_id INTEGER NOT NULL,
  FOREIGN KEY (collection_id) REFERENCES collections (id),
  FOREIGN KEY (hadith_id) REFERENCES hadiths (id),
  UNIQUE(collection_id, hadith_id)
)''');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collection_hadith ON collection_hadiths(collection_id)');
    
    debugPrintError('Database migrated to v9 (collection_hadiths table and index created).');
  }

  Future<void> _createDataTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS chapters (
  id INTEGER PRIMARY KEY,
  book_number INTEGER NOT NULL,
  title_arabic TEXT NOT NULL,
  title_urdu TEXT NOT NULL,
  title_english TEXT NOT NULL,
  hadith_count INTEGER NOT NULL DEFAULT 0
)''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS hadiths (
  id INTEGER PRIMARY KEY,
  chapter_id INTEGER NOT NULL,
  hadith_number TEXT NOT NULL,
  arabic_text TEXT NOT NULL,
  urdu_text TEXT NOT NULL,
  english_text TEXT NOT NULL,
  grade TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (chapter_id) REFERENCES chapters (id)
)''');
  }

  Future<void> _createUserTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hadith_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (hadith_id) REFERENCES hadiths (id)
)''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
)''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS collection_hadiths (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection_id INTEGER NOT NULL,
  hadith_id INTEGER NOT NULL,
  FOREIGN KEY (collection_id) REFERENCES collections (id),
  FOREIGN KEY (hadith_id) REFERENCES hadiths (id),
  UNIQUE(collection_id, hadith_id)
)''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hadith_id INTEGER NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (hadith_id) REFERENCES hadiths (id)
)''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS reading_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chapter_id INTEGER NOT NULL,
  hadith_index INTEGER NOT NULL DEFAULT 0,
  last_read_at TEXT NOT NULL,
  FOREIGN KEY (chapter_id) REFERENCES chapters (id)
)''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hadiths_chapter ON hadiths(chapter_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hadiths_number ON hadiths(hadith_number)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bookmarks_hadith ON bookmarks(hadith_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_hadith ON notes(hadith_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_progress_chapter ON reading_progress(chapter_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collection_hadith ON collection_hadiths(collection_id)');
  }


  /// Delete corrupted DB and re-copy from assets
  Future<void> resetDatabase() async {
    if (kIsWeb) return;
    final path = await _getDatabasePath();
    _database?.close();
    _database = null;
    final file = File(path);
    if (await file.exists()) await file.delete();
    _database = await _openDatabase();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

void debugPrintError(String msg) {
  // ignore: avoid_print
  assert(() { print('[AppDatabase] $msg'); return true; }());
}
