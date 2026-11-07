// اختبار واجهات: يشغّل البرنامج ببيانات تجريبية ويتنقل بين الأقسام على مقاس موبايل وتابلت.
// يفشل إذا رمت أي شاشة استثناء أو ظهر خطأ تخطيط (overflow).
// لحفظ صور الشاشات: SCREENSHOTS=1 flutter test --update-goldens test/screens_test.dart
import 'dart:io';

import 'package:alarab/app.dart';
import 'package:alarab/core/widgets.dart';
import 'package:alarab/data/db.dart';
import 'package:alarab/data/models.dart';
import 'package:alarab/data/repos/debts_repo.dart';
import 'package:alarab/data/repos/lines_repo.dart';
import 'package:alarab/data/repos/products_repo.dart';
import 'package:alarab/data/repos/repairs_repo.dart';
import 'package:alarab/data/repos/sales_repo.dart';
import 'package:alarab/data/repos/settings_repo.dart';
import 'package:alarab/data/repos/users_repo.dart';
import 'package:alarab/features/shell/shell.dart';
import 'package:alarab/services/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarab/services/license.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final shots = Platform.environment['SCREENSHOTS'] == '1';

Future<void> _loadFonts() async {
  final tajawal = FontLoader('Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    tajawal.addFont(rootBundle.load('assets/fonts/Tajawal-$w.ttf'));
  }
  await tajawal.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await icons.load();
    }
  }
}

Future<void> _seedDemo() async {
  final admin = await UsersRepo.create('المدير', '1234', 'admin');
  await UsersRepo.create('حيدر', '1111', 'employee');
  Session.instance.login(admin);
  final cats = await ProductsRepo.categories();
  int cat(String icon) => cats.firstWhere((c) => c.icon == icon).id;
  final ids = <int>[];
  for (final p in [
    (const Product(id: 0, name: 'iPhone 13 128GB', brand: 'Apple', model: 'iPhone 13', storage: '128GB', color: 'أزرق', cost: 720000, price: 790000), 'phone', 3),
    (const Product(id: 0, name: 'Galaxy A15', brand: 'Samsung', model: 'A15', storage: '128GB', cost: 190000, price: 215000), 'phone', 5),
    (const Product(id: 0, name: 'سماعة بلوتوث JBL', brand: 'JBL', cost: 25000, price: 40000), 'headphones', 8),
    (const Product(id: 0, name: 'شاحن سامسونج 25W', brand: 'Samsung', cost: 9000, price: 15000, minQty: 3), 'charger', 2),
    (const Product(id: 0, name: 'لاصقة 9D A12', cost: 1000, price: 5000), 'shield', 40),
    (const Product(id: 0, name: 'كفر شفاف iPhone 13', cost: 2000, price: 7000), 'case', 15),
  ]) {
    ids.add(await ProductsRepo.create(p.$1.copyWithCategory(cat(p.$2)), p.$3));
  }
  final types = await LinesRepo.lineTypes();
  final red = types.firstWhere((t) => t.name == 'ريد');
  final yoz = types.firstWhere((t) => t.name == 'يوز');
  await LinesRepo.addService(yoz.id, 'يوز 10', 10000, 0);
  await LinesRepo.addService(yoz.id, 'يوز 20', 20000, 0);
  final reds = await LinesRepo.services(lineTypeId: red.id);
  for (var i = 0; i < 4; i++) {
    await LinesRepo.sell(type: red, service: reds[i % reds.length], amount: reds[i % reds.length].price, customerPhone: i == 0 ? '07701234567' : '');
  }
  final p1 = (await ProductsRepo.byId(ids[2]))!;
  final p2 = (await ProductsRepo.byId(ids[4]))!;
  await SalesRepo.checkout(cart: [CartLine(p1), CartLine(p2, qty: 2)]);
  final r = await RepairsRepo.create(const Repair(
      id: 0, number: 0, customerName: 'مصطفى كريم', customerPhone: '07801112233', deviceBrand: 'Apple', deviceModel: 'iPhone 11', issue: 'تبديل شاشة', receivedAt: 0, estimatedCost: 65000, deposit: 20000));
  await RepairsRepo.setStatus(r, RepairStatus.ready);
  await RepairsRepo.create(const Repair(
      id: 0, number: 0, customerName: 'زهراء علي', deviceBrand: 'Samsung', deviceModel: 'Galaxy A32', issue: 'منفذ الشحن', receivedAt: 0, estimatedCost: 15000));
  await DebtsRepo.add(name: 'أبو حسين', phone: '07709998877', type: 'بيع آجل', amount: 150000);
  final d = await DebtsRepo.add(name: 'سجاد', type: 'دين نقدي', amount: 50000);
  await DebtsRepo.pay(d, 20000);
}

