// يلتقط صور شاشات البرنامج الحقيقية لفيديو الترويج (لا يعمل في CI).
// التشغيل: PROMO=1 flutter test --update-goldens test/promo_capture_test.dart
import 'dart:io';

import 'package:alarab/app.dart';
import 'package:alarab/core/widgets.dart';
import 'package:alarab/data/db.dart';
import 'package:alarab/data/models.dart';
import 'package:alarab/data/repos/base.dart' as base;
import 'package:alarab/data/repos/debts_repo.dart';
import 'package:alarab/data/repos/expenses_repo.dart';
import 'package:alarab/data/repos/lines_repo.dart';
import 'package:alarab/data/repos/products_repo.dart';
import 'package:alarab/data/repos/protectors_repo.dart';
import 'package:alarab/data/repos/repairs_repo.dart';
import 'package:alarab/data/repos/sales_repo.dart';
import 'package:alarab/data/repos/settings_repo.dart';
import 'package:alarab/data/repos/users_repo.dart';
import 'package:alarab/features/shell/shell.dart';
import 'package:alarab/services/receipt.dart';
import 'package:alarab/services/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarab/services/license.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final enabled = Platform.environment['PROMO'] == '1';

Future<void> _fonts() async {
  final t = FontLoader('Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    t.addFont(rootBundle.load('assets/fonts/Tajawal-$w.ttf'));
  }
  await t.load();
  final f = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
}

Product _p(String name, int cat, int cost, int price, {String brand = '', String model = '', String storage = '', String color = '', String imei = '', int min = 1, int? group}) =>
    Product(id: 0, name: name, categoryId: cat, brand: brand, model: model, storage: storage, color: color, imei: imei, cost: cost, price: price, minQty: min, protectorGroupId: group);

Future<int> _admin() async {
  await SettingsRepo.instance.setMany({'shop_name': 'محل الهاتف الذكي', 'shop_phone': '0770 000 0000', 'shop_address': 'بغداد - شارع الصناعة'});
  final a = await UsersRepo.create('المدير', '1234', 'admin');
  await UsersRepo.create('الموظف', '1111', 'employee');
  Session.instance.login(a);
  return a.id;
}

