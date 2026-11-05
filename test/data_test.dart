import 'package:alarab/data/db.dart';
import 'package:alarab/data/models.dart';
import 'package:alarab/data/repos/debts_repo.dart';
import 'package:alarab/data/repos/expenses_repo.dart';
import 'package:alarab/data/repos/lines_repo.dart';
import 'package:alarab/data/repos/products_repo.dart';
import 'package:alarab/data/repos/protectors_repo.dart';
import 'package:alarab/data/repos/repairs_repo.dart';
import 'package:alarab/data/repos/reports_repo.dart';
import 'package:alarab/data/repos/sales_repo.dart';
import 'package:alarab/data/repos/settings_repo.dart';
import 'package:alarab/data/repos/users_repo.dart';
import 'package:alarab/services/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDb.instance.close();
    await AppDb.instance.open(path: inMemoryDatabasePath);
    await SettingsRepo.instance.load();
    final admin = await UsersRepo.create('علي', '1234', 'admin');
    Session.instance.login(admin);
  });

  tearDown(() => AppDb.instance.close());

  test('seed creates catalog, categories and protector groups', () async {
    final types = await LinesRepo.lineTypes();
    expect(types.map((t) => t.name), containsAll(['ريد', 'يوز', 'كفو']));
    final red = types.firstWhere((t) => t.name == 'ريد');
    final services = await LinesRepo.services(lineTypeId: red.id);
    expect(services.map((s) => s.name), ['ريد 15', 'ريد 25', 'ريد 30']);
    expect((await ProductsRepo.categories()).length, greaterThan(5));
    expect((await ProtectorsRepo.groups()).length, greaterThan(30));
  });

  test('line sales get sequential numbers and reset after month close', () async {
    final red = (await LinesRepo.lineTypes()).firstWhere((t) => t.name == 'ريد');
    final s15 = (await LinesRepo.services(lineTypeId: red.id)).first;
    final (a, invA) = await LinesRepo.sell(type: red, service: s15, amount: 15000);
    final (b, _) = await LinesRepo.sell(type: red, service: s15, amount: 15000);
    expect(a.number, 1);
    expect(b.number, 2);
    expect(invA.code, '#1');

    final today = startOfToday();
    var s = await ReportsRepo.summary(today, today.add(const Duration(days: 1)));
    expect(s.byType[InvoiceType.line]!.total, 30000);

    await ReportsRepo.closePeriod();
    final (c, _) = await LinesRepo.sell(type: red, service: s15, amount: 15000);
    expect(c.number, 1);
    // old records are kept
    expect((await LinesRepo.sales()).length, 3);

    await LinesRepo.deleteSale(c);
    s = await ReportsRepo.summary(today, today.add(const Duration(days: 1)));
    expect(s.byType[InvoiceType.line]!.total, 30000);
  });

  test('POS checkout decrements stock, void restores it, credit creates debt', () async {
    final pid = await ProductsRepo.create(
        const Product(id: 0, name: 'شاحن سامسونج', cost: 5000, price: 10000, minQty: 2), 5);
    final p = (await ProductsRepo.byId(pid))!;
    final inv = await SalesRepo.checkout(cart: [CartLine(p, qty: 2)], discount: 1000);
    expect(inv.total, 19000);
    expect(inv.code, 'S-1');
    expect((await ProductsRepo.byId(pid))!.qty, 3);

    await expectLater(SalesRepo.checkout(cart: [CartLine(p, qty: 10)]), throwsException);

    await SalesRepo.voidInvoice(inv, 'خطأ');
    expect((await ProductsRepo.byId(pid))!.qty, 5);
    expect((await ProductsRepo.history(pid)).length, 3);

    final credit = await SalesRepo.checkout(
        cart: [CartLine(p)], payment: 'credit', paidNow: 4000, customerName: 'حسين');
    final debts = await DebtsRepo.list(open: true);
    expect(debts.single.remaining, 6000);
    expect(credit.remaining, 6000);
  });

  test('debt payment closes debt and voiding payment reopens it', () async {
    final d = await DebtsRepo.add(name: 'أحمد', phone: '0770', type: 'دين نقدي', amount: 50000);
    final inv = await DebtsRepo.pay(d, 20000);
    var cur = (await DebtsRepo.get(d.id))!;
    expect(cur.remaining, 30000);
    await expectLater(DebtsRepo.pay(cur, 40000), throwsException);
    await DebtsRepo.pay(cur, 30000);
    cur = (await DebtsRepo.get(d.id))!;
    expect(cur.isClosed, true);
    await SalesRepo.voidInvoice(inv, 'تجربة');
    cur = (await DebtsRepo.get(d.id))!;
    expect(cur.remaining, 20000);
    expect(cur.isClosed, false);
  });

  test('repair workflow: receive, ready, deliver creates invoice', () async {
    final r = await RepairsRepo.create(const Repair(
        id: 0, number: 0, customerName: 'زينب', deviceModel: 'iPhone 11', issue: 'تبديل شاشة', receivedAt: 0, deposit: 10000));
    expect(r.code, 'R-1');
    await RepairsRepo.setStatus(r, RepairStatus.ready);
    final inv = await RepairsRepo.deliver((await RepairsRepo.get(r.id))!, finalCost: 60000, partsCost: 35000);
    expect(inv.profit, 25000);
    expect((await RepairsRepo.get(r.id))!.status, RepairStatus.delivered);
    expect((await RepairsRepo.history(r.id)).length, 3);
  });

  test('protector search is precise', () async {
    final all = await ProtectorsRepo.groups();
    final r1 = ProtectorsRepo.search(all, 'iphone 13');
    expect(r1.first.exact, true);
    expect(r1.first.group.models.map((m) => m.model), contains('iPhone 14'));
    final r2 = ProtectorsRepo.search(all, 'A12');
    expect(r2.first.exact, true);
    expect(r2.first.group.models.map((m) => m.model), contains('Galaxy A32 5G'));
    final r3 = ProtectorsRepo.search(all, 'سامسونج a50');
    expect(r3.first.exact, true);
    expect(r3.first.group.models.map((m) => m.model), contains('Galaxy A30'));
    final r4 = ProtectorsRepo.search(all, 'ريدمي نوت 10 برو');
    expect(r4.first.exact, true);
    expect(r4.first.group.models.map((m) => m.model), contains('Poco X4 Pro 5G'));
  });

  test('shift reset zeroes sales, received and expenses but keeps records', () async {
    final red = (await LinesRepo.lineTypes()).firstWhere((t) => t.name == 'ريد');
    final s15 = (await LinesRepo.services(lineTypeId: red.id)).first;
    await LinesRepo.sell(type: red, service: s15, amount: 15000);
    await ExpensesRepo.add('إنترنت', 5000, '');
    final d = await DebtsRepo.add(name: 'أحمد', type: 'دين نقدي', amount: 20000);
    await DebtsRepo.pay(d, 8000);

    var s = await ReportsRepo.shiftSummary();
    expect(s.revenue, 15000);
    expect(s.received, 23000);
    expect(s.expenses, 5000);
    expect(s.cash, 18000);

    await Future.delayed(const Duration(milliseconds: 5));
    await ReportsRepo.closePeriod();
    await Future.delayed(const Duration(milliseconds: 5));
    s = await ReportsRepo.shiftSummary();
    expect(s.revenue, 0);
    expect(s.received, 0);
    expect(s.expenses, 0);
    expect(s.cash, 0);

    final (sale, _) = await LinesRepo.sell(type: red, service: s15, amount: 15000);
    expect(sale.number, 1);
    expect((await ReportsRepo.shiftSummary()).revenue, 15000);
    // السجلات القديمة باقية والدين المتبقي لم يتأثر
    expect((await LinesRepo.sales()).length, 2);
    expect((await DebtsRepo.get(d.id))!.remaining, 12000);
    expect((await ReportsRepo.closedPeriods()).length, 1);
  });

  test('partial return restocks and reduces invoice; duplicate barcode rejected', () async {
    final pid = await ProductsRepo.create(
        const Product(id: 0, name: 'سماعة انكر', barcode: '6901234567890', cost: 6000, price: 10000), 100);
    await expectLater(
        ProductsRepo.create(const Product(id: 0, name: 'نسخة', barcode: '6901234567890', price: 1), 1), throwsException);
    final p = (await ProductsRepo.byId(pid))!;
    final inv = await SalesRepo.checkout(cart: [CartLine(p, qty: 100)]);
    expect((await ProductsRepo.byId(pid))!.qty, 0);
    final after = await SalesRepo.returnItem(inv, inv.items.isNotEmpty ? (await SalesRepo.get(inv.id))!.items.first : inv.items.first, 30);
    expect(after.total, 700000);
    expect(after.cost, 420000);
    expect(after.items.single.qty, 70);
    expect((await ProductsRepo.byId(pid))!.qty, 30);
    // إرجاع الباقي يلغي الفاتورة
    final last = await SalesRepo.returnItem(after, after.items.single, 70);
    expect(last.isVoid, true);
    expect((await ProductsRepo.byId(pid))!.qty, 100);
  });

  test('cannot remove last admin', () async {
    final admin = (await UsersRepo.all()).single;
    await expectLater(UsersRepo.update(admin.id, active: false), throwsException);
    expect(await UsersRepo.verifyAnyAdmin('1234'), isNotNull);
    expect(await UsersRepo.verifyAnyAdmin('0000'), isNull);
  });
}

DateTime startOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
