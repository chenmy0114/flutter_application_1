import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/record.dart';
import 'models/category.dart';

class RecordsDatabase {
  static final RecordsDatabase instance = RecordsDatabase._init();

  static Database? _database;

  static const String tableRecords = "records";

  RecordsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('records.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path,
        version: 1, onCreate: _createDB, onOpen: _onOpen);
  }

  Future<void> _onOpen(Database db) async {
    // Ensure categories table exists and default categories present
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        ordering INTEGER NOT NULL
      )
    ''');

    // ensure default categories exist if table empty
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM categories');
    final cnt = (countRes.first['c'] as int?) ?? 0;
    if (cnt == 0) {
      final defaults = [
        '餐饮',
        '交通',
        '服饰',
        '购物',
        '服务',
        '教育',
        '娱乐',
        '生活缴费',
        '医疗',
        '发红包',
        '转账',
        '其他人情',
        '其他'
      ];
      for (var i = 0; i < defaults.length; i++) {
        await db.insert('categories', {'name': defaults[i], 'ordering': i});
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      dateTime INTEGER NOT NULL,
      category TEXT NOT NULL,
      isIncome INTEGER NOT NULL,
      amount REAL NOT NULL,
      note TEXT
    )
    ''');
  }

  Future<Record> insertRecord(Record record) async {
    final db = await instance.database;
    final id = await db.insert('records', record.toMap());
    return Record(
      id: id,
      dateTime: record.dateTime,
      category: record.category,
      isIncome: record.isIncome,
      amount: record.amount,
      note: record.note,
    );
  }

  Future<List<Record>> getRecordsForMonth(int year, int month) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final maps = await db.query(
      'records',
      where: 'dateTime >= ? AND dateTime < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'dateTime DESC',
    );
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<Map<String, double>> getMonthSummary(int year, int month) async {
    final rows = await getRecordsForMonth(year, month);
    double income = 0;
    double expense = 0;
    for (var r in rows) {
      if (r.isIncome) {
        income += r.amount;
      } else {
        expense += r.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  Future<List<Record>> getRecordsForYear(int year) async {
    final db = await instance.database;
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1 + 1, 1);
    final maps = await db.query(
      'records',
      where: 'dateTime >= ? AND dateTime < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'dateTime DESC',
    );
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<Map<String, double>> getYearSummary(int year) async {
    final rows = await getRecordsForYear(year);
    double income = 0;
    double expense = 0;
    for (var r in rows) {
      if (r.isIncome) {
        income += r.amount;
      } else {
        expense += r.amount;
      }
    }
    return {'income': income, 'expense': expense};
  }

  Future<Map<int, Map<String, double>>> getYearSummaries(int year) async {
    final db = await instance.database;
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    final result = await db.rawQuery('''
      SELECT strftime('%m', datetime(dateTime/1000, 'unixepoch', '+${offsetHours} hours')) AS month,
             SUM(CASE WHEN isIncome = 1 THEN amount ELSE 0 END) AS income,
             SUM(CASE WHEN isIncome = 0 THEN amount ELSE 0 END) AS expense
      FROM records
      WHERE dateTime >= ? AND dateTime < ?
      GROUP BY month
    ''', [start, end]);

    final Map<int, Map<String, double>> summaries = {};
    for (var row in result) {
      final monthStr = row['month'] as String?;
      if (monthStr == null) continue;
      final m = int.tryParse(monthStr) ?? 0;
      final income = (row['income'] as num?)?.toDouble() ?? 0.0;
      final expense = (row['expense'] as num?)?.toDouble() ?? 0.0;
      summaries[m] = {'income': income, 'expense': expense};
    }
    return summaries;
  }

  Future<Map<int, Map<String, double>>> getDaySummaries(
      int year, int month) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    final result = await db.rawQuery('''
      SELECT strftime('%d', datetime(dateTime/1000, 'unixepoch', '+${offsetHours} hours')) AS day,
             SUM(CASE WHEN isIncome = 1 THEN amount ELSE 0 END) AS income,
             SUM(CASE WHEN isIncome = 0 THEN amount ELSE 0 END) AS expense
      FROM records
      WHERE dateTime >= ? AND dateTime < ?
      GROUP BY day
    ''', [start, end]);

    final Map<int, Map<String, double>> summaries = {};
    for (var row in result) {
      final dayStr = row['day'] as String?;
      if (dayStr == null) continue;
      final d = int.tryParse(dayStr) ?? 0;
      final income = (row['income'] as num?)?.toDouble() ?? 0.0;
      final expense = (row['expense'] as num?)?.toDouble() ?? 0.0;
      summaries[d] = {'income': income, 'expense': expense};
    }
    return summaries;
  }

  Future<double> getWalletTotal() async {
    final db = await instance.database;
    final row = await db.rawQuery('''
      SELECT SUM(CASE WHEN isIncome = 1 THEN amount ELSE -amount END) AS total
      FROM records
    ''');
    if (row.isEmpty) return 0.0;
    final val = (row.first['total'] as num?)?.toDouble();
    return val ?? 0.0;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  /// Export the current database file to [destDir]. Returns the exported file path.
  Future<String> exportDatabaseToDirectory(String destDir) async {
    final dbPath = await getDatabasesPath();
    final dbFile = join(dbPath, 'records.db');
    final destFile = join(destDir,
        'records_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.db');
    final source = File(dbFile);
    final dest = File(destFile);
    await source.copy(dest.path);
    return dest.path;
  }

  /// Replace the current database with the provided file at [sourcePath].
  /// Closes the open database, copies the file into place, and resets internal state.
  Future<void> replaceDatabaseWithFile(String sourcePath) async {
    // Close current database if open
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final destPath = join(dbPath, 'records.db');
    final src = File(sourcePath);
    await src.copy(destPath);
    // Next time `.database` getter is accessed, it will reopen the copied DB
  }

  // --- Category helpers ---
  Future<List<Category>> getCategories() async {
    final db = await instance.database;
    // Ensure table exists (defensive in case DB was created before this code ran)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        ordering INTEGER NOT NULL
      )
    ''');

    // ensure default categories exist if table empty
    final countRes = await db.rawQuery('SELECT COUNT(*) as c FROM categories');
    final cnt = (countRes.first['c'] as int?) ?? 0;
    if (cnt == 0) {
      final defaults = [
        '餐饮',
        '交通',
        '服饰',
        '购物',
        '服务',
        '教育',
        '娱乐',
        '生活缴费',
        '医疗',
        '发红包',
        '转账',
        '其他人情',
        '其他'
      ];
      for (var i = 0; i < defaults.length; i++) {
        await db.insert('categories', {'name': defaults[i], 'ordering': i});
      }
    }

    final rows = await db.query('categories', orderBy: 'ordering ASC');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<Category> insertCategory(String name, int order) async {
    final db = await instance.database;
    final id = await db.insert('categories', {'name': name, 'ordering': order});
    return Category(id: id, name: name, order: order);
  }

  Future<int> updateCategoryName(int id, String name) async {
    final db = await instance.database;
    return await db.update('categories', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCategoryOrder(int id, int order) async {
    final db = await instance.database;
    return await db.update('categories', {'ordering': order},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRecords(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.delete('records',
        where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<int> deleteRecordsForMonth(int year, int month) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    return await db.delete('records',
        where: 'dateTime >= ? AND dateTime < ?', whereArgs: [start, end]);
  }

  Future<List<Record>> getRecordsForDay(int year, int month, int day) async {
    final db = await instance.database;
    final start = DateTime(year, month, day).millisecondsSinceEpoch;
    final next = DateTime(year, month, day)
        .add(Duration(days: 1))
        .millisecondsSinceEpoch;
    final maps = await db.query(
      'records',
      where: 'dateTime >= ? AND dateTime < ?',
      whereArgs: [start, next],
      orderBy: 'dateTime DESC',
    );
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<List<Map<String, Object>>> getCategorySumsForMonth(
      int year, int month, bool isIncome) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final res = await db.rawQuery('''
      SELECT category, SUM(amount) AS total, COUNT(*) AS cnt
      FROM records
      WHERE dateTime >= ? AND dateTime < ? AND isIncome = ?
      GROUP BY category
      ORDER BY total DESC
    ''', [start, end, isIncome ? 1 : 0]);

    return res.map((row) {
      return {
        'category': (row['category'] as String?) ?? '',
        'total': ((row['total'] as num?)?.toDouble()) ?? 0.0,
        'count': (row['cnt'] as int?) ?? (row['cnt'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, Object>>> getCategorySumsForYear(
      int year, bool isIncome) async {
    final db = await instance.database;
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final res = await db.rawQuery('''
      SELECT category, SUM(amount) AS total, COUNT(*) AS cnt
      FROM records
      WHERE dateTime >= ? AND dateTime < ? AND isIncome = ?
      GROUP BY category
      ORDER BY total DESC
    ''', [start, end, isIncome ? 1 : 0]);

    return res.map((row) {
      return {
        'category': (row['category'] as String?) ?? '',
        'total': ((row['total'] as num?)?.toDouble()) ?? 0.0,
        'count': (row['cnt'] as int?) ?? (row['cnt'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<List<Record>> getRecordsForCategoryInMonth(
      int year, int month, String category, bool isIncome) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final maps = await db.query('records',
        where:
            'dateTime >= ? AND dateTime < ? AND category = ? AND isIncome = ?',
        whereArgs: [start, end, category, isIncome ? 1 : 0],
        orderBy: 'dateTime DESC');
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  Future<List<Record>> getRecordsForCategoryInYear(
      int year, String category, bool isIncome) async {
    final db = await instance.database;
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final maps = await db.query('records',
        where:
            'dateTime >= ? AND dateTime < ? AND category = ? AND isIncome = ?',
        whereArgs: [start, end, category, isIncome ? 1 : 0],
        orderBy: 'dateTime DESC');
    return maps.map((m) => Record.fromMap(m)).toList();
  }

  // 导出所有数据
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;

    // 查询记录表数据
    final records = await db.query(tableRecords);

    return {
      "records": records,
      "export_time": DateTime.now().toIso8601String(), // 导出时间
      "version": "1.0" // 数据版本
    };
  }

  // 导入数据（先清空旧数据，再插入新数据）
  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;
    final batch = db.batch();

    // 清空现有数据（可根据需求改为增量导入）
    batch.delete(tableRecords);

    // 插入记录数据
    List<Map<String, dynamic>> records = List.from(data["records"]);
    for (var item in records) {
      item.remove("id"); // 移除自增ID
      batch.insert(tableRecords, item);
    }

    await batch.commit(noResult: true);
  }
}
