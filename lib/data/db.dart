import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/format.dart';
import 'protector_seed.dart';

/// قاعدة البيانات المحلية — كل البيانات تُحفظ على الجهاز وتعمل بدون إنترنت.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const version = 1;
  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database not opened');
    return d;
  }

  bool get isOpen => _db != null;

  Future<void> open({String? path}) async {
    if (_db != null) return;
    final dbPath = path ?? p.join(await getDatabasesPath(), 'alarab.db');
    _db = await openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        final b = db.batch();
        for (final s in schema) {
          b.execute(s);
        }
        await b.commit(noResult: true);
        await seed(db);
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// جداول تُصدَّر في النسخة الاحتياطية (بالترتيب المناسب للاستعادة)
  static const tables = [
    'settings', 'users', 'categories', 'products', 'stock_log',
    'carriers', 'line_types', 'services',
    'invoices', 'invoice_items', 'line_sales',
    'repairs', 'repair_log', 'debts', 'debt_payments', 'expenses',
    'protector_groups', 'protector_models', 'periods', 'activity_log', 'telegram_outbox',
  ];

  static const schema = [
    '''CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)''',
    '''CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      pin_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'employee',
      active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'box',
      color INTEGER NOT NULL DEFAULT 0,
      sort INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category_id INTEGER,
      brand TEXT DEFAULT '',
      model TEXT DEFAULT '',
      barcode TEXT DEFAULT '',
      imei TEXT DEFAULT '',
      color TEXT DEFAULT '',
      storage TEXT DEFAULT '',
      condition TEXT DEFAULT 'new',
      cost INTEGER NOT NULL DEFAULT 0,
      price INTEGER NOT NULL DEFAULT 0,
      qty INTEGER NOT NULL DEFAULT 0,
      min_qty INTEGER NOT NULL DEFAULT 1,
      protector_group_id INTEGER,
      notes TEXT DEFAULT '',
      active INTEGER NOT NULL DEFAULT 1,
      created_by TEXT DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL)''',
    'CREATE INDEX idx_products_cat ON products(category_id)',
    'CREATE INDEX idx_products_barcode ON products(barcode)',
    '''CREATE TABLE stock_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      change INTEGER NOT NULL,
      qty_after INTEGER NOT NULL,
      reason TEXT NOT NULL,
      ref TEXT DEFAULT '',
      note TEXT DEFAULT '',
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    'CREATE INDEX idx_stock_log_p ON stock_log(product_id)',
    '''CREATE TABLE carriers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      color INTEGER NOT NULL,
      sort INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE line_types(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carrier_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      color INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      sort INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE services(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      line_type_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      price INTEGER NOT NULL DEFAULT 0,
      cost INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1,
      sort INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE invoices(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      number INTEGER NOT NULL,
      period_id INTEGER NOT NULL,
      customer_name TEXT DEFAULT '',
      customer_phone TEXT DEFAULT '',
      subtotal INTEGER NOT NULL DEFAULT 0,
      discount INTEGER NOT NULL DEFAULT 0,
      total INTEGER NOT NULL DEFAULT 0,
      paid INTEGER NOT NULL DEFAULT 0,
      cost INTEGER NOT NULL DEFAULT 0,
      payment TEXT NOT NULL DEFAULT 'cash',
      status TEXT NOT NULL DEFAULT 'active',
      note TEXT DEFAULT '',
      ref_id INTEGER,
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER)''',
    'CREATE INDEX idx_invoices_date ON invoices(created_at)',
    'CREATE INDEX idx_invoices_type ON invoices(type)',
    '''CREATE TABLE invoice_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
      product_id INTEGER,
      name TEXT NOT NULL,
      detail TEXT DEFAULT '',
      qty INTEGER NOT NULL DEFAULT 1,
      price INTEGER NOT NULL DEFAULT 0,
      cost INTEGER NOT NULL DEFAULT 0)''',
    'CREATE INDEX idx_items_inv ON invoice_items(invoice_id)',
    '''CREATE TABLE line_sales(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      number INTEGER NOT NULL,
      period_id INTEGER NOT NULL,
      invoice_id INTEGER,
      carrier_name TEXT NOT NULL,
      line_type_id INTEGER,
      line_type_name TEXT NOT NULL,
      service_id INTEGER,
      service_name TEXT NOT NULL,
      amount INTEGER NOT NULL,
      cost INTEGER NOT NULL DEFAULT 0,
      customer_phone TEXT DEFAULT '',
      status TEXT NOT NULL DEFAULT 'active',
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    'CREATE INDEX idx_line_sales_date ON line_sales(created_at)',
    '''CREATE TABLE repairs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      number INTEGER NOT NULL,
      customer_name TEXT NOT NULL,
      customer_phone TEXT DEFAULT '',
      device_brand TEXT DEFAULT '',
      device_model TEXT NOT NULL,
      imei TEXT DEFAULT '',
      issue TEXT NOT NULL,
      device_password TEXT DEFAULT '',
      accessories TEXT DEFAULT '',
      condition_notes TEXT DEFAULT '',
      estimated_cost INTEGER NOT NULL DEFAULT 0,
      deposit INTEGER NOT NULL DEFAULT 0,
      final_cost INTEGER NOT NULL DEFAULT 0,
      parts_cost INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'received',
      tech_notes TEXT DEFAULT '',
      expected_at INTEGER,
      received_at INTEGER NOT NULL,
      ready_at INTEGER,
      delivered_at INTEGER,
      invoice_id INTEGER,
      user_name TEXT DEFAULT '')''',
    'CREATE INDEX idx_repairs_status ON repairs(status)',
    '''CREATE TABLE repair_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      repair_id INTEGER NOT NULL REFERENCES repairs(id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      note TEXT DEFAULT '',
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE debts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_name TEXT NOT NULL,
      customer_phone TEXT DEFAULT '',
      debt_type TEXT NOT NULL,
      amount INTEGER NOT NULL,
      paid INTEGER NOT NULL DEFAULT 0,
      note TEXT DEFAULT '',
      status TEXT NOT NULL DEFAULT 'open',
      invoice_id INTEGER,
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL,
      closed_at INTEGER)''',
    '''CREATE TABLE debt_payments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL,
      note TEXT DEFAULT '',
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE expenses(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      amount INTEGER NOT NULL,
      note TEXT DEFAULT '',
      user_name TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE protector_groups(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      size TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      builtin INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE protector_models(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL REFERENCES protector_groups(id) ON DELETE CASCADE,
      brand TEXT NOT NULL,
      model TEXT NOT NULL,
      search_key TEXT NOT NULL)''',
    'CREATE INDEX idx_pm_group ON protector_models(group_id)',
    '''CREATE TABLE periods(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at INTEGER NOT NULL,
      closed_at INTEGER,
      closed_by TEXT DEFAULT '',
      summary TEXT DEFAULT '')''',
    '''CREATE TABLE activity_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_name TEXT DEFAULT '',
      action TEXT NOT NULL,
      details TEXT DEFAULT '',
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE telegram_outbox(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL)''',
  ];

  static Future<void> seed(DatabaseExecutor db) async {
    final now = nowMs();
    await db.insert('periods', {'started_at': now});

    const cats = [
      ['هواتف', 'phone', 0xFF3E8BFF],
      ['إكسسوارات', 'headphones', 0xFF8B5CF6],
      ['شواحن وكيبلات', 'charger', 0xFF14B8A6],
      ['لاصقات حماية', 'shield', 0xFFD9B25F],
      ['كفرات', 'case', 0xFFEC4899],
      ['قطع غيار', 'chip', 0xFFF5A524],
      ['كارتات رصيد', 'card', 0xFFE5202E],
      ['أخرى', 'box', 0xFF64748B],
    ];
    for (var i = 0; i < cats.length; i++) {
      await db.insert('categories', {'name': cats[i][0], 'icon': cats[i][1], 'color': cats[i][2], 'sort': i});
    }

    // شركات الاتصال وأنواع الخطوط والخدمات (قابلة للتعديل من الإدارة)
    final asia = await db.insert('carriers', {'name': 'آسياسيل', 'color': 0xFFE5202E, 'sort': 0});
    await db.insert('carriers', {'name': 'زين العراق', 'color': 0xFF7B2D8E, 'sort': 1});
    // خدمات "ريد" كما طلبها صاحب المحل، وبقية الأنواع تُضاف خدماتها وأسعارها من الإدارة
    final types = {
      'ريد': [0xFFE5202E, [15000, 25000, 30000]],
      'يوز': [0xFF3E8BFF, <int>[]],
      'كفو': [0xFF2FBF71, <int>[]],
    };
    var ti = 0;
    for (final e in types.entries) {
      final tid = await db.insert('line_types', {
        'carrier_id': asia,
        'name': e.key,
        'color': e.value[0] as int,
        'sort': ti++,
      });
      final prices = e.value[1] as List<int>;
      for (var i = 0; i < prices.length; i++) {
        await db.insert('services', {
          'line_type_id': tid,
          'name': '${e.key} ${prices[i] ~/ 1000}',
          'price': prices[i],
          'sort': i,
        });
      }
    }

    await seedProtectors(db);

    const settings = {
      'shop_name': 'مبيعات علي العراب',
      'shop_phone': '',
      'shop_address': 'العراق',
      'receipt_footer': 'شكراً لتعاملكم معنا ❤',
      'repair_terms': 'المحل غير مسؤول عن الأجهزة المتروكة أكثر من 30 يوماً بعد إشعار الجاهزية.\nيرجى الاحتفاظ بهذا الوصل لاستلام الجهاز.',
      'counter_sale': '0',
      'counter_line': '0',
      'counter_repair': '0',
      'counter_debt_pay': '0',
      'printer_mode': 'none',
      'paper_width': '58',
      'auto_print': '0',
      'tg_enabled': '0',
      'tg_token': '',
      'tg_chat': '',
      'tg_ev_sale': '1',
      'tg_ev_line': '1',
      'tg_ev_repair': '1',
      'tg_ev_debt': '1',
      'tg_ev_expense': '1',
      'theme': 'dark',
    };
    for (final e in settings.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value});
    }
  }

  static Future<void> seedProtectors(DatabaseExecutor db) async {
    for (final g in protectorSeed) {
      final gid = await db.insert('protector_groups', {
        'name': g.name,
        'size': g.size,
        'notes': g.notes,
        'builtin': 1,
      });
      for (final m in g.models) {
        await db.insert('protector_models', {
          'group_id': gid,
          'brand': m.$1,
          'model': m.$2,
          'search_key': protectorKey('${m.$1} ${m.$2}'),
        });
      }
    }
  }
}

/// مفتاح بحث موحّد لأسماء الأجهزة: حروف صغيرة بدون فراغات أو رموز
String protectorKey(String s) {
  var t = normalizeAr(s);
  const map = {
    'سامسونج': 'samsung', 'سامسونك': 'samsung', 'ايفون': 'iphone', 'آيفون': 'iphone',
    'شاومي': 'xiaomi', 'ريدمي': 'redmi', 'بوكو': 'poco', 'اوبو': 'oppo', 'ريلمي': 'realme',
    'هواوي': 'huawei', 'هونر': 'honor', 'انفنكس': 'infinix', 'تكنو': 'tecno', 'فيفو': 'vivo',
    'برو': 'pro', 'ماكس': 'max', 'بلس': 'plus', 'الترا': 'ultra', 'نوت': 'note', 'لايت': 'lite',
    'جالكسي': '', 'كلاكسي': '', 'galaxy': '',
  };
  map.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll('+', 'plus');
  return t.replaceAll(RegExp(r'[^a-z0-9؀-ۿ]'), '');
}