extension on Product {
  Product copyWithCategory(int c) => Product(
      id: id, name: name, categoryId: c, brand: brand, model: model, storage: storage, color: color, cost: cost, price: price, minQty: minQty);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _loadFonts();
  });

  setUp(() async {
    Session.instance.logout();
    await AppDb.instance.close();
    await AppDb.instance.open(path: inMemoryDatabasePath);
    await SettingsRepo.instance.load();
    AdminGate.verifier = (pin) async => await UsersRepo.verifyAnyAdmin(pin) != null;
    SharedPreferences.setMockInitialValues({
      'lic_device_id': '7K2M9X4QAB12',
      'lic_expiry_ms': DateTime.now().add(const Duration(days: 120)).millisecondsSinceEpoch,
    });
    await LicenseService.instance.init();
  });

  tearDown(() async {
    await AppDb.instance.close();
  });

  for (final device in [('phone', const Size(1080, 2340), 2.75), ('tablet', const Size(2560, 1600), 2.0)]) {
    testWidgets('all sections render on ${device.$1}', (tester) async {
      tester.view.physicalSize = device.$2;
      tester.view.devicePixelRatio = device.$3;
      addTearDown(tester.view.reset);

      await tester.runAsync(_seedDemo);
      await tester.pumpWidget(const AlarabApp());
      // تحميل البيانات من قاعدة البيانات يحتاج runAsync
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 400));
        }
      }

      Future<void> shot(String name) async {
        await settle();
        if (shots) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${device.$1}_$name.png'));
        }
      }

      await shot('dashboard');
      for (final s in [Section.lines, Section.pos, Section.repairs, Section.inventory, Section.debts, Section.protectors, Section.invoices, Section.reports, Section.admin, Section.expenses]) {
        ShellNav.go(s);
        await shot(s.name);
      }

      // تبويب الخطوط المباعة
      ShellNav.go(Section.lines);
      await settle();
      await tester.tap(find.text('الخطوط المباعة'));
      await shot('lines_sold');

      // نافذة إضافة خط
      await tester.tap(find.text('إضافة خط مباع'));
      await settle();
      await tester.tap(find.text('ريد').last);
      await settle();
      await tester.tap(find.text('ريد 25').last);
      await shot('line_sheet');
      await tester.tapAt(const Offset(5, 5));
      await settle();

      // البحث في التوافقات
      ShellNav.go(Section.protectors);
      await settle();
      await tester.enterText(find.byType(TextField).first, 'A12');
      await shot('protectors_search');
      await tester.tap(find.text('ربط لاصقات المخزن بالتوافقات'));
      await shot('link_stock');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle();

      ShellNav.go(Section.dashboard);
      await settle();
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('trial banner on dashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({}); // أول تشغيل → يوم مجاني
    await tester.runAsync(() async {
      await LicenseService.instance.init();
      final a = await UsersRepo.create('المدير', '1234', 'admin');
      Session.instance.login(a);
    });
    await tester.pumpWidget(const AlarabApp());
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phone_trial.png'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('lock screen renders when not activated', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'lic_device_id': '7K2M9X4QAB12'}); // لا يوجد اشتراك
    await tester.runAsync(() async {
      await LicenseService.instance.init();
      await LicenseService.instance.debugReset(device: '7K2M9X4QAB12', expiry: 0);
      await SettingsRepo.instance.set('provider_contact', '0770 123 4567');
    });
    await tester.pumpWidget(const AlarabApp());
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('البرنامج غير مفعّل'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phone_lock.png'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('login screen renders', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => UsersRepo.create('المدير', '1234', 'admin'));
    await tester.pumpWidget(const AlarabApp());
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('أدخل الرمز السري'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/phone_login.png'));
    await tester.pump(const Duration(seconds: 3));
  });
}
