import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/license_crypto.dart';

enum LicenseStatus { notActivated, active, expired }

/// اشتراك البرنامج (6 أشهر افتراضياً).
/// يعمل بدون إنترنت تماماً: الكود يُتحقق منه محلياً بالتوقيع.
/// حالة الاشتراك تُحفظ في تخزين منفصل عن قاعدة البيانات، فلا تتأثر بالنسخ الاحتياطي
/// ولا يستطيع الزبون تمديد اشتراكه باستعادة نسخة قديمة.
class LicenseService extends ChangeNotifier {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const _kDevice = 'lic_device_id';
  static const _kExpiry = 'lic_expiry_ms';
  static const _kSeen = 'lic_last_seen';
  static const _kTrialUsed = 'lic_trial_used';
  static const _kIsTrial = 'lic_is_trial';

  /// مدة اليوم المجاني التجريبي
  static const trialMs = 24 * 60 * 60 * 1000;

  late SharedPreferences _prefs;
  String _deviceId = '';
  int _expiry = 0;
  int _lastSeen = 0;
  bool _isTrial = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs.getString(_kDevice) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = _newDeviceId();
      await _prefs.setString(_kDevice, _deviceId);
    }
    _expiry = _prefs.getInt(_kExpiry) ?? 0;
    _lastSeen = _prefs.getInt(_kSeen) ?? 0;
    _isTrial = _prefs.getBool(_kIsTrial) ?? false;
    // أول تشغيل على الإطلاق: يوم مجاني تلقائي للتجربة
    final trialUsed = _prefs.getBool(_kTrialUsed) ?? false;
    if (_expiry == 0 && !trialUsed) {
      _expiry = DateTime.now().millisecondsSinceEpoch + trialMs;
      _isTrial = true;
      await _prefs.setInt(_kExpiry, _expiry);
      await _prefs.setBool(_kTrialUsed, true);
      await _prefs.setBool(_kIsTrial, true);
    }
    await touch();
  }

  /// رمز جهاز عشوائي (60 بت) بصيغة Crockford
  static String _newDeviceId() {
    final r = Random.secure();
    const a = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    return List.generate(12, (_) => a[r.nextInt(32)]).join();
  }

  /// يمنع الغش بإرجاع ساعة الجهاز للخلف: نعتمد أكبر وقت رأيناه
  int get _now {
    final n = DateTime.now().millisecondsSinceEpoch;
    return n > _lastSeen ? n : _lastSeen;
  }

  Future<void> touch() async {
    final n = DateTime.now().millisecondsSinceEpoch;
    if (n > _lastSeen) {
      _lastSeen = n;
      await _prefs.setInt(_kSeen, n);
    }
  }

  /// رمز الجهاز المعروض للمزوّد: ALRB-XXXX-XXXX-XXXX
  String get deviceId => _deviceId;
  String get deviceIdShown {
    final d = _deviceId.padRight(12, '0');
    return 'ALRB-${d.substring(0, 4)}-${d.substring(4, 8)}-${d.substring(8, 12)}';
  }

  bool get isTrial => _isTrial && status == LicenseStatus.active;

  /// انتهت الفترة التجريبية المجانية ولم يُفعّل بكود مدفوع بعد
  bool get trialEnded => _isTrial && status == LicenseStatus.expired;

  int get expiryMs => _expiry;
  DateTime? get expiryDate => _expiry == 0 ? null : DateTime.fromMillisecondsSinceEpoch(_expiry);

  LicenseStatus get status {
    if (_expiry == 0) return LicenseStatus.notActivated;
    return _now <= _expiry ? LicenseStatus.active : LicenseStatus.expired;
  }

  bool get unlocked => status == LicenseStatus.active;

  int get daysLeft {
    if (_expiry == 0) return 0;
    final d = ((_expiry - _now) / 86400000).ceil();
    return d < 0 ? 0 : d;
  }

  int get hoursLeft {
    if (_expiry == 0) return 0;
    final h = ((_expiry - _now) / 3600000).ceil();
    return h < 0 ? 0 : h;
  }

  /// true إذا اقترب انتهاء الاشتراك (10 أيام أو أقل) أو نسخة تجريبية
  bool get expiringSoon => status == LicenseStatus.active && (daysLeft <= 10 || isTrial);

  /// تفعيل/تجديد بكود. يعيد true عند النجاح.
  Future<bool> activate(String code) async {
    final days = verifyCode(_deviceId, code);
    if (days == null) return false;
    final expiry = (days + 1) * 86400000; // شامل ليوم الانتهاء
    if (expiry <= _now) return false; // كود منتهٍ أصلاً
    _expiry = expiry;
    _isTrial = false;
    await _prefs.setInt(_kExpiry, expiry);
    await _prefs.setBool(_kIsTrial, false);
    notifyListeners();
    return true;
  }

  /// للاختبار فقط
  @visibleForTesting
  Future<void> debugReset({String? device, int expiry = 0}) async {
    _deviceId = device ?? _newDeviceId();
    _expiry = expiry;
    _lastSeen = 0;
    _isTrial = false;
    await _prefs.setString(_kDevice, _deviceId);
    await _prefs.setInt(_kExpiry, expiry);
    await _prefs.setBool(_kTrialUsed, true);
    await _prefs.setBool(_kIsTrial, false);
    await _prefs.remove(_kSeen);
    notifyListeners();
  }
}
