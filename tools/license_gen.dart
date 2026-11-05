// مولّد أكواد تفعيل برنامج "مبيعات علي العراب".
//
// الاستخدام:
//   dart run tools/license_gen.dart <رمز-الجهاز> [عدد-الأشهر]
// أمثلة:
//   dart run tools/license_gen.dart ALRB-7K2M-9X4Q-AB12          (افتراضي 6 أشهر)
//   dart run tools/license_gen.dart ALRB-7K2M-9X4Q-AB12 1        (شهر واحد)
//   dart run tools/license_gen.dart ALRB-7K2M-9X4Q-AB12 --days 7 (7 أيام)
//
// المفتاح السري: يُقرأ من متغير البيئة ALARAB_LICENSE_SECRET إن وُجد،
// وإلا يُستخدم المفتاح الافتراضي المضمّن في البرنامج.
import 'dart:io';

import 'package:alarab/core/license_crypto.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('الاستخدام: dart run tools/license_gen.dart <رمز-الجهاز> [عدد-الأشهر]');
    exit(1);
  }
  final device = args[0];
  final secret = Platform.environment['ALARAB_LICENSE_SECRET'] ?? licenseSecret;

  int days;
  String label;
  final di = args.indexOf('--days');
  if (di >= 0 && di + 1 < args.length) {
    final d = int.parse(args[di + 1]);
    days = d;
    label = '$d يوم';
  } else {
    final months = args.length > 1 ? int.parse(args[1]) : 6;
    days = months * 30;
    label = '$months شهر';
  }

  final expiry = DateTime.now().add(Duration(days: days));
  final code = generateCodeUntil(device, expiry, secret: secret);

  stdout.writeln('رمز الجهاز : ${device.toUpperCase()}');
  stdout.writeln('المدة      : $label');
  stdout.writeln('ينتهي في   : ${expiry.toIso8601String().substring(0, 10)}');
  stdout.writeln('كود التفعيل: $code');
}
