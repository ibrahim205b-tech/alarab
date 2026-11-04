import '../../core/format.dart';
import '../../services/telegram.dart';
import '../models.dart';
import 'base.dart';

class RepairsRepo {
  static Future<Repair> create(Repair r) async {
    final rep = await db.transaction((txn) async {
      final number = await nextCounter(txn, 'repair');
      final now = nowMs();
      final id = await txn.insert('repairs', {
        ...r.toEditableMap(),
        'number': number,
        'status': RepairStatus.received.key,
        'received_at': now,
        'user_name': actor,
      });
      await txn.insert('repair_log', {
        'repair_id': id,
        'status': RepairStatus.received.key,
        'note': 'استلام الجهاز من الزبون',
        'user_name': actor,
        'created_at': now,
      });
      await logActivity(txn, 'استلام جهاز صيانة', 'R-$number ${r.device} — ${r.customerName}');
      return (await txn.query('repairs', where: 'id = ?', whereArgs: [id])).map(Repair.fromMap).first;
    });
    changed();
    await TelegramService.instance.notify('repair', [
      '🛠 <b>استلام جهاز صيانة ${rep.code}</b>',
      '📱 ${TelegramService.esc(rep.device)}',
      '🔧 العطل: ${TelegramService.esc(rep.issue)}',
      '👤 ${TelegramService.esc(rep.customerName)} ${rep.customerPhone}',
      if (rep.estimatedCost > 0) 'التكلفة التقديرية: ${money(rep.estimatedCost)}',
      if (rep.deposit > 0) 'العربون: ${money(rep.deposit)}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(rep.receivedAt)}',
    ].join('\n'));
    return rep;
  }

