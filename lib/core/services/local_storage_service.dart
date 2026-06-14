import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';

/// Platform-agnostic local storage used by [OfflineService].
///
/// - Mobile/desktop: delegates to [DatabaseService] (sqflite / sqflite_ffi).
/// - Web: stores each table as a JSON list in shared_preferences, since
///   sqflite is not available in the browser.
///
/// The query API intentionally mirrors the subset of [DatabaseService]
/// that OfflineService relies on: equality `where` clauses
/// ("field = ?" joined by AND) and a single-field `orderBy`
/// ("field ASC" / "field DESC").
abstract class LocalStorageService {
  static LocalStorageService? _instance;

  static LocalStorageService get instance {
    _instance ??= kIsWeb ? _WebLocalStorage() : _SqfliteLocalStorage();
    return _instance!;
  }

  /// Allows tests to inject a fake implementation.
  @visibleForTesting
  static set instance(LocalStorageService value) => _instance = value;

  Future<void> insert(String table, Map<String, dynamic> data);

  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  );

  Future<void> delete(String table, String where, List<dynamic> whereArgs);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<void> clearTable(String table);
}

// ── sqflite implementation (Android, iOS, Windows, macOS, Linux) ──

class _SqfliteLocalStorage extends LocalStorageService {
  @override
  Future<void> insert(String table, Map<String, dynamic> data) =>
      DatabaseService.insert(table, data);

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) =>
      DatabaseService.update(table, data, where, whereArgs);

  @override
  Future<void> delete(String table, String where, List<dynamic> whereArgs) =>
      DatabaseService.delete(table, where, whereArgs);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) =>
      DatabaseService.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );

  @override
  Future<void> clearTable(String table) => DatabaseService.clearTable(table);
}

// ── shared_preferences implementation (Web) ──────────────────────

class _WebLocalStorage extends LocalStorageService {
  static const String _prefix = 'questkids_table_';

  // Tables whose primary key should replace existing rows on insert,
  // mirroring ConflictAlgorithm.replace in DatabaseService.
  static const Map<String, String> _primaryKeys = {
    'users': 'uid',
    'activities': 'id',
    'rewards': 'uid',
    'app_settings': 'key',
  };

  // Tables with INTEGER PRIMARY KEY AUTOINCREMENT in the sqflite schema.
  static const Set<String> _autoIncrementTables = {'progress', 'pending_sync'};

  Future<List<Map<String, dynamic>>> _readTable(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$table');
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _writeTable(
      String table, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$table', jsonEncode(rows));
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final rows = await _readTable(table);
    final row = Map<String, dynamic>.from(data);

    if (_autoIncrementTables.contains(table) && row['id'] == null) {
      final maxId = rows.fold<int>(
          0, (max, r) => (r['id'] as int? ?? 0) > max ? r['id'] as int : max);
      row['id'] = maxId + 1;
    }

    final pk = _primaryKeys[table];
    if (pk != null) {
      rows.removeWhere((r) => r[pk] == row[pk]);
    }
    rows.add(row);
    await _writeTable(table, rows);
  }

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final rows = await _readTable(table);
    final matcher = _buildMatcher(where, whereArgs);
    for (final row in rows) {
      if (matcher(row)) row.addAll(data);
    }
    await _writeTable(table, rows);
  }

  @override
  Future<void> delete(
      String table, String where, List<dynamic> whereArgs) async {
    final rows = await _readTable(table);
    final matcher = _buildMatcher(where, whereArgs);
    rows.removeWhere(matcher);
    await _writeTable(table, rows);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    var rows = await _readTable(table);

    if (where != null) {
      final matcher = _buildMatcher(where, whereArgs ?? const []);
      rows = rows.where(matcher).toList();
    }

    if (orderBy != null) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final field = parts[0];
      final descending = parts.length > 1 &&
          parts[1].toUpperCase() == 'DESC';
      rows.sort((a, b) {
        final av = a[field];
        final bv = b[field];
        int cmp;
        if (av is num && bv is num) {
          cmp = av.compareTo(bv);
        } else {
          cmp = '$av'.compareTo('$bv');
        }
        return descending ? -cmp : cmp;
      });
    }

    if (limit != null && rows.length > limit) {
      rows = rows.sublist(0, limit);
    }
    return rows;
  }

  @override
  Future<void> clearTable(String table) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$table');
  }

  /// Supports "field = ?" clauses joined with AND, which is all
  /// OfflineService uses.
  bool Function(Map<String, dynamic>) _buildMatcher(
      String where, List<dynamic> whereArgs) {
    final clauses = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    final fields = <String>[];
    for (final clause in clauses) {
      final match = RegExp(r'^\s*(\w+)\s*=\s*\?\s*$').firstMatch(clause);
      if (match == null) {
        throw UnsupportedError(
            'Web storage only supports "field = ?" clauses, got: $where');
      }
      fields.add(match.group(1)!);
    }
    return (row) {
      for (var i = 0; i < fields.length; i++) {
        if (row[fields[i]] != whereArgs[i]) return false;
      }
      return true;
    };
  }
}
