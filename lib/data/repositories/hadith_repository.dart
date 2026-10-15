import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../isar/isar_service.dart';
import '../isar/isar_models.dart';
import '../database/app_database.dart';
import 'package:isar_community/isar.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final isarServiceProvider = Provider<IsarService>(
  (ref) => IsarService.instance,
);

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepository(
    ref.watch(databaseProvider),
    ref.watch(isarServiceProvider),
  );
});

final lastProgressProvider = FutureProvider<ReadingProgress?>((ref) async {
  final repo = ref.watch(hadithRepositoryProvider);
  return repo.getLastReadingProgress();
});

class HadithRepository {
  final AppDatabase _db;
  final IsarService _isar;
  HadithRepository(this._db, this._isar);

  // --- Chapters ---
  Future<List<Chapter>> getChapters() async {
    final db = await _db.database;
    final result = await db.query('chapters', orderBy: 'book_number ASC');
    return result.map((e) => Chapter.fromMap(e)).toList();
  }

  Future<int> getTotalChapterCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM chapters');
    return result.first['c'] as int;
  }

  Future<Chapter?> getChapterById(int id) async {
    final db = await _db.database;
    final result = await db.query('chapters', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Chapter.fromMap(result.first);
  }

  // --- Hadiths (paginated) ---
  Future<List<Hadith>> getHadithsByChapter(
    int chapterId, {
    int? limit,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final result = await db.query(
      'hadiths',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((e) => Hadith.fromMap(e)).toList();
  }

  Future<int> getHadithCountByChapter(int chapterId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM hadiths WHERE chapter_id = ?',
      [chapterId],
    );
    return result.first['c'] as int;
  }

  Future<Hadith?> getHadithById(int id) async {
    final db = await _db.database;
    final result = await db.query('hadiths', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Hadith.fromMap(result.first);
  }

  Future<Hadith?> getHadithByNumber(String hadithNumber) async {
    final db = await _db.database;
    final result = await db.query(
      'hadiths',
      where: 'hadith_number = ?',
      whereArgs: [hadithNumber],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Hadith.fromMap(result.first);
  }

  Future<int> getHadithIndexWithinChapter(
    int chapterId,
    String hadithNumber,
  ) async {
    final db = await _db.database;

    // First get the id of the target hadith
    final target = await db.query(
      'hadiths',
      where: 'chapter_id = ? AND hadith_number = ?',
      whereArgs: [chapterId, hadithNumber],
      limit: 1,
    );
    if (target.isEmpty) return 0;

    final targetId = target.first['id'] as int;

    // Count how many hadiths in the same chapter have an id strictly less than targetId
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM hadiths WHERE chapter_id = ? AND id < ?',
      [chapterId, targetId],
    );
    return result.first['c'] as int;
  }

  Future<int> getTotalHadithCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM hadiths');
    return result.first['c'] as int;
  }

  Future<Hadith?> getHadithByGlobalNumber(String number) async {
    final db = await _db.database;
    final result = await db.query(
      'hadiths',
      where: 'hadith_number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Hadith.fromMap(result.first);
  }

  Future<int> getHadithIndex(int chapterId, String hadithNumber) async {
    return getHadithIndexWithinChapter(chapterId, hadithNumber);
  }

  // --- Search (Optimized with Isar & SQLite Fallback) ---
  Future<List<Hadith>> searchHadiths(
    String query, {
    bool exactMatch = false,
    int limit = 30,
    int offset = 0,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final isarResults = await _isar.search(
        cleanQuery,
        limit: limit,
        offset: offset,
      );
      if (isarResults.isNotEmpty) {
        final List<Hadith> hadiths = [];
        for (final ir in isarResults) {
          if (ir.sqliteId != null) {
            final h = await getHadithById(ir.sqliteId!);
            if (h != null) hadiths.add(h);
          }
        }
        if (hadiths.isNotEmpty) return hadiths;
      }
    } catch (e) {
      debugPrint('Isar search error, falling back to SQLite: $e');
    }

    // Direct SQLite fallback — ultra reliable and never crashes
    final db = await _db.database;
    if (int.tryParse(cleanQuery) != null) {
      final result = await db.query(
        'hadiths',
        where: 'hadith_number = ?',
        whereArgs: [cleanQuery],
        limit: limit,
        offset: offset,
      );
      if (result.isNotEmpty) {
        return result.map((e) => Hadith.fromMap(e)).toList();
      }
    }

    final searchPattern = '%$cleanQuery%';
    final result = await db.query(
      'hadiths',
      where: 'urdu_text LIKE ? OR english_text LIKE ? OR arabic_text LIKE ?',
      whereArgs: [searchPattern, searchPattern, searchPattern],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return result.map((e) => Hadith.fromMap(e)).toList();
  }

  Future<int> searchCount(String query, {bool exactMatch = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return 0;
    try {
      final isar = await _isar.db;
      final count = await isar.isarHadiths
          .filter()
          .urduTextContains(cleanQuery, caseSensitive: false)
          .or()
          .englishTextContains(cleanQuery, caseSensitive: false)
          .or()
          .hadithNumberEqualTo(cleanQuery)
          .count();
      if (count > 0) return count;
    } catch (_) {}

    final db = await _db.database;
    final searchPattern = '%$cleanQuery%';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM hadiths WHERE urdu_text LIKE ? OR english_text LIKE ? OR arabic_text LIKE ? OR hadith_number = ?',
      [searchPattern, searchPattern, searchPattern, cleanQuery],
    );
    return result.first['c'] as int;
  }

  // --- Bookmarks ---
  Future<List<Hadith>> getBookmarkedHadiths() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT h.* FROM hadiths h
      INNER JOIN bookmarks b ON h.id = b.hadith_id
      ORDER BY b.created_at DESC
    ''');
    return result.map((e) => Hadith.fromMap(e)).toList();
  }

  Future<void> toggleBookmark(int hadithId) async {
    final db = await _db.database;
    final exists = await db.query(
      'bookmarks',
      where: 'hadith_id = ?',
      whereArgs: [hadithId],
    );
    if (exists.isEmpty) {
      await db.insert('bookmarks', {
        'hadith_id': hadithId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.delete(
        'bookmarks',
        where: 'hadith_id = ?',
        whereArgs: [hadithId],
      );
    }
  }

  Future<bool> isBookmarked(int hadithId) async {
    final db = await _db.database;
    final r = await db.query(
      'bookmarks',
      where: 'hadith_id = ?',
      whereArgs: [hadithId],
    );
    return r.isNotEmpty;
  }

  // --- Collections ---
  Future<List<HadithCollection>> getCollections() async {
    final db = await _db.database;
    final result = await db.query('collections', orderBy: 'created_at DESC');
    return result.map((e) => HadithCollection.fromMap(e)).toList();
  }

  Future<int> createCollection(String name) async {
    final db = await _db.database;
    return await db.insert('collections', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --- Reading Progress ---
  Future<void> saveReadingProgress(int chapterId, int hadithIndex) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'reading_progress',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );
    if (existing.isEmpty) {
      await db.insert('reading_progress', {
        'chapter_id': chapterId,
        'hadith_index': hadithIndex,
        'last_read_at': now,
      });
    } else {
      await db.update(
        'reading_progress',
        {'hadith_index': hadithIndex, 'last_read_at': now},
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );
    }
  }

  Future<ReadingProgress?> getLastReadingProgress() async {
    final db = await _db.database;
    final result = await db.query(
      'reading_progress',
      orderBy: 'last_read_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return ReadingProgress.fromMap(result.first);
  }

  // --- Stats ---
  Future<int> getBookmarkCount() async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM bookmarks');
    return r.first['c'] as int;
  }

  Future<int> getNotesCount() async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM notes');
    return r.first['c'] as int;
  }

  Future<int> getTotalReadChapters() async {
    final db = await _db.database;
    final r = await db.rawQuery(
      'SELECT COUNT(DISTINCT chapter_id) as c FROM reading_progress',
    );
    return r.first['c'] as int;
  }

  // --- Bookmarks with Chapter Info ---
  Future<List<Map<String, dynamic>>> getBookmarkedHadithsWithChapter() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT h.*, c.title_urdu as chapter_title_urdu, c.book_number
      FROM hadiths h
      INNER JOIN bookmarks b ON h.id = b.hadith_id
      LEFT JOIN chapters c ON h.chapter_id = c.id
      ORDER BY b.created_at DESC
    ''');
    return result;
  }

  // --- Notes ---
  Future<List<Map<String, dynamic>>> getNotesWithHadithInfo() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT n.*, h.hadith_number,
        SUBSTR(h.english_text, 1, 150) as hadith_preview
      FROM notes n
      LEFT JOIN hadiths h ON n.hadith_id = h.id
      ORDER BY n.updated_at DESC
    ''');
  }

  Future<void> addNote(int hadithId, String content) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'notes',
      where: 'hadith_id = ?',
      whereArgs: [hadithId],
    );
    if (existing.isEmpty) {
      await db.insert('notes', {
        'hadith_id': hadithId,
        'content': content,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'notes',
        {'content': content, 'updated_at': now},
        where: 'hadith_id = ?',
        whereArgs: [hadithId],
      );
    }
  }

  Future<void> deleteNote(int noteId) async {
    final db = await _db.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
  }

  // --- Collections ---
  Future<HadithCollection?> getCollectionById(int id) async {
    final db = await _db.database;
    final result = await db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return HadithCollection.fromMap(result.first);
  }

  Future<List<Hadith>> getCollectionHadiths(int collectionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT h.* FROM hadiths h
      INNER JOIN collection_hadiths ch ON h.id = ch.hadith_id
      WHERE ch.collection_id = ?
    ''',
      [collectionId],
    );
    return result.map((e) => Hadith.fromMap(e)).toList();
  }

  Future<int> getCollectionHadithCount(int collectionId) async {
    final db = await _db.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM collection_hadiths WHERE collection_id = ?',
      [collectionId],
    );
    return r.first['c'] as int;
  }

  Future<void> addHadithToCollection(int collectionId, int hadithId) async {
    final db = await _db.database;
    final existing = await db.query(
      'collection_hadiths',
      where: 'collection_id = ? AND hadith_id = ?',
      whereArgs: [collectionId, hadithId],
    );
    if (existing.isEmpty) {
      await db.insert('collection_hadiths', {
        'collection_id': collectionId,
        'hadith_id': hadithId,
      });
    }
  }

  Future<void> deleteCollection(int id) async {
    final db = await _db.database;
    await db.delete(
      'collection_hadiths',
      where: 'collection_id = ?',
      whereArgs: [id],
    );
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  // --- Hadith of the Day ---
  /// Hadith of the day: the SAME hadith for the whole (local) calendar day.
  ///
  /// The pick is derived from today's date (no RANDOM(), no storage needed), so
  /// pull-to-refresh, app restarts and screen rebuilds can never change it.
  /// It changes only when the date changes. It is also faster than
  /// `ORDER BY RANDOM()`, which sorts the whole table (slow on low-end phones).
  Future<Hadith?> getHadithOfTheDay() async {
    final db = await _db.database;
    final countRows = await db.rawQuery('SELECT COUNT(*) as c FROM hadiths');
    final total = (countRows.first['c'] as int?) ?? 0;
    if (total == 0) return null;

    final now = DateTime.now();
    // yyyymmdd -> stable seed for the day. Dart's seeded Random is deterministic.
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final offset = Random(seed).nextInt(total);

    final result = await db.rawQuery(
      'SELECT * FROM hadiths ORDER BY id LIMIT 1 OFFSET ?',
      [offset],
    );
    if (result.isEmpty) return null;
    return Hadith.fromMap(result.first);
  }

  Future<Hadith?> getRandomHadith() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT * FROM hadiths ORDER BY RANDOM() LIMIT 1',
    );
    if (result.isEmpty) return null;
    return Hadith.fromMap(result.first);
  }

  // --- Chapter Progress ---
  Future<List<Map<String, dynamic>>> getAllChapterProgress() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT c.id, c.book_number, c.title_urdu, c.hadith_count,
        rp.hadith_index, rp.last_read_at
      FROM chapters c
      LEFT JOIN reading_progress rp ON c.id = rp.chapter_id
      ORDER BY c.book_number ASC
    ''');
  }

  // --- Export / Import ---
  Future<Map<String, dynamic>> exportUserData() async {
    final db = await _db.database;
    final bookmarks = await db.query('bookmarks');
    final notes = await db.query('notes');
    final collections = await db.query('collections');
    final collectionHadiths = await db.query('collection_hadiths');
    final progress = await db.query('reading_progress');
    return {
      'bookmarks': bookmarks,
      'notes': notes,
      'collections': collections,
      'collection_hadiths': collectionHadiths,
      'reading_progress': progress,
    };
  }

  Future<int> importUserData(Map<String, dynamic> data) async {
    final db = await _db.database;
    int count = 0;
    await db.transaction((txn) async {
      if (data['bookmarks'] != null) {
        for (final b in (data['bookmarks'] as List)) {
          try {
            await txn.insert('bookmarks', Map<String, dynamic>.from(b));
            count++;
          } catch (_) {}
        }
      }
      if (data['notes'] != null) {
        for (final n in (data['notes'] as List)) {
          try {
            await txn.insert('notes', Map<String, dynamic>.from(n));
            count++;
          } catch (_) {}
        }
      }
      if (data['collections'] != null) {
        for (final c in (data['collections'] as List)) {
          try {
            await txn.insert('collections', Map<String, dynamic>.from(c));
            count++;
          } catch (_) {}
        }
      }
      if (data['collection_hadiths'] != null) {
        for (final ch in (data['collection_hadiths'] as List)) {
          try {
            await txn.insert(
              'collection_hadiths',
              Map<String, dynamic>.from(ch),
            );
            count++;
          } catch (_) {}
        }
      }
      if (data['reading_progress'] != null) {
        for (final r in (data['reading_progress'] as List)) {
          try {
            await txn.insert('reading_progress', Map<String, dynamic>.from(r));
            count++;
          } catch (_) {}
        }
      }
    });
    return count;
  }
}
