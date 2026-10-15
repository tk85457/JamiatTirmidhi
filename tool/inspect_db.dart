import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dbPath = p.absolute('assets/db/jami_at_tirmidhi.db');
  print('Opening db at: $dbPath');
  var db = await databaseFactory.openDatabase(dbPath);
  var version = await db.getVersion();
  print('user_version: $version');
  var tables = await db.rawQuery(
    "SELECT name FROM sqlite_schema WHERE type='table';",
  );
  print('tables: $tables');
  await db.close();
}
