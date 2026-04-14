import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'isar_models.dart';
import '../database/app_database.dart';

class IsarService {
  static final IsarService instance = IsarService._init();
  Isar? _isar;

  IsarService._init();

  Future<Isar> get db async {
    if (_isar != null) return _isar!;
    _isar = await _initIsar();
    return _isar!;
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
      inspector: true,
    );

    // Initial sync check
    final count = await isar.isarHadiths.count();
    if (count == 0) {
      await _syncFromSqlite(isar);
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

    // 2. Sync Hadiths (in batches to avoid memory issues)
    const batchSize = 1000;
    int offset = 0;
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
          .toList();

      await isar.writeTxn(() async {
        await isar.isarHadiths.putAll(isarHadiths);
      });
      offset += batchSize;
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
