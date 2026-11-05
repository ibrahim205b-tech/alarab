import 'package:sqflite/sqflite.dart';

import '../../core/format.dart';
import '../models.dart';
import 'base.dart';

class ProductsRepo {
  static Future<List<Category>> categories() async =>
      (await db.query('categories', orderBy: 'sort, id')).map(Category.fromMap).toList();

  static Future<int> addCategory(String name, String icon, int color) async {
    final id = await db.insert('categories', {'name': name.trim(), 'icon': icon, 'color': color, 'sort': 99});
    changed();
    return id;
  }

  static Future<List<Product>> search({
    String query = '',
    int? categoryId,
    bool lowOnly = false,
    bool inStockOnly = false,
  }) async {
    final where = <String>['active = 1'];
    final args = <Object?>[];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (lowOnly) where.add('qty <= min_qty');
    if (inStockOnly) where.add('qty > 0');
    final q = query.trim();
    if (q.isNotEmpty) {
      // كل كلمة يجب أن تطابق أحد الحقول
      for (final word in q.split(RegExp(r'\s+'))) {
        where.add('(name LIKE ? OR brand LIKE ? OR model LIKE ? OR barcode = ? OR imei LIKE ? OR color LIKE ?)');
        final like = '%$word%';
        args.addAll([like, like, like, word, like, like]);
      }
    }
    final rows = await db.query('products', where: where.join(' AND '), whereArgs: args, orderBy: 'updated_at DESC');
    return rows.map(Product.fromMap).toList();
  }

  static Future<Product?> byId(int id) async {
    final r = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Product.fromMap(r.first);
  }

  static Future<Product?> byBarcode(String code) async {
    if (code.trim().isEmpty) return null;
    final r = await db.query('products',
        where: 'active = 1 AND (barcode = ? OR imei = ?)', whereArgs: [code.trim(), code.trim()], limit: 1);
    return r.isEmpty ? null : Product.fromMap(r.first);
  }

  /// إضافة منتج جديد (مسموح للموظف) مع تسجيل الحركة
  static Future<int> create(Product p, int qty) async {
    if (p.imei.trim().isNotEmpty) {
      final r = await db.query('products', columns: ['name'], where: 'active = 1 AND imei = ?', whereArgs: [p.imei.trim()], limit: 1);
      if (r.isNotEmpty) throw Exception('رقم IMEI مسجل مسبقاً للمنتج: ${r.first['name']}');
    }
    if (p.barcode.trim().isNotEmpty) {
      final r = await db.query('products', columns: ['name'], where: 'active = 1 AND barcode = ?', whereArgs: [p.barcode.trim()], limit: 1);
      if (r.isNotEmpty) throw Exception('الباركود مسجل مسبقاً للمنتج "${r.first['name']}" — استخدم "إضافة كمية" بدل منتج جديد');
    }
    final id = await db.transaction((txn) async {
      final now = nowMs();
      final id = await txn.insert('products', {
        ...p.toMap(),
        'qty': qty,
        'active': 1,
        'created_by': actor,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('stock_log', {
        'product_id': id,
        'change': qty,
        'qty_after': qty,
        'reason': 'create',
        'user_name': actor,
        'created_at': now,
      });
      await logActivity(txn, 'إضافة منتج', '${p.name} — الكمية $qty — السعر ${money(p.price)}');
      return id;
    });
    changed();
    return id;
  }

  /// إضافة كمية لمنتج موجود (مسموح للموظف)
  static Future<void> restock(int productId, int qty, {String note = '', int? newCost}) async {
    if (qty <= 0) return;
    await db.transaction((txn) async {
      await _changeQty(txn, productId, qty, 'restock', note: note);
      if (newCost != null && newCost > 0) {
        await txn.update('products', {'cost': newCost}, where: 'id = ?', whereArgs: [productId]);
      }
    });
    changed();
  }

  /// تعديل بيانات المنتج (مدير فقط)
  static Future<void> update(Product p) async {
    await db.update('products', {...p.toMap(), 'updated_at': nowMs()}, where: 'id = ?', whereArgs: [p.id]);
    await logActivity(db, 'تعديل منتج', p.name);
    changed();
  }

  /// تعديل جرد (مدير فقط) — يضبط الكمية الفعلية
  static Future<void> adjust(int productId, int newQty, String note) async {
    await db.transaction((txn) async {
      final r = await txn.query('products', columns: ['qty', 'name'], where: 'id = ?', whereArgs: [productId]);
      if (r.isEmpty) return;
      final cur = (r.first['qty'] as num).toInt();
      if (cur == newQty) return;
      await _changeQty(txn, productId, newQty - cur, 'adjust', note: note);
      await logActivity(txn, 'تعديل جرد', '${r.first['name']}: $cur ← $newQty');
    });
    changed();
  }

  /// حذف المنتج (مدير فقط) — حذف ناعم حتى تبقى الفواتير القديمة سليمة
  static Future<void> delete(Product p) async {
    await db.update('products', {'active': 0, 'updated_at': nowMs()}, where: 'id = ?', whereArgs: [p.id]);
    await logActivity(db, 'حذف منتج', p.name);
    changed();
  }

  static Future<void> _changeQty(DatabaseExecutor ex, int productId, int change, String reason,
      {String ref = '', String note = ''}) async {
    await ex.rawUpdate('UPDATE products SET qty = qty + ?, updated_at = ? WHERE id = ?', [change, nowMs(), productId]);
    final r = await ex.query('products', columns: ['qty'], where: 'id = ?', whereArgs: [productId]);
    await ex.insert('stock_log', {
      'product_id': productId,
      'change': change,
      'qty_after': r.isEmpty ? 0 : r.first['qty'],
      'reason': reason,
      'ref': ref,
      'note': note,
      'user_name': actor,
      'created_at': nowMs(),
    });
  }

  static Future<void> changeQty(DatabaseExecutor ex, int productId, int change, String reason,
          {String ref = '', String note = ''}) =>
      _changeQty(ex, productId, change, reason, ref: ref, note: note);

  static Future<List<StockEntry>> history(int productId) async => (await db.query('stock_log',
          where: 'product_id = ?', whereArgs: [productId], orderBy: 'id DESC', limit: 200))
      .map(StockEntry.fromMap)
      .toList();

  static Future<(int count, int units, int costValue, int saleValue, int low)> stats() async {
    final r = await db.rawQuery('''SELECT COUNT(*) c, COALESCE(SUM(qty),0) u,
        COALESCE(SUM(qty*cost),0) cv, COALESCE(SUM(qty*price),0) sv,
        COALESCE(SUM(CASE WHEN qty <= min_qty THEN 1 ELSE 0 END),0) low
        FROM products WHERE active = 1''');
    final m = r.first;
    int v(String k) => (m[k] as num).toInt();
    return (v('c'), v('u'), v('cv'), v('sv'), v('low'));
  }
}
