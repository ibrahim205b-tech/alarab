import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/format.dart';
import '../models.dart';
import 'base.dart';

class UsersRepo {
  static String hashPin(String pin) => sha256.convert(utf8.encode('alarab::$pin')).toString();

  static Future<bool> hasAdmin() async {
    final r = await db.rawQuery("SELECT COUNT(*) c FROM users WHERE role='admin' AND active=1");
    return sumOf(r, 'c') > 0;
  }

  static Future<List<AppUser>> all({bool activeOnly = false}) async {
    final rows = await db.query('users',
        where: activeOnly ? 'active = 1' : null, orderBy: "CASE role WHEN 'admin' THEN 0 ELSE 1 END, name");
    return rows.map(AppUser.fromMap).toList();
  }

  static Future<AppUser> create(String name, String pin, String role) async {
    final id = await db.insert('users', {
      'name': name.trim(),
      'pin_hash': hashPin(pin),
      'role': role,
      'active': 1,
      'created_at': nowMs(),
    });
    await logActivity(db, 'إضافة مستخدم', '${name.trim()} (${role == 'admin' ? 'مدير' : 'موظف'})');
    changed();
    return AppUser(id: id, name: name.trim(), role: role);
  }

  static Future<bool> verify(int userId, String pin) async {
    final r = await db.query('users', where: 'id = ? AND active = 1', whereArgs: [userId]);
    return r.isNotEmpty && r.first['pin_hash'] == hashPin(pin);
  }

  /// التحقق من رمز أي مدير (لتأكيد العمليات الحساسة من جهاز الموظف)
  static Future<AppUser?> verifyAnyAdmin(String pin) async {
    final r = await db.query('users',
        where: "role = 'admin' AND active = 1 AND pin_hash = ?", whereArgs: [hashPin(pin)], limit: 1);
    return r.isEmpty ? null : AppUser.fromMap(r.first);
  }

  static Future<void> update(int id, {String? name, String? pin, String? role, bool? active}) async {
    final m = <String, Object?>{};
    if (name != null) m['name'] = name.trim();
    if (pin != null && pin.isNotEmpty) m['pin_hash'] = hashPin(pin);
    if (role != null) m['role'] = role;
    if (active != null) m['active'] = active ? 1 : 0;
    if (m.isEmpty) return;
    if ((role != null && role != 'admin') || active == false) {
      final r = await db.rawQuery("SELECT COUNT(*) c FROM users WHERE role='admin' AND active=1 AND id != ?", [id]);
      final self = await db.query('users', where: 'id = ?', whereArgs: [id]);
      if (self.isNotEmpty && self.first['role'] == 'admin' && sumOf(r, 'c') == 0) {
        throw Exception('لا يمكن إزالة آخر مدير في النظام');
      }
    }
    await db.update('users', m, where: 'id = ?', whereArgs: [id]);
    await logActivity(db, 'تعديل مستخدم', name ?? '#$id');
    changed();
  }
}
