// يلتقط صور الخطوات التفصيلية لفيديو الشرح (لا يعمل في CI).
// التشغيل: TUT=1 flutter test --update-goldens test/tutorial_capture_test.dart
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
import 'package:alarab/services/license.dart';
import 'package:alarab/services/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final on = Platform.environment['TUT'] == '1';

Future<void> _fonts() async {
  final t = FontLoader('Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    t.addFont(rootBundle.load('assets/fonts/Tajawal-$w.ttf'));
  }
  await t.load();
  final f = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
}

Product _p(String name, int cat, int cost, int price, {String brand = '', String model = '', String storage = '', int min = 1}) =>
    Product(id: 0, name: name, categoryId: cat, brand: brand, model: model, storage: storage, cost: cost, price: price, minQty: min);

Future<void> _seed({bool withData = true}) async {
  await SettingsRepo.instance.setMany({'shop_name': 'محل النور للموبايلات', 'shop_phone': '0770 000 0000', 'shop_address': 'بغداد'});
  final a = await UsersRepo.create('المدير', '1234', 'admin');
  Session.instance.login(a);
  if (!withData) return;
  final cats = await ProductsRepo.categories();
  int c(String i) => cats.firstWhere((x) => x.icon == i).id;
  final ids = <int>[];
  for (final p in [
    _p('iPhone 13 128GB', c('phone'), 720000, 790000, brand: 'Apple', model: 'iPhone 13', storage: '128GB'),
    _p('Galaxy A15', c('phone'), 190000, 215000, brand: 'Samsung', model: 'A15'),
    _p('سماعة بلوتوث JBL', c('headphones'), 25000, 40000),
    _p('شاحن سامسونج 25W', c('charger'), 9000, 15000, min: 3),
    _p('لاصقة 9D سامسونج A12', c('shield'), 1000, 5000),
  ]) {
    ids.add(await ProductsRepo.create(p, 12));
  }
  final types = await LinesRepo.lineTypes();
  final red = types.firstWhere((t) => t.name == 'ريد');
  final s = (await LinesRepo.services(lineTypeId: red.id)).first;
  await LinesRepo.sell(type: red, service: s, amount: s.price);
  await SalesRepo.checkout(cart: [CartLine((await ProductsRepo.byId(ids[2]))!)]);
  final r = await RepairsRepo.create(const Repair(id: 0, number: 0, customerName: 'مصطفى', customerPhone: '07801112233', deviceBrand: 'Apple', deviceModel: 'iPhone 11', issue: 'تبديل شاشة', estimatedCost: 65000, deposit: 20000, receivedAt: 0));
  await RepairsRepo.setStatus(r, RepairStatus.ready);
  final d = await DebtsRepo.add(name: 'أبو حسين', phone: '07709998877', type: 'بيع آجل', amount: 150000);
  await DebtsRepo.pay(d, 50000);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _fonts();
  });

  setUp(() async {
    Session.instance.logout();
    await AppDb.instance.close();
    await AppDb.instance.open(path: inMemoryDatabasePath);
    await SettingsRepo.instance.load();
    AdminGate.verifier = (pin) async => await UsersRepo.verifyAnyAdmin(pin) != null;
    SharedPreferences.setMockInitialValues({
      'lic_device_id': '7K2M9X4QAB12',
      'lic_trial_used': true,
      'lic_is_trial': false,
      'lic_expiry_ms': DateTime.now().add(const Duration(days: 120)).millisecondsSinceEpoch,
    });
    await LicenseService.instance.init();
  });
  tearDown(() => AppDb.instance.close());

  Future<void> settle(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 380));
    }
  }

  Future<void> snap(WidgetTester t, String name) async {
    await settle(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tut/$name.png'));
  }

  Future<void> tap(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return;
    await t.ensureVisible(last ? f.last : f.first);
    await t.pump(const Duration(milliseconds: 250));
    await t.tap(last ? f.last : f.first, warnIfMissed: false);
    await settle(t, 4);
  }

  Future<void> tapFab(WidgetTester t, String label) async {
    final f = find.widgetWithText(FloatingActionButton, label);
    if (f.evaluate().isEmpty) return;
    await t.tap(f.first, warnIfMissed: false);
    await settle(t, 4);
  }

  Future<void> tapContains(WidgetTester t, String text) async {
    final f = find.textContaining(text);
    if (f.evaluate().isEmpty) return;
    await t.tap(f.first, warnIfMissed: false);
    await settle(t, 4);
  }

  Future<void> type(WidgetTester t, Finder f, String s) async {
    try {
      if (f.evaluate().isEmpty) return;
    } catch (_) {
      return;
    }
    await t.enterText(f.first, s);
    await t.pump(const Duration(milliseconds: 200));
  }

  void pop(WidgetTester t) {
    final n = t.state<NavigatorState>(find.byType(Navigator).first);
    if (n.canPop()) n.pop();
  }

  Future<void> closeAll(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      final n = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!n.canPop()) break;
      n.pop();
      await settle(t, 3);
    }
  }

  testWidgets('setup screen', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(const AlarabApp());
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'اسم المحل'), 'محل النور للموبايلات');
    await t.enterText(find.widgetWithText(TextFormField, 'اسمك (المدير)'), 'أحمد');
    await snap(t, 'u01_setup');
    await t.pump(const Duration(seconds: 2));
  }, skip: !on);

  testWidgets('all how-to steps', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.runAsync(_seed);
    await t.pumpWidget(const AlarabApp());
    await settle(t);

    // ===== إضافة قسم =====
    ShellNav.go(Section.admin);
    await settle(t);
    await tap(t, 'أقسام المخزن');
    await snap(t, 'u10_categories');
    await tap(t, 'قسم جديد');
    await type(t, find.byType(TextField), 'ساعات ذكية');
    await snap(t, 'u11_category_add');
    pop(t);
    await settle(t);

    // ===== إضافة منتج =====
    ShellNav.go(Section.inventory);
    await tap(t, 'إضافة منتج');
    await tap(t, 'هواتف', last: true);
    await type(t, find.widgetWithText(TextFormField, 'اسم المنتج *'), 'Galaxy S24');
    await type(t, find.widgetWithText(TextFormField, 'سعر البيع *'), '450000');
    await snap(t, 'u12_product_add');
    pop(t);
    await settle(t);

    // ===== إضافة كمية =====
    await t.enterText(find.byType(TextField).first, 'iPhone 13 128');
    await settle(t, 4);
    await tap(t, 'iPhone 13 128GB', last: true);
    await tap(t, 'إضافة كمية');
    await snap(t, 'u13_restock');
    pop(t);
    await settle(t);
    pop(t);
    await settle(t);

    // ===== الخطوط والخدمات (الإدارة) =====
    await closeAll(t);
    ShellNav.go(Section.admin);
    await settle(t);
    await tap(t, 'الخطوط والخدمات');
    await snap(t, 'u14_catalog');
    await t.ensureVisible(find.text('إضافة خدمة لـ يوز').first);
    await settle(t, 2);
    await tap(t, 'إضافة خدمة لـ يوز');
    await type(t, find.byType(TextField), 'يوز 15');
    final priceField = find.widgetWithText(TextFormField, 'سعر البيع');
    await type(t, priceField, '15000');
    await snap(t, 'u15_service_add');
    pop(t);
    await settle(t);

    // ===== تسجيل دين =====
    await tap(t, 'دين');
    await type(t, find.widgetWithText(TextFormField, 'اسم الشخص'), 'حسين علي');
    await type(t, find.widgetWithText(TextFormField, 'رقم الهاتف'), '07701234567');
    await tap(t, 'طلب جهاز');
    await type(t, find.widgetWithText(TextFormField, 'المبلغ المطلوب من الزبون'), '300000');
    await snap(t, 'u20_debt_add');
    pop(t);
    await settle(t);

    // ===== تسديد دين =====
    ShellNav.go(Section.debts);
    await settle(t);
    await tap(t, 'أبو حسين');
    await tap(t, 'تسجيل دفعة / تسديد');
    await snap(t, 'u21_debt_pay');
    pop(t);
    await settle(t);
    pop(t);
    await settle(t);

    // ===== استلام جهاز صيانة =====
    await closeAll(t);
    ShellNav.go(Section.repairs);
    await settle(t);
    await tapFab(t, 'استلام جهاز');
    await type(t, find.widgetWithText(TextFormField, 'اسم الزبون *'), 'زينب كريم');
    await type(t, find.widgetWithText(TextFormField, 'رقم الهاتف'), '07801112233');
    await tap(t, 'Samsung');
    await type(t, find.widgetWithText(TextFormField, 'الموديل *'), 'Galaxy A32');
    await tap(t, 'منفذ الشحن');
    await snap(t, 'u30_repair_add');
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -700));
    await settle(t, 3);
    await snap(t, 'u31_repair_cost');
    pop(t);
    await settle(t);

    // ===== تسليم الجهاز والتواصل =====
    await closeAll(t);
    ShellNav.go(Section.repairs);
    await settle(t);
    await tapContains(t, 'iPhone 11');
    await snap(t, 'u32_repair_contact');
    await tap(t, 'تسليم للزبون');
    await snap(t, 'u33_repair_deliver');
    pop(t);
    await settle(t);
    pop(t);
    await settle(t);

    // ===== مصروف =====
    await closeAll(t);
    ShellNav.go(Section.expenses);
    await settle(t);
    await tapFab(t, 'مصروف جديد');
    await tap(t, 'كهرباء / مولدة');
    await type(t, find.byType(TextField), '75000');
    await snap(t, 'u40_expense_add');
    pop(t);
    await settle(t);

    // ===== مستخدم جديد =====
    await closeAll(t);
    ShellNav.go(Section.admin);
    await settle(t);
    await tap(t, 'المستخدمون');
    await settle(t, 3);
    await tapFab(t, 'مستخدم جديد');
    await type(t, find.widgetWithText(TextField, 'الاسم'), 'حيدر');
    await snap(t, 'u50_user_add');
    pop(t);
    await settle(t);
    pop(t);
    await settle(t);

    // ===== تصفير الوردية =====
    ShellNav.go(Section.dashboard);
    await settle(t);
    await tap(t, 'تصفير الوردية');
    await snap(t, 'u60_shift_reset');
    pop(t);
    await settle(t);

    // ===== تحديد العدد في نقطة البيع =====
    ShellNav.go(Section.pos);
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'JBL');
    await settle(t, 3);
    await tap(t, 'عدد', last: true);
    await snap(t, 'u61_quantity');
    pop(t);
    await settle(t);

    await t.pump(const Duration(seconds: 2));
  }, skip: !on);
}
