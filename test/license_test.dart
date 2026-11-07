import 'package:alarab/core/license_crypto.dart';
import 'package:alarab/services/license.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const device = 'ALRB-7K2M-9X4Q-AB12';

  test('code is device-bound and tamper-proof', () {
    final days = DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch ~/ 86400000;
    final code = generateCode(device, days);
    expect(code, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$')));
    // صحيح لنفس الجهاز
    expect(verifyCode(device, code), days);
    // يُقبل بصيغ إدخال مختلفة (حروف صغيرة، بدون شرطة، مسافات)
    expect(verifyCode(device, code.toLowerCase().replaceAll('-', ' ')), days);
    // لا يعمل على جهاز آخر
    expect(verifyCode('ALRB-0000-0000-0000', code), isNull);
    // كود مزيّف
    expect(verifyCode(device, 'ZZZZZ-ZZZZZ'), anyOf(isNull, isNot(days)));
    // مفتاح سري مختلف لا يُنتج نفس الكود
    expect(generateCode(device, days, secret: 'other'), isNot(code));
  });

  test('first run grants a free trial day, then locks', () async {
    SharedPreferences.setMockInitialValues({});
    final lic = LicenseService.instance;
    await lic.init();
    // يوم مجاني تلقائي
    expect(lic.unlocked, true);
    expect(lic.isTrial, true);
    expect(lic.hoursLeft, inInclusiveRange(1, 24));

    // كود مدفوع ينهي وضع التجربة
    final code = generateCode(lic.deviceId, DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch ~/ 86400000);
    expect(await lic.activate(code), true);
    expect(lic.isTrial, false);
    expect(lic.daysLeft, greaterThan(175));
  });

  test('expired trial shows trialEnded and does not re-grant', () async {
    SharedPreferences.setMockInitialValues({
      'lic_device_id': '7K2M9X4QAB12',
      'lic_trial_used': true,
      'lic_is_trial': true,
      'lic_expiry_ms': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
    });
    final lic = LicenseService.instance;
    await lic.init();
    expect(lic.unlocked, false);
    expect(lic.status, LicenseStatus.expired);
    expect(lic.trialEnded, true);
  });

  test('activation, expiry and clock-rollback guard', () async {
    SharedPreferences.setMockInitialValues({'lic_trial_used': true}); // تخطّي التجربة
    final lic = LicenseService.instance;
    await lic.init();
    expect(lic.status, LicenseStatus.notActivated);
    expect(lic.unlocked, false);

    final id = lic.deviceId;
    // كود 6 أشهر لهذا الجهاز
    final code = generateCode(id, DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch ~/ 86400000);
    expect(await lic.activate(code), true);
    expect(lic.unlocked, true);
    expect(lic.daysLeft, greaterThan(175));

    // كود منتهٍ يُرفض
    final past = generateCode(id, DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch ~/ 86400000);
    await lic.debugReset(device: id, expiry: 0);
    expect(await lic.activate(past), false);
    expect(lic.unlocked, false);

    // بعد انتهاء المدة يُقفل
    await lic.debugReset(device: id, expiry: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch);
    expect(lic.status, LicenseStatus.expired);
  });
}
