import '../../core/format.dart';
import '../../services/telegram.dart';
import '../models.dart';
import 'base.dart';
import 'products_repo.dart';

class CartLine {
  final Product product;
  int qty;
  int price;
  CartLine(this.product, {this.qty = 1, int? price}) : price = price ?? product.price;
  int get total => qty * price;
}

class SalesRepo {
  /// إتمام بيع منتجات من نقطة البيع
  static Future<Invoice> checkout({
    required List<CartLine> cart,
    int discount = 0,
    String customerName = '',
    String customerPhone = '',
    String payment = 'cash',
    int? paidNow,
    String note = '',
  }) async {
    if (cart.isEmpty) throw Exception('السلة فارغة');
    final subtotal = cart.fold<int>(0, (s, l) => s + l.total);
    final total = (subtotal - discount).clamp(0, subtotal);
    final paid = payment == 'credit' ? (paidNow ?? 0).clamp(0, total) : total;
    if (payment == 'credit' && customerName.trim().isEmpty) {
      throw Exception('البيع بالآجل يحتاج اسم الزبون');
    }

    final invoice = await db.transaction((txn) async {
      // التحقق من توفر الكميات
      for (final l in cart) {
        final r = await txn.query('products', columns: ['qty', 'name'], where: 'id = ?', whereArgs: [l.product.id]);
        final available = r.isEmpty ? 0 : (r.first['qty'] as num).toInt();
        if (available < l.qty) {
          throw Exception('الكمية غير كافية: ${l.product.name} (المتوفر $available)');
        }
      }
      final number = await nextCounter(txn, 'sale');
      final period = await currentPeriodId(txn);
      final cost = cart.fold<int>(0, (s, l) => s + l.product.cost * l.qty);
      final now = nowMs();
      final id = await txn.insert('invoices', {
        'type': 'sale',
        'number': number,
        'period_id': period,
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone.trim(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid': paid,
        'cost': cost,
        'payment': payment,
        'note': note,
        'user_name': actor,
        'created_at': now,
      });
      final items = <InvoiceItem>[];
      for (final l in cart) {
        final item = InvoiceItem(
          productId: l.product.id,
          name: l.product.name,
          detail: [l.product.subtitle, if (l.product.imei.isNotEmpty) 'IMEI: ${l.product.imei}']
              .where((e) => e.isNotEmpty)
              .join(' — '),
          qty: l.qty,
          price: l.price,
          cost: l.product.cost,
        );
        items.add(item);
        await txn.insert('invoice_items', {
          'invoice_id': id,
          'product_id': item.productId,
          'name': item.name,
          'detail': item.detail,
          'qty': item.qty,
          'price': item.price,
          'cost': item.cost,
        });
        await ProductsRepo.changeQty(txn, l.product.id, -l.qty, 'sale', ref: 'S-$number');
      }
      if (payment == 'credit' && total - paid > 0) {
        await txn.insert('debts', {
          'customer_name': customerName.trim(),
          'customer_phone': customerPhone.trim(),
          'debt_type': 'بيع آجل',
          'amount': total,
          'paid': paid,
          'note': 'فاتورة S-$number',
          'status': 'open',
          'invoice_id': id,
          'user_name': actor,
          'created_at': now,
        });
      }
      await logActivity(txn, 'بيع منتجات', 'S-$number — ${money(total)}');
      return Invoice(
        id: id,
        type: InvoiceType.sale,
        number: number,
        periodId: period,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        subtotal: subtotal,
        discount: discount,
        total: total,
        paid: paid,
        cost: cost,
        payment: payment,
        note: note,
        userName: actor,
        createdAt: now,
        items: items,
      );
    });
    changed();

    final lines = invoice.items.map((i) => '▫️ ${TelegramService.esc(i.name)} × ${i.qty} = ${money(i.total)}').join('\n');
    await TelegramService.instance.notify('sale', [
      '🛍 <b>بيع منتجات ${invoice.code}</b>',
      lines,
      if (discount > 0) 'الخصم: ${money(discount)}',
      '💰 <b>الإجمالي: ${money(total)}</b>',
      if (payment == 'credit') '⚠️ آجل — المدفوع ${money(paid)} والمتبقي ${money(total - paid)}',
      if (customerName.trim().isNotEmpty) '👤 ${TelegramService.esc(customerName.trim())} ${customerPhone.trim()}',
      '🧑‍💼 ${TelegramService.esc(actor)} • 🕒 ${dateTimeMs(invoice.createdAt)}',
    ].join('\n'));
    return invoice;
  }

  static Future<Invoice?> get(int id) async {
    final r = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return null;
    final items = (await db.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id], orderBy: 'id'))
        .map(InvoiceItem.fromMap)
        .toList();
    return Invoice.fromMap(r.first, items);
  }

  static Future<List<Invoice>> list({
    InvoiceType? type,
    DateTime? from,
    DateTime? to,
    String query = '',
    bool includeVoid = true,
    int limit = 300,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type.key);
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (!includeVoid) where.add("status = 'active'");
    final q = query.trim();
    if (q.isNotEmpty) {
      final n = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), ''));
      where.add('(customer_name LIKE ? OR customer_phone LIKE ? OR note LIKE ?${n != null ? ' OR number = ?' : ''}'
          ' OR id IN (SELECT invoice_id FROM invoice_items WHERE name LIKE ? OR detail LIKE ?))');
      args.addAll(['%$q%', '%$q%', '%$q%', if (n != null) n, '%$q%', '%$q%']);
    }
    final rows = await db.query('invoices',
        where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC', limit: limit);
    return rows.map((m) => Invoice.fromMap(m)).toList();
  }

  /// إلغاء فاتورة (مدير فقط): يرجع المخزون ويلغي القيود المرتبطة
  static Future<void> voidInvoice(Invoice inv, String reason) async {
    if (inv.isVoid) return;
    await db.transaction((txn) async {
      await txn.update('invoices', {'status': 'void', 'note': reason, 'updated_at': nowMs()},
          where: 'id = ?', whereArgs: [inv.id]);
      switch (inv.type) {
        case InvoiceType.sale:
          final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [inv.id]);
          for (final it in items) {
            final pid = it['product_id'];
            if (pid != null) {
              await ProductsRepo.changeQty(txn, (pid as num).toInt(), (it['qty'] as num).toInt(), 'void',
                  ref: inv.code, note: reason);
            }
          }
          await txn.delete('debts', where: 'invoice_id = ?', whereArgs: [inv.id]);
        case InvoiceType.line:
          await txn.update('line_sales', {'status': 'void'}, where: 'invoice_id = ?', whereArgs: [inv.id]);
        case InvoiceType.repair:
          final r = await txn.query('repairs', columns: ['id'], where: 'invoice_id = ?', whereArgs: [inv.id]);
          for (final rep in r) {
            await txn.update('repairs', {'status': 'ready', 'delivered_at': null, 'invoice_id': null},
                where: 'id = ?', whereArgs: [rep['id']]);
            await txn.insert('repair_log', {
              'repair_id': rep['id'],
              'status': 'ready',
              'note': 'إلغاء فاتورة التسليم: $reason',
              'user_name': actor,
              'created_at': nowMs(),
            });
          }
        case InvoiceType.debtPay:
          if (inv.refId != null) {
            final p = await txn.query('debt_payments', where: 'id = ?', whereArgs: [inv.refId]);
            if (p.isNotEmpty) {
              final debtId = p.first['debt_id'];
              await txn.rawUpdate("UPDATE debts SET paid = paid - ?, status = 'open', closed_at = NULL WHERE id = ?",
                  [p.first['amount'], debtId]);
              await txn.delete('debt_payments', where: 'id = ?', whereArgs: [inv.refId]);
            }
          }
      }
      await logActivity(txn, 'إلغاء فاتورة', '${inv.code} — ${money(inv.total)} — $reason');
    });
    changed();
  }

  /// تعديل بيانات فاتورة (مدير فقط)
  static Future<void> edit(Invoice inv, {String? customerName, String? customerPhone, int? discount, String? note}) async {
    final newDiscount = discount ?? inv.discount;
    final newTotal = (inv.subtotal - newDiscount).clamp(0, inv.subtotal);
    await db.update(
        'invoices',
        {
          'customer_name': customerName ?? inv.customerName,
          'customer_phone': customerPhone ?? inv.customerPhone,
          'discount': newDiscount,
          'total': newTotal,
          if (inv.payment != 'credit') 'paid': newTotal,
          'note': note ?? inv.note,
          'updated_at': nowMs(),
        },
        where: 'id = ?',
        whereArgs: [inv.id]);
    await logActivity(db, 'تعديل فاتورة', '${inv.code}: ${money(inv.total)} ← ${money(newTotal)}');
    changed();
  }
}
