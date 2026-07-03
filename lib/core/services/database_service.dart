import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;
  static const int _version = 1;
  static const String _dbName = 'questkids.db';

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        grade TEXT NOT NULL,
        totalPoints INTEGER DEFAULT 0,
        streakDays INTEGER DEFAULT 0,
        avatarUrl TEXT,
        parentUid TEXT,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        subject TEXT NOT NULL,
        type TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        rewardPoints INTEGER NOT NULL,
        grade TEXT NOT NULL,
        questionsJson TEXT NOT NULL,
        requiresProof INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        activityId TEXT NOT NULL,
        activityTitle TEXT NOT NULL,
        subject TEXT NOT NULL,
        score INTEGER NOT NULL,
        pointsEarned INTEGER NOT NULL,
        completed INTEGER DEFAULT 0,
        verified INTEGER DEFAULT 0,
        proofUrl TEXT,
        completedAt INTEGER NOT NULL,
        timeTakenSeconds INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE rewards (
        uid TEXT PRIMARY KEY,
        totalPoints INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        streakDays INTEGER DEFAULT 0,
        badgesJson TEXT DEFAULT "[]",
        achievementsJson TEXT DEFAULT "[]",
        lastActiveDate INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        dataJson TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        retryCount INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // future migrations go here
    }
  }

  // ── Generic helpers ──────────────────────────────────

  static Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  static Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  static Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }

  static Future<void> closeDb() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
