import '../../core/format.dart';
import '../../services/telegram.dart';
import '../models.dart';
import 'base.dart';

class LinesRepo {
  // ---------------- الكتالوج (الإدارة) ----------------
  static Future<List<Carrier>> carriers() async =>
      (await db.query('carriers', orderBy: 'sort, id')).map(Carrier.fromMap).toList();

  static Future<List<LineType>> lineTypes({bool activeOnly = false}) async {
    final rows = await db.rawQuery('''SELECT t.*, c.name carrier_name FROM line_types t
        JOIN carriers c ON c.id = t.carrier_id ${activeOnly ? 'WHERE t.active = 1' : ''}
        ORDER BY c.sort, t.sort, t.id''');
    return rows.map(LineType.fromMap).toList();
  }

  static Future<List<Service>> services({int? lineTypeId, bool activeOnly = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (lineTypeId != null) {
      where.add('line_type_id = ?');
      args.add(lineTypeId);
    }
    if (activeOnly) where.add('active = 1');
    final rows = await db.query('services',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'sort, price, id');
    return rows.map(Service.fromMap).toList();
  }

  static Future<int> addCarrier(String name, int color) async {
    final id = await db.insert('carriers', {'name': name.trim(), 'color': color, 'sort': 50});
    await logActivity(db, 'إضافة شركة اتصال', name);
    changed();
    return id;
  }

  static Future<void> updateCarrier(int id, String name, int color) async {
    await db.update('carriers', {'name': name.trim(), 'color': color}, where: 'id = ?', whereArgs: [id]);
    changed();
  }

  static Future<void> deleteCarrier(int id) async {
    final types = await db.query('line_types', where: 'carrier_id = ?', whereArgs: [id]);
    if (types.isNotEmpty) throw Exception('احذف أنواع الخطوط التابعة لهذه الشركة أولاً');
    await db.delete('carriers', where: 'id = ?', whereArgs: [id]);
    changed();
  }

  static Future<int> addLineType(int carrierId, String name, int color) async {
    final id = await db.insert('line_types', {'carrier_id': carrierId, 'name': name.trim(), 'color': color, 'sort': 50});
    await logActivity(db, 'إضافة نوع خط', name);
    changed();
    return id;
  }

  static Future<void> updateLineType(int id, {String? name, int? color, int? carrierId, bool? active}) async {
    await db.update(
        'line_types',
        {
          if (name != null) 'name': name.trim(),
          if (color != null) 'color': color,
          if (carrierId != null) 'carrier_id': carrierId,
          if (active != null) 'active': active ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
    changed();
  }

  static Future<void> deleteLineType(int id) async {
    await db.transaction((txn) async {
      await txn.delete('services', where: 'line_type_id = ?', whereArgs: [id]);
      await txn.delete('line_types', where: 'id = ?', whereArgs: [id]);
      await logActivity(txn, 'حذف نوع خط', '#$id');
    });
    changed();
  }

  static Future<int> addService(int lineTypeId, String name, int price, int cost) async {
    final id = await db.insert('services',
        {'line_type_id': lineTypeId, 'name': name.trim(), 'price': price, 'cost': cost, 'active': 1, 'sort': 50});
    await logActivity(db, 'إضافة خدمة', '$name — ${money(price)}');
    changed();
    return id;
  }

  static Future<void> updateService(int id, {String? name, int? price, int? cost, bool? active}) async {
    await db.update(
        'services',
        {
          if (name != null) 'name': name.trim(),
          if (price != null) 'price': price,
          if (cost != null) 'cost': cost,
          if (active != null) 'active': active ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
    await logActivity(db, 'تعديل خدمة', name ?? '#$id');
    changed();
  }

  static Future<void> deleteService(int id) async {
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
    await logActivity(db, 'حذف خدمة', '#$id');
    changed();
  }

  // ---------------- المبيعات ----------------

  /// تسجيل خط/خدمة مباعة — يُنشئ رقماً تسلسلياً وفاتورة
  static Future<(LineSale, Invoice)> sell({
    required LineType type,
    required Service service,
    required int amount,
    String customerPhone = '',
  }) async {
    if (amount <= 0) throw Exception('المبلغ غير صحيح');
    final result = await db.transaction((txn) async {
      final number = await nextCounter(txn, 'line');
      final period = await currentPeriodId(txn);
      final now = nowMs();
      final invId = await txn.insert('invoices', {
        'type': 'line',
        'number': number,
        'period_id': period,
        'customer_phone': customerPhone.trim(),
        'subtotal': amount,
        'total': amount,
        'paid': amount,
        'cost': service.cost,
        'user_name': actor,
        'created_at': now,
      });
      final item = InvoiceItem(
          name: service.name, detail: '${type.carrierName} — ${type.name}', price: amount, cost: service.cost);
      await txn.insert('invoice_items', {
        'invoice_id': invId,
        'name': item.name,
        'detail': item.detail,
        'qty': 1,
        'price': amount,
        'cost': service.cost,
      });
      final saleId = await txn.insert('line_sales', {
        'number': number,
        'period_id': period,
        'invoice_id': invId,
        'carrier_name': type.carrierName,
        'line_type_id': type.id,
        'line_type_name': type.name,
        'service_id': service.id,
        'service_name': service.name,
        'amount': amount,
        'cost': service.cost,
        'customer_phone': customerPhone.trim(),
        'user_name': actor,
        'created_at': now,
      });
      await txn.update('invoices', {'ref_id': saleId}, where: 'id = ?', whereArgs: [invId]);
      await logActivity(txn, 'بيع خط', '#$number ${service.name} — ${money(amount)}');
      final sale = LineSale(
        id: saleId,
        number: number,
        periodId: period,
        invoiceId: invId,
        carrierName: type.carrierName,
        lineTypeId: type.id,
        lineTypeName: type.name,
        serviceId: service.id,
        serviceName: service.name,
        amount: amount,
        cost: service.cost,
        customerPhone: customerPhone.trim(),
        userName: actor,
        createdAt: now,
      );
      final inv = Invoice(
        id: invId,
        type: InvoiceType.line,
        number: number,
        periodId: period,
        customerPhone: customerPhone.trim(),
        subtotal: amount,
        total: amount,
        paid: amount,
        cost: service.cost,
        refId: saleId,
        userName: actor,
        createdAt: now,
        items: [item],
      );
      return (sale, inv);
    });
    changed();
    final s = result.$1;
    await TelegramService.instance.notify('line', [
      '📶 <b>بيع خط جديد #${s.number}</b>',
      'الشركة: ${TelegramService.esc(s.carrierName)}',
      'نوع الخط: ${TelegramService.esc(s.lineTypeName)}',
      'الخدمة: ${TelegramService.esc(s.serviceName)}',
      '💰 <b>المبلغ: ${money(s.amount)}</b>',
      if (s.customerPhone.isNotEmpty) '📱 ${s.customerPhone}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(s.createdAt)}',
    ].join('\n'));
    return result;
  }

  static Future<List<LineSale>> sales({DateTime? from, DateTime? to, int? lineTypeId, bool includeVoid = false, int? periodId}) async {
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
    if (lineTypeId != null) {
      where.add('line_type_id = ?');
      args.add(lineTypeId);
    }
    if (periodId != null) {
      where.add('period_id = ?');
      args.add(periodId);
    }
    if (!includeVoid) where.add("status = 'active'");
    final rows = await db.query('line_sales',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'id DESC', limit: 1000);
    return rows.map(LineSale.fromMap).toList();
  }

  /// تعديل خط مباع (مدير فقط)
  static Future<void> updateSale(LineSale s, {required LineType type, required Service service, required int amount, String? phone}) async {
    await db.transaction((txn) async {
      await txn.update(
          'line_sales',
          {
            'carrier_name': type.carrierName,
            'line_type_id': type.id,
            'line_type_name': type.name,
            'service_id': service.id,
            'service_name': service.name,
            'amount': amount,
            'cost': service.cost,
            if (phone != null) 'customer_phone': phone,
          },
          where: 'id = ?',
          whereArgs: [s.id]);
      if (s.invoiceId != null) {
        await txn.update(
            'invoices',
            {
              'subtotal': amount,
              'total': amount,
              'paid': amount,
              'cost': service.cost,
              if (phone != null) 'customer_phone': phone,
              'updated_at': nowMs()
            },
            where: 'id = ?',
            whereArgs: [s.invoiceId]);
        await txn.update(
            'invoice_items',
            {'name': service.name, 'detail': '${type.carrierName} — ${type.name}', 'price': amount, 'cost': service.cost},
            where: 'invoice_id = ?',
            whereArgs: [s.invoiceId]);
      }
      await logActivity(txn, 'تعديل خط مباع', '#${s.number}: ${s.serviceName} ${money(s.amount)} ← ${service.name} ${money(amount)}');
    });
    changed();
  }

  /// حذف خط مباع (مدير فقط) — يلغي فاتورته
  static Future<void> deleteSale(LineSale s) async {
    await db.transaction((txn) async {
      await txn.update('line_sales', {'status': 'void'}, where: 'id = ?', whereArgs: [s.id]);
      if (s.invoiceId != null) {
        await txn.update('invoices', {'status': 'void', 'note': 'حذف من المدير', 'updated_at': nowMs()},
            where: 'id = ?', whereArgs: [s.invoiceId]);
      }
      await logActivity(txn, 'حذف خط مباع', '#${s.number} ${s.serviceName} — ${money(s.amount)}');
    });
    changed();
  }
}
