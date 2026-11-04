import 'dart:convert';

import '../../core/format.dart';
import '../models.dart';
import 'base.dart';

class TypeTotal {
  final InvoiceType type;
  final int count, total, profit;
  const TypeTotal(this.type, this.count, this.total, this.profit);
}

class ReportSummary {
  final Map<InvoiceType, TypeTotal> byType;
  final int expenses;
  final List<(String, int, int)> lineTypes; // name, count, total
  final List<(String, int, int)> topProducts; // name, qty, total
  final List<(String, int, int)> byEmployee; // name, count, total
  final List<(String, int)> expensesByCat;
  const ReportSummary(this.byType, this.expenses, this.lineTypes, this.topProducts, this.byEmployee, this.expensesByCat);

  /// إيرادات المبيعات (بدون تسديد الديون حتى لا تُحسب مرتين)
  int get revenue => byType.entries.where((e) => e.key != InvoiceType.debtPay).fold(0, (s, e) => s + e.value.total);
  int get grossProfit => byType.entries.where((e) => e.key != InvoiceType.debtPay).fold(0, (s, e) => s + e.value.profit);
  int get netProfit => grossProfit - expenses;
  int get count => byType.entries.where((e) => e.key != InvoiceType.debtPay).fold(0, (s, e) => s + e.value.count);
  int get collectedDebts => byType[InvoiceType.debtPay]?.total ?? 0;
}

class Period {
  final int id, startedAt;
  final int? closedAt;
  final String closedBy, summary;
  const Period(this.id, this.startedAt, this.closedAt, this.closedBy, this.summary);
}

class ReportsRepo {
  static Future<ReportSummary> summary(DateTime from, DateTime to) async {
    final a = [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];
    final rows = await db.rawQuery('''SELECT type, COUNT(*) c, COALESCE(SUM(total),0) t, COALESCE(SUM(total - cost),0) p
        FROM invoices WHERE status = 'active' AND created_at >= ? AND created_at < ? GROUP BY type''', a);
    final byType = <InvoiceType, TypeTotal>{};
    for (final r in rows) {
      final t = InvoiceTypeX.parse(r['type'].toString());
      byType[t] = TypeTotal(t, (r['c'] as num).toInt(), (r['t'] as num).toInt(), (r['p'] as num).toInt());
    }
    final exp = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE created_at >= ? AND created_at < ?', a);
    final lines = await db.rawQuery('''SELECT line_type_name n, COUNT(*) c, COALESCE(SUM(amount),0) t FROM line_sales
        WHERE status = 'active' AND created_at >= ? AND created_at < ? GROUP BY line_type_name ORDER BY t DESC''', a);
    final top = await db.rawQuery('''SELECT i.name n, SUM(i.qty) q, SUM(i.qty * i.price) t FROM invoice_items i
        JOIN invoices v ON v.id = i.invoice_id WHERE v.type = 'sale' AND v.status = 'active'
        AND v.created_at >= ? AND v.created_at < ? GROUP BY i.name ORDER BY q DESC LIMIT 10''', a);
    final emp = await db.rawQuery('''SELECT user_name n, COUNT(*) c, COALESCE(SUM(total),0) t FROM invoices
        WHERE status = 'active' AND type != 'debt_pay' AND created_at >= ? AND created_at < ?
        GROUP BY user_name ORDER BY t DESC''', a);
    final expCat = await db.rawQuery('''SELECT category n, COALESCE(SUM(amount),0) t FROM expenses
        WHERE created_at >= ? AND created_at < ? GROUP BY category ORDER BY t DESC''', a);
    (String, int, int) tri(Map<String, Object?> r, String b, String c) =>
        (r['n'].toString(), (r[b] as num).toInt(), (r[c] as num).toInt());
    return ReportSummary(
      byType,
      sumOf(exp),
      lines.map((r) => tri(r, 'c', 't')).toList(),
      top.map((r) => tri(r, 'q', 't')).toList(),
      emp.map((r) => tri(r, 'c', 't')).toList(),
      expCat.map((r) => (r['n'].toString(), (r['t'] as num).toInt())).toList(),
    );
  }

  /// مبيعات كل يوم لآخر [days] يوماً (للرسم البياني)
  static Future<List<(DateTime, int)>> daily(int days) async {
    final start = startOfDay(DateTime.now()).subtract(Duration(days: days - 1));
    final rows = await db.rawQuery('''SELECT created_at, total FROM invoices
        WHERE status = 'active' AND type != 'debt_pay' AND created_at >= ?''', [start.millisecondsSinceEpoch]);
    final buckets = List<int>.filled(days, 0);
    for (final r in rows) {
      final d = startOfDay(DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num).toInt()));
      final idx = d.difference(start).inDays;
      if (idx >= 0 && idx < days) buckets[idx] += (r['total'] as num).toInt();
    }
    return List.generate(days, (i) => (start.add(Duration(days: i)), buckets[i]));
  }

  static Future<List<ActivityEntry>> activity({int limit = 300, String query = ''}) async {
    final rows = await db.query('activity_log',
        where: query.isEmpty ? null : '(action LIKE ? OR details LIKE ? OR user_name LIKE ?)',
        whereArgs: query.isEmpty ? null : List.filled(3, '%$query%'),
        orderBy: 'id DESC',
        limit: limit);
    return rows.map(ActivityEntry.fromMap).toList();
  }

  static Future<Period> currentPeriod() async {
    final id = await currentPeriodId(db);
    final r = await db.query('periods', where: 'id = ?', whereArgs: [id]);
    final m = r.first;
    return Period(id, (m['started_at'] as num).toInt(), null, '', '');
  }

  static Future<List<Period>> closedPeriods() async {
    final rows = await db.query('periods', where: 'closed_at IS NOT NULL', orderBy: 'id DESC');
    return rows
        .map((m) => Period((m['id'] as num).toInt(), (m['started_at'] as num).toInt(), (m['closed_at'] as num?)?.toInt(),
            m['closed_by'].toString(), m['summary'].toString()))
        .toList();
  }

  /// تصفير مبيعات الشهر (مدير فقط): يغلق الفترة الحالية ويحفظ ملخصها ويعيد الترقيم من #1.
  /// السجلات القديمة لا تُحذف وتبقى في التقارير والأرشيف.
  static Future<void> closePeriod() async {
    final cur = await currentPeriod();
    final now = DateTime.now();
    final s = await summary(DateTime.fromMillisecondsSinceEpoch(cur.startedAt), now.add(const Duration(seconds: 1)));
    final summaryJson = jsonEncode({
      'revenue': s.revenue,
      'profit': s.grossProfit,
      'expenses': s.expenses,
      'net': s.netProfit,
      'count': s.count,
      'lines': s.byType[InvoiceType.line]?.count ?? 0,
      'lines_total': s.byType[InvoiceType.line]?.total ?? 0,
      'sales_total': s.byType[InvoiceType.sale]?.total ?? 0,
      'repairs_total': s.byType[InvoiceType.repair]?.total ?? 0,
    });
    await db.transaction((txn) async {
      await txn.update('periods', {'closed_at': now.millisecondsSinceEpoch, 'closed_by': actor, 'summary': summaryJson},
          where: 'id = ?', whereArgs: [cur.id]);
      await txn.insert('periods', {'started_at': now.millisecondsSinceEpoch});
      for (final k in ['sale', 'line', 'debt_pay']) {
        await txn.update('settings', {'value': '0'}, where: 'key = ?', whereArgs: ['counter_$k']);
      }
      await logActivity(txn, 'تصفير مبيعات الشهر', 'إجمالي الفترة ${money(s.revenue)}');
    });
    changed();
  }
}
