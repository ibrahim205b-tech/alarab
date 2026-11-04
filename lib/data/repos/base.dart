import 'package:sqflite/sqflite.dart';

import '../../core/format.dart';
import '../../services/session.dart';
import '../db.dart';

Database get db => AppDb.instance.db;

void changed() => DataBus.instance.bump();

String get actor => Session.instance.actor;

/// تسجيل كل عملية في سجل النشاط (للمراجعة من المدير)
Future<void> logActivity(DatabaseExecutor ex, String action, [String details = '']) => ex.insert('activity_log', {
      'user_name': actor,
      'action': action,
      'details': details,
      'created_at': nowMs(),
    });

/// العداد التسلسلي لكل نوع (#1، #2 ...) — يُصفّر فقط عند تصفير الشهر من المدير
Future<int> nextCounter(DatabaseExecutor ex, String key) async {
  final rows = await ex.query('settings', where: 'key = ?', whereArgs: ['counter_$key']);
  final cur = rows.isEmpty ? 0 : int.tryParse(rows.first['value'].toString()) ?? 0;
  final next = cur + 1;
  await ex.insert('settings', {'key': 'counter_$key', 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  return next;
}

Future<int> currentPeriodId(DatabaseExecutor ex) async {
  final r = await ex.rawQuery('SELECT id FROM periods WHERE closed_at IS NULL ORDER BY id DESC LIMIT 1');
  if (r.isNotEmpty) return (r.first['id'] as num).toInt();
  return ex.insert('periods', {'started_at': nowMs()});
}

int sumOf(List<Map<String, Object?>> rows, [String col = 's']) =>
    rows.isEmpty ? 0 : ((rows.first[col] as num?) ?? 0).toInt();
