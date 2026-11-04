import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// المستخدم الحالي المسجّل دخوله
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  AppUser? _user;
  AppUser? get user => _user;
  bool get loggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String get actor => _user?.name ?? 'النظام';

  void login(AppUser u) {
    _user = u;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

/// ناقل أحداث بسيط: أي تعديل على البيانات يُبلغ الشاشات لتعيد التحميل
class DataBus extends ChangeNotifier {
  DataBus._();
  static final DataBus instance = DataBus._();
  int _rev = 0;
  int get rev => _rev;
  void bump() {
    _rev++;
    notifyListeners();
  }
}