  static Future<List<Repair>> list({Set<RepairStatus>? statuses, String query = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (statuses != null && statuses.isNotEmpty) {
      where.add('status IN (${List.filled(statuses.length, '?').join(',')})');
      args.addAll(statuses.map((e) => e.key));
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      final n = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), ''));
      where.add('(customer_name LIKE ? OR customer_phone LIKE ? OR device_model LIKE ? OR device_brand LIKE ? '
          'OR imei LIKE ? OR issue LIKE ?${n != null ? ' OR number = ?' : ''})');
      args.addAll(List.filled(6, '%$q%'));
      if (n != null) args.add(n);
    }
    final rows = await db.query('repairs',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: "CASE status WHEN 'ready' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'waiting_parts' THEN 2 "
            "WHEN 'received' THEN 3 WHEN 'unfixable' THEN 4 ELSE 5 END, received_at DESC",
        limit: 500);
    return rows.map(Repair.fromMap).toList();
  }

  static Future<Repair?> get(int id) async {
    final r = await db.query('repairs', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Repair.fromMap(r.first);
  }

  static Future<List<RepairLogEntry>> history(int id) async =>
      (await db.query('repair_log', where: 'repair_id = ?', whereArgs: [id], orderBy: 'id DESC'))
          .map(RepairLogEntry.fromMap)
          .toList();

  static Future<Map<RepairStatus, int>> counts() async {
    final rows = await db.rawQuery('SELECT status, COUNT(*) c FROM repairs GROUP BY status');
    return {for (final r in rows) RepairStatusX.parse(r['status'].toString()): (r['c'] as num).toInt()};
  }

  /// تغيير حالة الجهاز (مسار العمل — متاح للموظف)
  static Future<void> setStatus(Repair r, RepairStatus s, {String note = ''}) async {
    if (s == RepairStatus.delivered) throw Exception('استخدم زر التسليم');
    await db.transaction((txn) async {
      await txn.update(
          'repairs',
          {
            'status': s.key,
            if (s == RepairStatus.ready) 'ready_at': nowMs(),
          },
          where: 'id = ?',
          whereArgs: [r.id]);
      await txn.insert('repair_log', {
        'repair_id': r.id,
        'status': s.key,
        'note': note,
        'user_name': actor,
        'created_at': nowMs(),
      });
      await logActivity(txn, 'تحديث حالة صيانة', '${r.code}: ${s.label}');
    });
    changed();
  }

  static Future<void> addNote(Repair r, String note) async {
    if (note.trim().isEmpty) return;
    await db.transaction((txn) async {
      final merged = [r.techNotes, '• ${note.trim()}'].where((e) => e.isNotEmpty).join('\n');
      await txn.update('repairs', {'tech_notes': merged}, where: 'id = ?', whereArgs: [r.id]);
      await txn.insert('repair_log', {
        'repair_id': r.id,
        'status': r.status.key,
        'note': note.trim(),
        'user_name': actor,
        'created_at': nowMs(),
      });
    });
    changed();
  }

  /// تسليم الجهاز للزبون وإصدار فاتورة
  static Future<Invoice> deliver(Repair r, {required int finalCost, int partsCost = 0}) async {
    final inv = await db.transaction((txn) async {
      final period = await currentPeriodId(txn);
      final now = nowMs();
      final invId = await txn.insert('invoices', {
        'type': 'repair',
        'number': r.number,
        'period_id': period,
        'customer_name': r.customerName,
        'customer_phone': r.customerPhone,
        'subtotal': finalCost,
        'total': finalCost,
        'paid': finalCost,
        'cost': partsCost,
        'ref_id': r.id,
        'note': r.deposit > 0 ? 'عربون مستلم مسبقاً: ${money(r.deposit)}' : '',
        'user_name': actor,
        'created_at': now,
      });
      final item = InvoiceItem(
          name: 'صيانة ${r.device}',
          detail: r.issue,
          price: finalCost,
          cost: partsCost);
      await txn.insert('invoice_items', {
        'invoice_id': invId,
        'name': item.name,
        'detail': item.detail,
        'qty': 1,
        'price': finalCost,
        'cost': partsCost,
      });
      await txn.update(
          'repairs',
          {
            'status': RepairStatus.delivered.key,
            'final_cost': finalCost,
            'parts_cost': partsCost,
            'delivered_at': now,
            'invoice_id': invId,
          },
          where: 'id = ?',
          whereArgs: [r.id]);
      await txn.insert('repair_log', {
        'repair_id': r.id,
        'status': RepairStatus.delivered.key,
        'note': 'تسليم للزبون — ${money(finalCost)}',
        'user_name': actor,
        'created_at': now,
      });
      await logActivity(txn, 'تسليم جهاز صيانة', '${r.code} — ${money(finalCost)}');
      return Invoice(
        id: invId,
        type: InvoiceType.repair,
        number: r.number,
        periodId: period,
        customerName: r.customerName,
        customerPhone: r.customerPhone,
        subtotal: finalCost,
        total: finalCost,
        paid: finalCost,
        cost: partsCost,
        refId: r.id,
        note: r.deposit > 0 ? 'عربون مستلم مسبقاً: ${money(r.deposit)}' : '',
        userName: actor,
        createdAt: now,
        items: [item],
      );
    });
    changed();
    await TelegramService.instance.notify('repair', [
      '✅ <b>تسليم جهاز صيانة ${r.code}</b>',
      '📱 ${TelegramService.esc(r.device)}',
      '👤 ${TelegramService.esc(r.customerName)}',
      '💰 <b>المبلغ: ${money(finalCost)}</b>',
      if (r.deposit > 0) 'منها عربون: ${money(r.deposit)} • المستلم الآن: ${money(finalCost - r.deposit)}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(inv.createdAt)}',
    ].join('\n'));
    return inv;
  }

  /// تعديل بيانات الجهاز (مدير فقط)
  static Future<void> update(Repair r) async {
    await db.update('repairs', r.toEditableMap(), where: 'id = ?', whereArgs: [r.id]);
    await logActivity(db, 'تعديل صيانة', r.code);
    changed();
  }

  /// حذف (مدير فقط)
  static Future<void> delete(Repair r) async {
    await db.transaction((txn) async {
      if (r.invoiceId != null) {
        await txn.update('invoices', {'status': 'void', 'note': 'حذف سجل الصيانة'}, where: 'id = ?', whereArgs: [r.invoiceId]);
      }
      await txn.delete('repairs', where: 'id = ?', whereArgs: [r.id]);
      await logActivity(txn, 'حذف صيانة', '${r.code} ${r.device} — ${r.customerName}');
    });
    changed();
  }
}
