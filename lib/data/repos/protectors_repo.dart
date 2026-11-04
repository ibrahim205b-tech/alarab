import '../db.dart';
import '../models.dart';
import 'base.dart';

class ProtectorMatch {
  final ProtectorGroup group;
  final Set<int> matchedIds;
  final bool exact;
  const ProtectorMatch(this.group, this.matchedIds, this.exact);
}

class ProtectorsRepo {
  static Future<List<ProtectorGroup>> groups() async {
    final g = await db.rawQuery('''SELECT g.*, COALESCE((SELECT SUM(qty) FROM products p
        WHERE p.protector_group_id = g.id AND p.active = 1), 0) stock
        FROM protector_groups g ORDER BY g.id''');
    final m = await db.query('protector_models', orderBy: 'id');
    final byGroup = <int, List<ProtectorModel>>{};
    for (final r in m) {
      final pm = ProtectorModel.fromMap(r);
      byGroup.putIfAbsent(pm.groupId, () => []).add(pm);
    }
    return g.map((r) {
      final id = (r['id'] as num).toInt();
      return ProtectorGroup(id, r['name'].toString(), r['size'].toString(), r['notes'].toString(),
          (r['builtin'] as num).toInt() == 1, byGroup[id] ?? const [],
          stock: (r['stock'] as num).toInt());
    }).toList();
  }

  /// بحث دقيق: يطابق اسم الجهاز بعد التطبيع (بدون فراغات/رموز، عربي أو إنجليزي)
  /// المطابقة التامة تظهر أولاً، ثم المطابقات الجزئية كاقتراحات.
  static List<ProtectorMatch> search(List<ProtectorGroup> all, String query) {
    final q = protectorKey(query);
    if (q.isEmpty) return all.map((g) => ProtectorMatch(g, const {}, false)).toList();
    final tokens = query
        .split(RegExp(r'\s+'))
        .map(protectorKey)
        .where((t) => t.isNotEmpty)
        .toList();

    final exact = <ProtectorMatch>[];
    final partial = <ProtectorMatch>[];
    for (final g in all) {
      final exactIds = <int>{};
      final partialIds = <int>{};
      for (final m in g.models) {
        final sk = protectorKey('${m.brand} ${m.model}');
        final mk = protectorKey(m.model);
        final bk = protectorKey(m.brand);
        if (sk == q || mk == q || sk == bk + q || mk == q.replaceFirst(bk, '')) {
          exactIds.add(m.id);
        } else if (sk.contains(q) || tokens.every(sk.contains)) {
          partialIds.add(m.id);
        }
      }
      if (exactIds.isNotEmpty) {
        exact.add(ProtectorMatch(g, exactIds, true));
      } else if (partialIds.isNotEmpty) {
        partial.add(ProtectorMatch(g, partialIds, false));
      } else if (protectorKey(g.name).contains(q)) {
        partial.add(ProtectorMatch(g, const {}, false));
      }
    }
    return [...exact, ...partial];
  }

  static Future<int> addGroup(String name, String size, String notes, List<(String, String)> models) async {
    final id = await db.transaction((txn) async {
      final id = await txn.insert('protector_groups', {'name': name.trim(), 'size': size.trim(), 'notes': notes.trim(), 'builtin': 0});
      for (final m in models) {
        await txn.insert('protector_models', {
          'group_id': id,
          'brand': m.$1.trim(),
          'model': m.$2.trim(),
          'search_key': protectorKey('${m.$1} ${m.$2}'),
        });
      }
      await logActivity(txn, 'إضافة مجموعة توافق', name);
      return id;
    });
    changed();
    return id;
  }

  static Future<void> updateGroup(int id, String name, String size, String notes) async {
    await db.update('protector_groups', {'name': name.trim(), 'size': size.trim(), 'notes': notes.trim()},
        where: 'id = ?', whereArgs: [id]);
    changed();
  }

  static Future<void> addModel(int groupId, String brand, String model) async {
    await db.insert('protector_models', {
      'group_id': groupId,
      'brand': brand.trim(),
      'model': model.trim(),
      'search_key': protectorKey('$brand $model'),
    });
    await logActivity(db, 'إضافة جهاز لمجموعة توافق', '$brand $model');
    changed();
  }

  static Future<void> deleteModel(int id) async {
    await db.delete('protector_models', where: 'id = ?', whereArgs: [id]);
    changed();
  }

  static Future<void> deleteGroup(int id) async {
    await db.transaction((txn) async {
      await txn.update('products', {'protector_group_id': null}, where: 'protector_group_id = ?', whereArgs: [id]);
      await txn.delete('protector_models', where: 'group_id = ?', whereArgs: [id]);
      await txn.delete('protector_groups', where: 'id = ?', whereArgs: [id]);
      await logActivity(txn, 'حذف مجموعة توافق', '#$id');
    });
    changed();
  }

  static Future<List<Product>> productsFor(int groupId) async => (await db.query('products',
          where: 'protector_group_id = ? AND active = 1', whereArgs: [groupId], orderBy: 'qty DESC'))
      .map(Product.fromMap)
      .toList();
}