Future<void> _seed() async {
  final cats = await ProductsRepo.categories();
  int c(String icon) => cats.firstWhere((x) => x.icon == icon).id;
  final groups = await ProtectorsRepo.groups();
  final gA12 = groups.firstWhere((g) => g.name.contains('A12')).id;
  final gIp = groups.firstWhere((g) => g.name.contains('12 / 13 / 14')).id;

  final items = [
    (_p('iPhone 13 128GB', c('phone'), 720000, 790000, brand: 'Apple', model: 'iPhone 13', storage: '128GB', color: 'أزرق', imei: '356789104455661'), 3),
    (_p('Galaxy A15', c('phone'), 190000, 215000, brand: 'Samsung', model: 'A15', storage: '128GB', color: 'أسود'), 6),
    (_p('Redmi Note 13', c('phone'), 230000, 260000, brand: 'Xiaomi', model: 'Note 13', storage: '256GB'), 4),
    (_p('سماعة بلوتوث JBL', c('headphones'), 25000, 40000, brand: 'JBL'), 8),
    (_p('ايربودز برو', c('headphones'), 30000, 50000), 5),
    (_p('شاحن سامسونج 25W', c('charger'), 9000, 15000, brand: 'Samsung', min: 3), 2),
    (_p('كيبل Type-C', c('charger'), 2000, 5000, min: 5), 30),
    (_p('لاصقة 9D سامسونج A12', c('shield'), 1000, 5000, group: gA12), 40),
    (_p('لاصقة 9D ايفون 13', c('shield'), 1000, 5000, group: gIp), 25),
    (_p('كفر شفاف iPhone 13', c('case'), 2000, 7000), 15),
    (_p('شاشة iPhone 11 أصلية', c('chip'), 45000, 0 + 65000), 2),
  ];
  final ids = <int>[];
  for (final i in items) {
    ids.add(await ProductsRepo.create(i.$1, i.$2));
  }

  // كتالوج الخطوط
  final types = await LinesRepo.lineTypes();
  final yoz = types.firstWhere((t) => t.name == 'يوز');
  final kfo = types.firstWhere((t) => t.name == 'كفو');
  await LinesRepo.addService(yoz.id, 'يوز 10', 10000, 0);
  await LinesRepo.addService(yoz.id, 'يوز 20', 20000, 0);
  await LinesRepo.addService(kfo.id, 'كفو 15', 15000, 0);
  await LinesRepo.addService(kfo.id, 'كفو 25', 25000, 0);
  final carriers = await LinesRepo.carriers();
  final zain = carriers.firstWhere((x) => x.name.contains('زين'));
  final ztype = await LinesRepo.addLineType(zain.id, 'زين باقات', 0xFF7B2D8E);
  await LinesRepo.addService(ztype, 'باقة 15', 15000, 0);
  await LinesRepo.addService(ztype, 'باقة 30', 30000, 0);

  final allTypes = await LinesRepo.lineTypes();
  final allServices = await LinesRepo.services();
  // مبيعات موزعة على آخر 7 أيام
  final now = DateTime.now();
  final plan = [3, 5, 4, 7, 6, 8, 5];
  for (var d = 0; d < 7; d++) {
    for (var k = 0; k < plan[d]; k++) {
      final t = allTypes[(d + k) % allTypes.length];
      final svcs = allServices.where((s) => s.lineTypeId == t.id).toList();
      if (svcs.isEmpty) continue;
      final s = svcs[k % svcs.length];
      final (_, inv) = await LinesRepo.sell(type: t, service: s, amount: s.price);
      final when = DateTime(now.year, now.month, now.day, 10 + k, 5 * k).subtract(Duration(days: 6 - d));
      if (d < 6) {
        await base.db.update('invoices', {'created_at': when.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [inv.id]);
        await base.db.update('line_sales', {'created_at': when.millisecondsSinceEpoch}, where: 'invoice_id = ?', whereArgs: [inv.id]);
      }
    }
    if (d % 2 == 0) {
      final p = (await ProductsRepo.byId(ids[3 + d % 4]))!;
      final inv = await SalesRepo.checkout(cart: [CartLine(p)]);
      final when = now.subtract(Duration(days: 6 - d, hours: 2));
      if (d < 6) await base.db.update('invoices', {'created_at': when.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [inv.id]);
    }
  }
  final ph = (await ProductsRepo.byId(ids[1]))!;
  await SalesRepo.checkout(cart: [CartLine(ph), CartLine((await ProductsRepo.byId(ids[7]))!)], customerName: 'حسين');

  // الصيانة
  final r1 = await RepairsRepo.create(const Repair(id: 0, number: 0, customerName: 'مصطفى', customerPhone: '07801112233', deviceBrand: 'Apple', deviceModel: 'iPhone 11', imei: '353912110045879', issue: 'تبديل شاشة', accessories: 'كفر', estimatedCost: 65000, deposit: 20000, receivedAt: 0));
  await RepairsRepo.setStatus(r1, RepairStatus.inProgress, note: 'تم فحص الجهاز');
  await RepairsRepo.addNote((await RepairsRepo.get(r1.id))!, 'تم طلب شاشة أصلية');
  await RepairsRepo.setStatus((await RepairsRepo.get(r1.id))!, RepairStatus.ready);
  await RepairsRepo.create(const Repair(id: 0, number: 0, customerName: 'زينب', deviceBrand: 'Samsung', deviceModel: 'Galaxy A32', issue: 'منفذ الشحن', estimatedCost: 15000, receivedAt: 0));
  final r3 = await RepairsRepo.create(const Repair(id: 0, number: 0, customerName: 'كرار', customerPhone: '07709876543', deviceBrand: 'Xiaomi', deviceModel: 'Redmi Note 10', issue: 'تبديل بطارية', estimatedCost: 25000, receivedAt: 0));
  await RepairsRepo.setStatus(r3, RepairStatus.inProgress);
  final r4 = await RepairsRepo.create(const Repair(id: 0, number: 0, customerName: 'علياء', deviceBrand: 'Huawei', deviceModel: 'Y9 2019', issue: 'سقط بالماء', estimatedCost: 40000, receivedAt: 0));
  await RepairsRepo.setStatus(r4, RepairStatus.waitingParts);

  // ديون
  await DebtsRepo.add(name: 'أبو حسين', phone: '07709998877', type: 'بيع آجل', amount: 150000, note: 'باقي سعر موبايل');
  final d = await DebtsRepo.add(name: 'سجاد', type: 'دين نقدي', amount: 50000);
  await DebtsRepo.pay(d, 20000);
  await DebtsRepo.add(name: 'محمد', phone: '07501234567', type: 'طلب جهاز', amount: 300000, note: 'حجز iPhone 13');
  final d2 = await DebtsRepo.add(name: 'رسول', type: 'رصيد / كارت', amount: 25000);
  await DebtsRepo.pay(d2, 25000);

  await ExpensesRepo.add('كهرباء / مولدة', 75000, 'اشتراك المولدة');
  await ExpensesRepo.add('إنترنت', 35000, '');
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
      'lic_expiry_ms': DateTime.now().add(const Duration(days: 120)).millisecondsSinceEpoch,
    });
    await LicenseService.instance.init();
  });
  tearDown(() => AppDb.instance.close());

  Future<void> settle(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> snap(WidgetTester t, String name) async {
    await settle(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/promo/$name.png'));
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    await t.ensureVisible(last ? f.last : f.first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(last ? f.last : f.first, warnIfMissed: false);
    await settle(t, 4);
  }

  Future<void> closeSheet(WidgetTester t) async {
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t, 4);
  }

  testWidgets('promo phone', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    debugDisableShadows = false;

    await t.runAsync(() async {
      await _admin();
      await _seed();
      Session.instance.logout();
    });
    await t.pumpWidget(const AlarabApp());
    await settle(t);
    // تسجيل الدخول
    await tapText(t, 'المدير');
    await snap(t, 'p01_login');
    for (final d in ['1', '2', '3', '4']) {
      await t.tap(find.text(d).last);
      await t.pump(const Duration(milliseconds: 150));
    }
    await settle(t);
    await snap(t, 'p02_dashboard');
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await snap(t, 'p03_dashboard_chart');

    // الخطوط
    ShellNav.go(Section.lines);
    await snap(t, 'p04_lines_services');
    await tapText(t, 'إضافة خط مباع');
    await snap(t, 'p05_line_sheet_empty');
    await tapText(t, 'ريد', last: true);
    await snap(t, 'p06_line_sheet_type');
    await tapText(t, 'ريد 25', last: true);
    await snap(t, 'p07_line_sheet_service');
    await tapText(t, 'تأكيد البيع • 25,000 د.ع');
    await t.pump(const Duration(milliseconds: 1200));
    await snap(t, 'p08_line_success');
    await tapText(t, 'تم');
    await tapText(t, 'الخطوط المباعة');
    await snap(t, 'p09_lines_sold');

    // نقطة البيع
    ShellNav.go(Section.pos);
    await settle(t);
    Future<void> addByName(String q, String name, [int times = 1]) async {
      await t.enterText(find.byType(TextField).first, q);
      await settle(t, 4);
      for (var i = 0; i < times; i++) {
        await tapText(t, name);
      }
    }
    await addByName('Galaxy', 'Galaxy A15');
    await addByName('JBL', 'سماعة بلوتوث JBL');
    await addByName('A12', 'لاصقة 9D سامسونج A12', 2);
    await t.enterText(find.byType(TextField).first, '');
    await settle(t, 4);
    await snap(t, 'p10_pos');
    await tapText(t, 'عرض السلة وإتمام البيع');
    await snap(t, 'p11_cart');
    await tapText(t, 'إتمام البيع', last: true);
    await snap(t, 'p12_checkout');
    await tapText(t, 'آجل (دين)');
    await snap(t, 'p13_checkout_credit');
    await closeSheet(t);

    // الصيانة
    ShellNav.go(Section.repairs);
    await snap(t, 'p14_repairs');
    await tapText(t, 'Apple iPhone 11');
    await snap(t, 'p15_repair_details');
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -1400));
    await snap(t, 'p16_repair_timeline');
    await closeSheet(t);
    await tapText(t, 'استلام جهاز');
    await snap(t, 'p17_repair_form');
    await closeSheet(t);

    // المخزن
    ShellNav.go(Section.inventory);
    await snap(t, 'p18_inventory');
    await t.enterText(find.byType(TextField).first, 'iPhone 13 128');
    await settle(t, 4);
    await tapText(t, 'iPhone 13 128GB', last: true);
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -900));
    await snap(t, 'p19_product_details');
    await closeSheet(t);
    await t.enterText(find.byType(TextField).first, '');
    await settle(t, 4);
    await tapText(t, 'إضافة منتج');
    await tapText(t, 'هواتف', last: true);
    await snap(t, 'p20_product_form');
    await closeSheet(t);

    // الديون
    ShellNav.go(Section.debts);
    await snap(t, 'p21_debts');
    await tapText(t, 'دين');
    await snap(t, 'p22_debt_sheet');
    await closeSheet(t);
    await t.enterText(find.byType(TextField).first, 'سجاد');
    await settle(t, 4);
    await tapText(t, 'سجاد', last: true);
    await snap(t, 'p23_debt_details');
    await closeSheet(t);

    // التوافقات
    ShellNav.go(Section.protectors);
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'A12');
    await snap(t, 'p24_protectors_a12');
    await t.enterText(find.byType(TextField).first, 'ايفون 13');
    await snap(t, 'p25_protectors_iphone');

    // الفواتير والتقارير والإدارة
    ShellNav.go(Section.invoices);
    await snap(t, 'p26_invoices');
    ShellNav.go(Section.reports);
    await snap(t, 'p27_reports');
    await t.drag(find.byType(ListView).first, const Offset(0, -1100));
    await snap(t, 'p28_reports_more');
    ShellNav.go(Section.expenses);
    await snap(t, 'p29_expenses');
    ShellNav.go(Section.admin);
    await snap(t, 'p30_admin');
    await tapText(t, 'بوت تليجرام');
    await snap(t, 'p31_telegram');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);
    await tapText(t, 'الطابعة');
    await tapText(t, 'بلوتوث حرارية');
    await snap(t, 'p32_printer');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);
    await tapText(t, 'الخطوط والخدمات');
    await snap(t, 'p33_catalog');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);
    await tapText(t, 'المستخدمون');
    await snap(t, 'p34_users');
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);

    // الوضع الفاتح
    await t.runAsync(() => SettingsRepo.instance.set('theme', 'light'));
    ThemeController.instance.toggle();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.runAsync(() => SettingsRepo.instance.set('theme', 'light'));
    ShellNav.go(Section.dashboard);
    await settle(t);
    await snap(t, 'p35_light_dashboard');
    await t.runAsync(() => SettingsRepo.instance.set('theme', 'dark'));
    await t.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
  }, skip: !enabled);

  test('promo receipt', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _admin();
    final inv = Invoice(
      id: 1, type: InvoiceType.line, number: 39, customerPhone: '0770 123 4567', subtotal: 25000, total: 25000, paid: 25000,
      userName: 'الموظف', createdAt: DateTime.now().millisecondsSinceEpoch,
      items: const [InvoiceItem(name: 'ريد 25', detail: 'آسياسيل — ريد', price: 25000)],
    );
    File('test/goldens/promo/receipt_line.pdf').writeAsBytesSync(await ReceiptBuilder.invoice(inv, paper: 58));
    final sale = Invoice(
      id: 2, type: InvoiceType.sale, number: 14, customerName: 'حسين', subtotal: 270000, discount: 5000, total: 265000, paid: 265000,
      userName: 'الموظف', createdAt: DateTime.now().millisecondsSinceEpoch,
      items: const [
        InvoiceItem(name: 'Galaxy A15', detail: 'Samsung • A15 • 128GB', price: 215000),
        InvoiceItem(name: 'سماعة بلوتوث JBL', price: 40000),
        InvoiceItem(name: 'لاصقة 9D سامسونج A12', qty: 2, price: 5000),
      ],
    );
    File('test/goldens/promo/receipt_sale.pdf').writeAsBytesSync(await ReceiptBuilder.invoice(sale, paper: 58));
  }, skip: !enabled);

  testWidgets('promo tablet', (t) async {
    t.view.physicalSize = const Size(2560, 1600);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    debugDisableShadows = false;
    await t.runAsync(() async {
      final id = await _admin();
      await _seed();
      Session.instance.login((await UsersRepo.all()).firstWhere((u) => u.id == id));
    });
    await t.pumpWidget(const AlarabApp());
    await settle(t);
    await snap(t, 't01_dashboard');
    ShellNav.go(Section.pos);
    await settle(t);
    for (final q in ['iPhone 13 128GB', 'كفر شفاف iPhone 13', 'لاصقة 9D ايفون 13']) {
      await t.enterText(find.byType(TextField).first, q);
      await settle(t, 4);
      await tapText(t, q, last: true);
    }
    await t.enterText(find.byType(TextField).first, '');
    await snap(t, 't02_pos');
    ShellNav.go(Section.repairs);
    await snap(t, 't03_repairs');
    ShellNav.go(Section.lines);
    await snap(t, 't04_lines');
    ShellNav.go(Section.dashboard);
    await t.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
  }, skip: !enabled);
}

