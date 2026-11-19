import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Independent, offline database. Not a migration of the unavailable v6 files.
class FarmStore {
  FarmStore._(this.db);
  final Database db;

  static Future<FarmStore> open() async {
    final base = await getDatabasesPath();
    final database = await openDatabase(
      p.join(base, 'mazraati_offline.db'),
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, from, to) async {
        // Only standalone DB versions are supported here. No silent legacy migration.
        if (from == 1 && to >= 2) await _createSchema(db);
      },
    );
    return FarmStore._(database);
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT NOT NULL,
        name TEXT NOT NULL,
        sex TEXT NOT NULL,
        life_stage TEXT NOT NULL,
        weight_kg REAL NOT NULL CHECK(weight_kg > 0),
        birth_date TEXT,
        measured_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        stock_kg REAL,
        price_per_kg REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_animal_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL UNIQUE,
        pregnancy_stage TEXT,
        breeding_date TEXT,
        daily_milk_kg REAL,
        suckling_kids INTEGER,
        bcs_value REAL,
        bcs_scale TEXT,
        notes TEXT,
        FOREIGN KEY(animal_id) REFERENCES animals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_feed_analyses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feed_id INTEGER NOT NULL UNIQUE,
        dm_percent REAL,
        energy_mj_kg_dm REAL,
        energy_system TEXT,
        cp_percent_dm REAL,
        ndf_percent_dm REAL,
        max_daily_kg REAL,
        source_type TEXT NOT NULL,
        source_note TEXT,
        analyzed_at TEXT,
        FOREIGN KEY(feed_id) REFERENCES feeds(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL UNIQUE,
        dm_min REAL, dm_max REAL,
        energy_min REAL, energy_max REAL,
        protein_min REAL, protein_max REAL,
        ndf_min REAL, ndf_max REAL,
        energy_system TEXT,
        applicable_stage TEXT,
        source_kind TEXT NOT NULL,
        source TEXT NOT NULL,
        reviewed_at TEXT,
        FOREIGN KEY(animal_id) REFERENCES animals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        as_fed_kg REAL NOT NULL,
        dm_kg REAL,
        energy_mj REAL,
        protein_kg REAL,
        ndf_kg REAL,
        warnings TEXT NOT NULL,
        FOREIGN KEY(animal_id) REFERENCES animals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ration_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ration_id INTEGER NOT NULL,
        feed_name TEXT NOT NULL,
        as_fed_kg REAL NOT NULL,
        dm_percent REAL,
        energy_mj_kg_dm REAL,
        cp_percent_dm REAL,
        ndf_percent_dm REAL,
        FOREIGN KEY(ration_id) REFERENCES rations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rations_animal ON rations(animal_id)');
  }

  Future<List<Map<String, Object?>>> animals() =>
      db.query('animals', orderBy: 'created_at DESC');

  Future<int> addAnimal(Map<String, Object?> fields) =>
      db.insert('animals', fields);

  Future<void> deleteAnimal(int id) async {
    await db.delete('animals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveProfile(int animalId, Map<String, Object?> fields) async {
    await db.insert(
      'nutrition_animal_profiles',
      {'animal_id': animalId, ...fields},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> profile(int animalId) async {
    final rows = await db.query(
      'nutrition_animal_profiles',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> feeds() => db.rawQuery('''
    SELECT f.*, a.dm_percent, a.energy_mj_kg_dm, a.energy_system,
           a.cp_percent_dm, a.ndf_percent_dm, a.max_daily_kg,
           a.source_type, a.source_note, a.analyzed_at
    FROM feeds f LEFT JOIN nutrition_feed_analyses a ON f.id = a.feed_id
    ORDER BY f.name
  ''');

  Future<int> addFeed(
    Map<String, Object?> feed,
    Map<String, Object?> analysis,
  ) async {
    return db.transaction((txn) async {
      final id = await txn.insert('feeds', feed);
      await txn.insert('nutrition_feed_analyses', {'feed_id': id, ...analysis});
      return id;
    });
  }

  Future<void> deleteFeed(int id) async =>
      db.delete('feeds', where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>?> target(int animalId) async {
    final rows = await db.query(
      'nutrition_targets',
      where: 'animal_id = ?',
      whereArgs: [animalId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveTarget(int animalId, Map<String, Object?> fields) async {
    await db.insert(
      'nutrition_targets',
      {'animal_id': animalId, ...fields},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> saveRation({
    required int animalId,
    required double asFedKg,
    required double? dmKg,
    required double? energyMj,
    required double? proteinKg,
    required double? ndfKg,
    required List<String> warnings,
    required List<Map<String, Object?>> items,
  }) async {
    return db.transaction((txn) async {
      final id = await txn.insert('rations', {
        'animal_id': animalId,
        'created_at': DateTime.now().toIso8601String(),
        'as_fed_kg': asFedKg,
        'dm_kg': dmKg,
        'energy_mj': energyMj,
        'protein_kg': proteinKg,
        'ndf_kg': ndfKg,
        'warnings': warnings.join('\n'),
      });
      for (final item in items) {
        await txn.insert('ration_items', {'ration_id': id, ...item});
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> rationHistory() => db.rawQuery('''
    SELECT r.*, a.name AS animal_name FROM rations r
    JOIN animals a ON a.id = r.animal_id ORDER BY r.created_at DESC
  ''');

  Future<List<Map<String, Object?>>> rationItems(int rationId) =>
      db.query('ration_items', where: 'ration_id = ?', whereArgs: [rationId]);

  Future<void> deleteRation(int rationId) async =>
      db.delete('rations', where: 'id = ?', whereArgs: [rationId]);

  Future<void> close() => db.close();
}
