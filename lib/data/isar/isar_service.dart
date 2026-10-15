import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'isar_models.dart';
import '../database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IsarService {
  static final IsarService instance = IsarService._init();
  Isar? _isar;
  final syncProgress = ValueNotifier<double>(0);
  bool _isInitializing = false;
  bool _ready = false;
  bool get isReady => _ready;

  IsarService._init();

  Future<Isar> get db async {
    if (_isar != null) return _isar!;
    return await _initIsar();
  }

  /// Initialize Isar in background
  Future<void> init() async {
    if (_isInitializing || _ready) return;
    _isInitializing = true;
    await _initIsar();
  }

  Future<Isar> _initIsar() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        IsarChapterSchema,
        IsarHadithSchema,
        IsarBookmarkSchema,
        IsarHadithCollectionSchema,
        IsarNoteSchema,
        IsarReadingProgressSchema,
      ],
      directory: dir.path,
      inspector: kDebugMode,
    );

    _isar = isar;

    // Initial sync check
    final prefs = await SharedPreferences.getInstance();
    final isSyncCompleted = prefs.getBool('isar_sync_v1_completed') ?? false;

    if (!isSyncCompleted) {
      _syncFromSqlite(isar).then((_) async {
        await prefs.setBool('isar_sync_v1_completed', true);
        _ready = true;
        _isInitializing = false;
        syncProgress.value = 1.0;
      }).catchError((e) {
        debugPrint('Error syncing SQLite to Isar: $e');
        _ready = true;
        _isInitializing = false;
        syncProgress.value = 1.0;
      });
    } else {
      _ready = true;
      _isInitializing = false;
      syncProgress.value = 1.0;
    }

    return isar;
  }

  Future<void> _syncFromSqlite(Isar isar) async {
    final sqlite = AppDatabase.instance;
    final db = await sqlite.database;

    // 1. Sync Chapters
    final chaptersRaw = await db.query('chapters');
    final isarChapters = chaptersRaw
        .map(
          (e) => IsarChapter()
            ..sqliteId = e['id'] as int
            ..bookNumber = e['book_number'] as int
            ..titleArabic = e['title_arabic'] as String
            ..titleUrdu = e['title_urdu'] as String
            ..titleEnglish = e['title_english'] as String
            ..hadithCount = e['hadith_count'] as int,
        )
        .toList();

    await isar.writeTxn(() async {
      await isar.isarChapters.putAll(isarChapters);
    });

    // Yield to UI
    await Future.delayed(const Duration(milliseconds: 20));

    // 2. Sync Hadiths in smooth batches to prevent ANRs
    const batchSize = 250;
    int offset = 0;
    final totalHadithsRaw = await db.rawQuery(
      'SELECT COUNT(*) as c FROM hadiths',
    );
    final totalHadiths = totalHadithsRaw.first['c'] as int;

    while (true) {
      final hadithsRaw = await db.query(
        'hadiths',
        limit: batchSize,
        offset: offset,
      );
      if (hadithsRaw.isEmpty) break;

      final isarHadiths = hadithsRaw
          .map(
            (e) => IsarHadith()
              ..sqliteId = e['id'] as int
              ..chapterId = e['chapter_id'] as int
              ..hadithNumber = e['hadith_number'].toString()
              ..arabicText = e['arabic_text'] as String
              ..urduText = e['urdu_text'] as String
              ..englishText = e['english_text'] as String,
          )
          .toList(growable: false);

      await isar.writeTxn(() async {
        await isar.isarHadiths.putAll(isarHadiths);
      });
      offset += batchSize;

      // Update progress
      syncProgress.value = (offset / (totalHadiths > 0 ? totalHadiths : 1))
          .clamp(0.0, 1.0);

      // Crucial: yield to the UI isolate so frames render and user inputs are processed
      await Future.delayed(const Duration(milliseconds: 20));
    }

    // 3. Sync User Data (Bookmarks)
    final bookmarksRaw = await db.query('bookmarks');
    final isarBookmarks = bookmarksRaw
        .map(
          (e) => IsarBookmark()
            ..hadithId = e['hadith_id'] as int
            ..createdAt = DateTime.parse(e['created_at'] as String),
        )
        .toList();

    if (isarBookmarks.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.isarBookmarks.putAll(isarBookmarks);
      });
    }

    // 4. Sync Notes
    final notesRaw = await db.query('notes');
    final isarNotes = notesRaw
        .map(
          (e) => IsarNote()
            ..hadithId = e['hadith_id'] as int
            ..content = e['content'] as String
            ..createdAt = DateTime.parse(e['created_at'] as String)
            ..updatedAt = DateTime.parse(e['updated_at'] as String),
        )
        .toList();

    if (isarNotes.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.isarNotes.putAll(isarNotes);
      });
    }
  }

  // --- Optimized Search ---
  Future<List<IsarHadith>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final isar = await db;
    if (query.isEmpty) return [];

    return await isar.isarHadiths
        .filter()
        .urduTextContains(query, caseSensitive: false)
        .or()
        .englishTextContains(query, caseSensitive: false)
        .or()
        .hadithNumberEqualTo(query)
        .sortByHadithNumber()
        .offset(offset)
        .limit(limit)
        .findAll();
  }
}
