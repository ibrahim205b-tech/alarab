import '../../core/format.dart';
import '../../services/telegram.dart';
import '../models.dart';
import 'base.dart';

class ExpensesRepo {
  static Future<void> add(String category, int amount, String note) async {
    if (amount <= 0) throw Exception('المبلغ غير صحيح');
    final now = nowMs();
    await db.insert('expenses', {
      'category': category,
      'amount': amount,
      'note': note.trim(),
      'user_name': actor,
      'created_at': now,
    });
    await logActivity(db, 'إضافة مصروف', '$category — ${money(amount)}');
    changed();
    await TelegramService.instance.notify('expense', [
      '🧾 <b>مصروف جديد</b>',
      'البند: ${TelegramService.esc(category)}',
      '💸 <b>${money(amount)}</b>',
      if (note.trim().isNotEmpty) '📝 ${TelegramService.esc(note.trim())}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(now)}',
    ].join('\n'));
  }

  static Future<List<Expense>> list({DateTime? from, DateTime? to}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query('expenses',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC', limit: 1000);
    return rows.map(Expense.fromMap).toList();
  }

  static Future<void> delete(Expense e) async {
    await db.delete('expenses', where: 'id = ?', whereArgs: [e.id]);
    await logActivity(db, 'حذف مصروف', '${e.category} — ${money(e.amount)}');
    changed();
  }
}
