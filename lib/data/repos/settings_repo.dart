import 'package:sqflite/sqflite.dart';

import 'base.dart';

/// إعدادات المحل محفوظة في قاعدة البيانات مع نسخة بالذاكرة للقراءة السريعة
class SettingsRepo {
  SettingsRepo._();
  static final SettingsRepo instance = SettingsRepo._();

  final Map<String, String> _cache = {};

  Future<void> load() async {
    final rows = await db.query('settings');
    _cache
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r['key'].toString(), r['value']?.toString() ?? '')));
  }

  String get(String key, [String def = '']) => _cache[key] ?? def;
  bool flag(String key) => _cache[key] == '1';
  int integer(String key, [int def = 0]) => int.tryParse(_cache[key] ?? '') ?? def;

  Future<void> set(String key, String value) async {
    _cache[key] = value;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    changed();
  }

  Future<void> setMany(Map<String, String> values) async {
    final b = db.batch();
    values.forEach((k, v) {
      _cache[k] = v;
      b.insert('settings', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await b.commit(noResult: true);
    changed();
  }

  String get shopName {
    final v = get('shop_name').trim();
    return v.isEmpty ? 'نظام المبيعات' : v;
  }
}
