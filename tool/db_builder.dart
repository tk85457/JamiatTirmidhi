import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Grade hierarchy for averaging (higher = stronger hadith)
const Map<String, double> _gradeScore = {
  // Sahih variants
  'Sahih': 4.0,
  'Sahih Muslim': 4.0,
  'Sahih Bukhari': 4.0,
  'Sahih Al-Bukhari': 4.0,
  'Sahih li Ghairih': 3.7,
  'Hasan Sahih': 3.5,
  // Hasan variants
  'Hasan': 3.0,
  'Hasan li Ghairih': 2.7,
  // Da'if variants
  "Da'if": 2.0,
  "Da'if Al-Albani": 2.0,
  "Da'if Jiddan": 1.5,
  "Da'if Mursal": 1.8,
  // Mawdu / fabricated
  'Mawdu': 1.0,
  'Batil': 1.0,
};

/// Convert average score back to a grade label
String _scoreToLabel(double avg) {
  if (avg >= 3.8) return 'Sahih';
  if (avg >= 3.3) return 'Hasan Sahih';
  if (avg >= 2.5) return 'Hasan';
  if (avg >= 1.8) return "Da'if";
  if (avg >= 1.0) return 'Mawdu';
  return '';
}

/// Calculate average grade from a list of grade objects.
/// Falls back to most-common when scores are unavailable.
String _calcAverageGrade(List<dynamic>? grades) {
  if (grades == null || grades.isEmpty) return '';

  final List<double> scores = [];
  final Map<String, int> freqMap = {};

  for (final g in grades) {
    final raw = (g['grade'] as String?)?.trim() ?? '';
    if (raw.isEmpty) continue;
    freqMap[raw] = (freqMap[raw] ?? 0) + 1;
    final score = _gradeScore[raw];
    if (score != null) scores.add(score);
  }

  // If all grades are in our score map -> return averaged label
  if (scores.isNotEmpty) {
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return _scoreToLabel(avg);
  }

  // Fallback: most common grade string
  if (freqMap.isEmpty) return '';
  return freqMap.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

Future<void> main() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  final outPath = '${Directory.current.path}/assets/db/jami_at_tirmidhi.db';
  final outFile = File(outPath);
  if (await outFile.exists()) await outFile.delete();

  print('Building database for Jami at-Tirmidhi at: $outPath');

  final db = await factory.openDatabase(
    outPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chapters (
            id           INTEGER PRIMARY KEY,
            book_number  INTEGER NOT NULL,
            title_arabic TEXT    NOT NULL,
            title_urdu   TEXT    NOT NULL,
            title_english TEXT   NOT NULL,
            hadith_count INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE hadiths (
            id           INTEGER PRIMARY KEY,
            chapter_id   INTEGER NOT NULL,
            hadith_number INTEGER NOT NULL,
            arabic_text  TEXT    NOT NULL,
            urdu_text    TEXT    NOT NULL,
            english_text TEXT    NOT NULL,
            grade        TEXT    NOT NULL DEFAULT '',
            FOREIGN KEY (chapter_id) REFERENCES chapters (id)
          )''');
        await db.execute(
          'CREATE INDEX idx_hadiths_chapter ON hadiths(chapter_id)',
        );
        await db.execute(
          'CREATE INDEX idx_hadiths_number  ON hadiths(hadith_number)',
        );
      },
    ),
  );

  // -- 1. Load JSON files ---------------------------------------------------
  const base = r'C:\Windows.old\Users\tk854\Music\Downloads\hadith-api-1\hadith-api-1\editions';

  print('Loading Arabic JSON...');
  final araData = jsonDecode(await File('$base\\ara-tirmidhi.json').readAsString());

  print('Loading Urdu JSON...');
  final urdData = jsonDecode(await File('$base\\urd-tirmidhi.json').readAsString());

  print('Loading English JSON...');
  final engData = jsonDecode(await File('$base\\eng-tirmidhi.json').readAsString());

  final Map<String, dynamic> araMeta = araData['metadata']['sections'];
  final Map<String, dynamic> urdMeta = urdData['metadata']['sections'];
  final Map<String, dynamic> engMeta = engData['metadata']['sections'];

  final List<dynamic> araList = araData['hadiths'];
  final List<dynamic> urdList = urdData['hadiths'];
  final List<dynamic> engList = engData['hadiths'];

  print('Found ${araList.length} hadiths in Arabic file.');

  // -- 2. Insert chapters dynamically ---------------------------------------
  print('Inserting chapters from metadata...');
  final cBatch = db.batch();
  final Set<int> bookIds = araMeta.keys.map((k) => int.parse(k)).toSet();
  
  for (final id in bookIds) {
    if (id == 0) continue; // Skip metadata book
    cBatch.insert('chapters', {
      'id': id,
      'book_number': id,
      'title_arabic': araMeta[id.toString()] ?? 'كتاب',
      'title_urdu': urdMeta[id.toString()] ?? 'کتاب',
      'title_english': engMeta[id.toString()] ?? 'Book',
      'hadith_count': 0,
    });
  }
  await cBatch.commit(noResult: true);


  // -- 3. Build lookup maps ------------------------------------------------
  final Map<int, String> urduMap = {};
  final Map<int, String> englishMap = {};
  final Map<int, String> gradeMap = {};

  for (final h in urdList) {
    urduMap[(h['hadithnumber'] as num).toInt()] = h['text'] as String;
  }

  for (final h in engList) {
    final n = (h['hadithnumber'] as num).toInt();
    englishMap[n] = h['text'] as String;
    gradeMap[n] = _calcAverageGrade(h['grades'] as List<dynamic>?);
  }

  // -- 4. Insert hadiths ---------------------------------------------------
  print('Inserting hadiths...');
  var hBatch = db.batch();
  int count = 0;

  for (final h in araList) {
    final int hNum = (h['hadithnumber'] as num).toInt();
    final int bookNum = (h['reference']['book'] as num).toInt();
    final String arabicText = h['text'] as String;
    final String urduText = urduMap[hNum] ?? 'ترجمہ دستیاب نہیں';
    final String englishText = englishMap[hNum] ?? 'Translation not available';
    final String grade = gradeMap[hNum] ?? '';

    // Skip hadiths with book 0 (metadata placeholder)
    if (bookNum == 0) continue;

    hBatch.insert('hadiths', {
      'chapter_id': bookNum,
      'hadith_number': hNum,
      'arabic_text': arabicText,
      'urdu_text': urduText,
      'english_text': englishText,
      'grade': grade,
    });

    count++;
    if (count % 500 == 0) {
      await hBatch.commit(noResult: true);
      hBatch = db.batch();
      print('  Inserted $count hadiths...');
    }
  }
  await hBatch.commit(noResult: true);

  // -- 5. Update chapter hadith counts -------------------------------------
  print('Updating chapter counts...');
  await db.execute('''
    UPDATE chapters
    SET hadith_count = (
      SELECT COUNT(*) FROM hadiths WHERE chapter_id = chapters.id
    )
  ''');

  // -- 6. Summary ----------------------------------------------------------
  final totalRes = await db.rawQuery('SELECT COUNT(*) AS c FROM hadiths');
  final total = totalRes.first['c'];
  final chapRes = await db.rawQuery(
    'SELECT id, title_english, hadith_count FROM chapters ORDER BY id',
  );

  print('\n✓ Database build complete!');
  print('✓ Total Hadiths: $total');
  print('\nChapter summary:');
  for (final row in chapRes) {
    print(
      '  [${row['id']}] ${row['title_english']} -- ${row['hadith_count']} hadiths',
    );
  }

  await db.close();
}
