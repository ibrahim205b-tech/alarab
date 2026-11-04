import '../../core/format.dart';
import '../../services/telegram.dart';
import '../models.dart';
import 'base.dart';

class DebtsRepo {
  /// إضافة دين/طلب (مسموح للموظف) — لا يُعدّل ولا يُحذف إلا من المدير
  static Future<Debt> add({
    required String name,
    String phone = '',
    required String type,
    required int amount,
    String note = '',
  }) async {
    if (name.trim().isEmpty) throw Exception('اسم الزبون مطلوب');
    if (amount <= 0) throw Exception('المبلغ غير صحيح');
    final now = nowMs();
    final id = await db.insert('debts', {
      'customer_name': name.trim(),
      'customer_phone': phone.trim(),
      'debt_type': type,
      'amount': amount,
      'paid': 0,
      'note': note.trim(),
      'status': 'open',
      'user_name': actor,
      'created_at': now,
    });
    await logActivity(db, 'إضافة دين', '${name.trim()} — $type — ${money(amount)}');
    changed();
    await TelegramService.instance.notify('debt', [
      '📒 <b>دين / طلب جديد</b>',
      '👤 ${TelegramService.esc(name.trim())} ${phone.trim()}',
      'النوع: ${TelegramService.esc(type)}',
      '💰 <b>المبلغ: ${money(amount)}</b>',
      if (note.trim().isNotEmpty) '📝 ${TelegramService.esc(note.trim())}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(now)}',
    ].join('\n'));
    return Debt(
        id: id, customerName: name.trim(), customerPhone: phone.trim(), debtType: type, amount: amount, note: note, userName: actor, createdAt: now);
  }

  static Future<List<Debt>> list({bool? open, String query = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (open == true) where.add("status = 'open' AND paid < amount");
    if (open == false) where.add("(status = 'closed' OR paid >= amount)");
    if (query.trim().isNotEmpty) {
      where.add('(customer_name LIKE ? OR customer_phone LIKE ? OR debt_type LIKE ? OR note LIKE ?)');
      args.addAll(List.filled(4, '%${query.trim()}%'));
    }
    final rows = await db.query('debts',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC', limit: 1000);
    return rows.map(Debt.fromMap).toList();
  }

  static Future<Debt?> get(int id) async {
    final r = await db.query('debts', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Debt.fromMap(r.first);
  }

  static Future<List<DebtPayment>> payments(int debtId) async =>
      (await db.query('debt_payments', where: 'debt_id = ?', whereArgs: [debtId], orderBy: 'id DESC'))
          .map(DebtPayment.fromMap)
          .toList();

  static Future<(int count, int total)> openSummary() async {
    final r = await db.rawQuery(
        "SELECT COUNT(*) c, COALESCE(SUM(amount - paid),0) s FROM debts WHERE status = 'open' AND paid < amount");
    return (sumOf(r, 'c'), sumOf(r, 's'));
  }

  /// تسجيل دفعة (تسديد) مع وصل
  static Future<Invoice> pay(Debt d, int amount, {String note = ''}) async {
    if (amount <= 0) throw Exception('المبلغ غير صحيح');
    if (amount > d.remaining) throw Exception('المبلغ أكبر من المتبقي (${money(d.remaining)})');
    final inv = await db.transaction((txn) async {
      final now = nowMs();
      final payId = await txn.insert('debt_payments', {
        'debt_id': d.id,
        'amount': amount,
        'note': note,
        'user_name': actor,
        'created_at': now,
      });
      final newPaid = d.paid + amount;
      await txn.update(
          'debts',
          {
            'paid': newPaid,
            if (newPaid >= d.amount) 'status': 'closed',
            if (newPaid >= d.amount) 'closed_at': now,
          },
          where: 'id = ?',
          whereArgs: [d.id]);
      final number = await nextCounter(txn, 'debt_pay');
      final period = await currentPeriodId(txn);
      final invId = await txn.insert('invoices', {
        'type': 'debt_pay',
        'number': number,
        'period_id': period,
        'customer_name': d.customerName,
        'customer_phone': d.customerPhone,
        'subtotal': amount,
        'total': amount,
        'paid': amount,
        'ref_id': payId,
        'note': 'المتبقي بعد الدفعة: ${money(d.amount - newPaid)}',
        'user_name': actor,
        'created_at': now,
      });
      final item = InvoiceItem(name: 'تسديد ${d.debtType}', detail: 'أصل الدين ${money(d.amount)}', price: amount);
      await txn.insert('invoice_items',
          {'invoice_id': invId, 'name': item.name, 'detail': item.detail, 'qty': 1, 'price': amount, 'cost': 0});
      await logActivity(txn, 'تسديد دين', '${d.customerName} — ${money(amount)}');
      return Invoice(
        id: invId,
        type: InvoiceType.debtPay,
        number: number,
        periodId: period,
        customerName: d.customerName,
        customerPhone: d.customerPhone,
        subtotal: amount,
        total: amount,
        paid: amount,
        refId: payId,
        note: 'المتبقي بعد الدفعة: ${money(d.amount - newPaid)}',
        userName: actor,
        createdAt: now,
        items: [item],
      );
    });
    changed();
    await TelegramService.instance.notify('debt', [
      '💵 <b>تسديد دين ${inv.code}</b>',
      '👤 ${TelegramService.esc(d.customerName)}',
      '💰 <b>المبلغ المستلم: ${money(amount)}</b>',
      'المتبقي: ${money(d.remaining - amount)}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(inv.createdAt)}',
    ].join('\n'));
    return inv;
  }

  /// تعديل (مدير فقط)
  static Future<void> update(Debt d, {String? name, String? phone, String? type, int? amount, String? note}) async {
    final newAmount = amount ?? d.amount;
    await db.update(
        'debts',
        {
          'customer_name': name ?? d.customerName,
          'customer_phone': phone ?? d.customerPhone,
          'debt_type': type ?? d.debtType,
          'amount': newAmount,
          'note': note ?? d.note,
          'status': d.paid >= newAmount ? 'closed' : 'open',
        },
        where: 'id = ?',
        whereArgs: [d.id]);
    await logActivity(db, 'تعديل دين', '${d.customerName}: ${money(d.amount)} ← ${money(newAmount)}');
    changed();
  }

  /// حذف (مدير فقط)
  static Future<void> delete(Debt d) async {
    await db.delete('debts', where: 'id = ?', whereArgs: [d.id]);
    await logActivity(db, 'حذف دين', '${d.customerName} — ${money(d.amount)}');
    changed();
  }
}
