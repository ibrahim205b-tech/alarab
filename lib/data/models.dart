import 'package:flutter/material.dart';

int _i(Object? v) => v == null ? 0 : (v as num).toInt();
String _s(Object? v) => v?.toString() ?? '';
int? _ni(Object? v) => v == null ? null : (v as num).toInt();

class AppUser {
  final int id;
  final String name;
  final String role;
  final bool active;
  const AppUser({required this.id, required this.name, required this.role, this.active = true});
  bool get isAdmin => role == 'admin';
  String get roleLabel => isAdmin ? 'مدير' : 'موظف';
  factory AppUser.fromMap(Map<String, Object?> m) =>
      AppUser(id: _i(m['id']), name: _s(m['name']), role: _s(m['role']), active: _i(m['active']) == 1);
}

class Category {
  final int id;
  final String name;
  final String icon;
  final int color;
  const Category({required this.id, required this.name, required this.icon, required this.color});
  factory Category.fromMap(Map<String, Object?> m) =>
      Category(id: _i(m['id']), name: _s(m['name']), icon: _s(m['icon']), color: _i(m['color']));
  Color get c => Color(color);
}

class Product {
  final int id;
  final String name;
  final int? categoryId;
  final String brand, model, barcode, imei, color, storage, condition, notes, createdBy;
  final int cost, price, qty, minQty;
  final int? protectorGroupId;
  final int createdAt, updatedAt;
  const Product({
    required this.id,
    required this.name,
    this.categoryId,
    this.brand = '',
    this.model = '',
    this.barcode = '',
    this.imei = '',
    this.color = '',
    this.storage = '',
    this.condition = 'new',
    this.notes = '',
    this.createdBy = '',
    this.cost = 0,
    this.price = 0,
    this.qty = 0,
    this.minQty = 1,
    this.protectorGroupId,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  bool get lowStock => qty <= minQty;
  bool get outOfStock => qty <= 0;
  int get profit => price - cost;
  String get subtitle => [brand, model, storage, color].where((e) => e.trim().isNotEmpty).join(' • ');
  String get conditionLabel => condition == 'used' ? 'مستعمل' : 'جديد';

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: _i(m['id']),
        name: _s(m['name']),
        categoryId: _ni(m['category_id']),
        brand: _s(m['brand']),
        model: _s(m['model']),
        barcode: _s(m['barcode']),
        imei: _s(m['imei']),
        color: _s(m['color']),
        storage: _s(m['storage']),
        condition: _s(m['condition']).isEmpty ? 'new' : _s(m['condition']),
        notes: _s(m['notes']),
        createdBy: _s(m['created_by']),
        cost: _i(m['cost']),
        price: _i(m['price']),
        qty: _i(m['qty']),
        minQty: _i(m['min_qty']),
        protectorGroupId: _ni(m['protector_group_id']),
        createdAt: _i(m['created_at']),
        updatedAt: _i(m['updated_at']),
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'category_id': categoryId,
        'brand': brand,
        'model': model,
        'barcode': barcode,
        'imei': imei,
        'color': color,
        'storage': storage,
        'condition': condition,
        'notes': notes,
        'cost': cost,
        'price': price,
        'min_qty': minQty,
        'protector_group_id': protectorGroupId,
      };
}

class StockEntry {
  final int id, productId, change, qtyAfter, createdAt;
  final String reason, ref, note, userName;
  const StockEntry(this.id, this.productId, this.change, this.qtyAfter, this.reason, this.ref, this.note,
      this.userName, this.createdAt);
  factory StockEntry.fromMap(Map<String, Object?> m) => StockEntry(_i(m['id']), _i(m['product_id']),
      _i(m['change']), _i(m['qty_after']), _s(m['reason']), _s(m['ref']), _s(m['note']), _s(m['user_name']),
      _i(m['created_at']));

  String get reasonLabel => switch (reason) {
        'create' => 'إضافة المنتج',
        'restock' => 'إضافة كمية',
        'sale' => 'بيع',
        'void' => 'إلغاء فاتورة (إرجاع)',
        'adjust' => 'تعديل جرد (مدير)',
        'repair' => 'استخدام في صيانة',
        _ => reason,
      };
}

class Carrier {
  final int id;
  final String name;
  final int color;
  const Carrier(this.id, this.name, this.color);
  factory Carrier.fromMap(Map<String, Object?> m) => Carrier(_i(m['id']), _s(m['name']), _i(m['color']));
}

class LineType {
  final int id, carrierId, color;
  final String name, carrierName;
  final bool active;
  const LineType(this.id, this.carrierId, this.name, this.color, this.carrierName, this.active);
  factory LineType.fromMap(Map<String, Object?> m) => LineType(_i(m['id']), _i(m['carrier_id']), _s(m['name']),
      _i(m['color']), _s(m['carrier_name']), _i(m['active']) == 1);
}

class Service {
  final int id, lineTypeId, price, cost;
  final String name;
  final bool active;
  const Service(this.id, this.lineTypeId, this.name, this.price, this.cost, this.active);
  factory Service.fromMap(Map<String, Object?> m) =>
      Service(_i(m['id']), _i(m['line_type_id']), _s(m['name']), _i(m['price']), _i(m['cost']), _i(m['active']) == 1);
}

class InvoiceItem {
  final int id;
  final int? productId;
  final String name, detail;
  final int qty, price, cost;
  const InvoiceItem({this.id = 0, this.productId, required this.name, this.detail = '', this.qty = 1, required this.price, this.cost = 0});
  int get total => qty * price;
  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
      id: _i(m['id']),
      productId: _ni(m['product_id']),
      name: _s(m['name']),
      detail: _s(m['detail']),
      qty: _i(m['qty']),
      price: _i(m['price']),
      cost: _i(m['cost']));
}

enum InvoiceType { sale, line, repair, debtPay }

extension InvoiceTypeX on InvoiceType {
  String get key => switch (this) {
        InvoiceType.sale => 'sale',
        InvoiceType.line => 'line',
        InvoiceType.repair => 'repair',
        InvoiceType.debtPay => 'debt_pay',
      };
  String get label => switch (this) {
        InvoiceType.sale => 'بيع منتجات',
        InvoiceType.line => 'خطوط وخدمات',
        InvoiceType.repair => 'صيانة',
        InvoiceType.debtPay => 'تسديد دين',
      };
  String get prefix => switch (this) {
        InvoiceType.sale => 'S',
        InvoiceType.line => '#',
        InvoiceType.repair => 'R',
        InvoiceType.debtPay => 'D',
      };
  IconData get icon => switch (this) {
        InvoiceType.sale => Icons.shopping_bag_rounded,
        InvoiceType.line => Icons.sim_card_rounded,
        InvoiceType.repair => Icons.build_circle_rounded,
        InvoiceType.debtPay => Icons.payments_rounded,
      };
  Color get color => switch (this) {
        InvoiceType.sale => const Color(0xFF3E8BFF),
        InvoiceType.line => const Color(0xFFE5202E),
        InvoiceType.repair => const Color(0xFFF5A524),
        InvoiceType.debtPay => const Color(0xFF2FBF71),
      };
  static InvoiceType parse(String s) => InvoiceType.values.firstWhere((e) => e.key == s, orElse: () => InvoiceType.sale);
}

class Invoice {
  final int id, number, periodId;
  final InvoiceType type;
  final String customerName, customerPhone, payment, status, note, userName;
  final int subtotal, discount, total, paid, cost, createdAt;
  final int? refId, updatedAt;
  final List<InvoiceItem> items;
  const Invoice({
    required this.id,
    required this.type,
    required this.number,
    this.periodId = 0,
    this.customerName = '',
    this.customerPhone = '',
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.paid = 0,
    this.cost = 0,
    this.payment = 'cash',
    this.status = 'active',
    this.note = '',
    this.refId,
    this.userName = '',
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });
  bool get isVoid => status == 'void';
  String get code => type == InvoiceType.line ? '#$number' : '${type.prefix}-$number';
  int get remaining => total - paid;
  int get profit => total - cost;
  String get paymentLabel => payment == 'credit' ? 'آجل (دين)' : 'نقدي';

  factory Invoice.fromMap(Map<String, Object?> m, [List<InvoiceItem> items = const []]) => Invoice(
        id: _i(m['id']),
        type: InvoiceTypeX.parse(_s(m['type'])),
        number: _i(m['number']),
        periodId: _i(m['period_id']),
        customerName: _s(m['customer_name']),
        customerPhone: _s(m['customer_phone']),
        subtotal: _i(m['subtotal']),
        discount: _i(m['discount']),
        total: _i(m['total']),
        paid: _i(m['paid']),
        cost: _i(m['cost']),
        payment: _s(m['payment']),
        status: _s(m['status']),
        note: _s(m['note']),
        refId: _ni(m['ref_id']),
        userName: _s(m['user_name']),
        createdAt: _i(m['created_at']),
        updatedAt: _ni(m['updated_at']),
        items: items,
      );
}

class LineSale {
  final int id, number, periodId, amount, cost, createdAt;
  final int? invoiceId, lineTypeId, serviceId;
  final String carrierName, lineTypeName, serviceName, customerPhone, status, userName;
  const LineSale({
    required this.id,
    required this.number,
    this.periodId = 0,
    this.invoiceId,
    required this.carrierName,
    this.lineTypeId,
    required this.lineTypeName,
    this.serviceId,
    required this.serviceName,
    required this.amount,
    this.cost = 0,
    this.customerPhone = '',
    this.status = 'active',
    this.userName = '',
    required this.createdAt,
  });
  bool get isVoid => status == 'void';
  factory LineSale.fromMap(Map<String, Object?> m) => LineSale(
        id: _i(m['id']),
        number: _i(m['number']),
        periodId: _i(m['period_id']),
        invoiceId: _ni(m['invoice_id']),
        carrierName: _s(m['carrier_name']),
        lineTypeId: _ni(m['line_type_id']),
        lineTypeName: _s(m['line_type_name']),
        serviceId: _ni(m['service_id']),
        serviceName: _s(m['service_name']),
        amount: _i(m['amount']),
        cost: _i(m['cost']),
        customerPhone: _s(m['customer_phone']),
        status: _s(m['status']),
        userName: _s(m['user_name']),
        createdAt: _i(m['created_at']),
      );
}

enum RepairStatus { received, inProgress, waitingParts, ready, delivered, unfixable }

extension RepairStatusX on RepairStatus {
  String get key => switch (this) {
        RepairStatus.received => 'received',
        RepairStatus.inProgress => 'in_progress',
        RepairStatus.waitingParts => 'waiting_parts',
        RepairStatus.ready => 'ready',
        RepairStatus.delivered => 'delivered',
        RepairStatus.unfixable => 'unfixable',
      };
  String get label => switch (this) {
        RepairStatus.received => 'مستلم',
        RepairStatus.inProgress => 'قيد الصيانة',
        RepairStatus.waitingParts => 'بانتظار قطعة',
        RepairStatus.ready => 'جاهز للتسليم',
        RepairStatus.delivered => 'تم التسليم',
        RepairStatus.unfixable => 'تعذر الإصلاح',
      };
  Color get color => switch (this) {
        RepairStatus.received => const Color(0xFF3E8BFF),
        RepairStatus.inProgress => const Color(0xFFF5A524),
        RepairStatus.waitingParts => const Color(0xFF8B5CF6),
        RepairStatus.ready => const Color(0xFF2FBF71),
        RepairStatus.delivered => const Color(0xFF64748B),
        RepairStatus.unfixable => const Color(0xFFE5484D),
      };
  IconData get icon => switch (this) {
        RepairStatus.received => Icons.move_to_inbox_rounded,
        RepairStatus.inProgress => Icons.handyman_rounded,
        RepairStatus.waitingParts => Icons.hourglass_top_rounded,
        RepairStatus.ready => Icons.check_circle_rounded,
        RepairStatus.delivered => Icons.handshake_rounded,
        RepairStatus.unfixable => Icons.report_rounded,
      };
  bool get isOpen => this != RepairStatus.delivered;
  static RepairStatus parse(String s) =>
      RepairStatus.values.firstWhere((e) => e.key == s, orElse: () => RepairStatus.received);
}

class Repair {
  final int id, number;
  final String customerName, customerPhone, deviceBrand, deviceModel, imei, issue, devicePassword, accessories,
      conditionNotes, techNotes, userName;
  final int estimatedCost, deposit, finalCost, partsCost, receivedAt;
  final int? expectedAt, readyAt, deliveredAt, invoiceId;
  final RepairStatus status;
  const Repair({
    required this.id,
    required this.number,
    required this.customerName,
    this.customerPhone = '',
    this.deviceBrand = '',
    required this.deviceModel,
    this.imei = '',
    required this.issue,
    this.devicePassword = '',
    this.accessories = '',
    this.conditionNotes = '',
    this.techNotes = '',
    this.userName = '',
    this.estimatedCost = 0,
    this.deposit = 0,
    this.finalCost = 0,
    this.partsCost = 0,
    required this.receivedAt,
    this.expectedAt,
    this.readyAt,
    this.deliveredAt,
    this.invoiceId,
    this.status = RepairStatus.received,
  });
  String get code => 'R-$number';
  String get device => [deviceBrand, deviceModel].where((e) => e.trim().isNotEmpty).join(' ');

  factory Repair.fromMap(Map<String, Object?> m) => Repair(
        id: _i(m['id']),
        number: _i(m['number']),
        customerName: _s(m['customer_name']),
        customerPhone: _s(m['customer_phone']),
        deviceBrand: _s(m['device_brand']),
        deviceModel: _s(m['device_model']),
        imei: _s(m['imei']),
        issue: _s(m['issue']),
        devicePassword: _s(m['device_password']),
        accessories: _s(m['accessories']),
        conditionNotes: _s(m['condition_notes']),
        techNotes: _s(m['tech_notes']),
        userName: _s(m['user_name']),
        estimatedCost: _i(m['estimated_cost']),
        deposit: _i(m['deposit']),
        finalCost: _i(m['final_cost']),
        partsCost: _i(m['parts_cost']),
        receivedAt: _i(m['received_at']),
        expectedAt: _ni(m['expected_at']),
        readyAt: _ni(m['ready_at']),
        deliveredAt: _ni(m['delivered_at']),
        invoiceId: _ni(m['invoice_id']),
        status: RepairStatusX.parse(_s(m['status'])),
      );

  Map<String, Object?> toEditableMap() => {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'device_brand': deviceBrand,
        'device_model': deviceModel,
        'imei': imei,
        'issue': issue,
        'device_password': devicePassword,
        'accessories': accessories,
        'condition_notes': conditionNotes,
        'estimated_cost': estimatedCost,
        'deposit': deposit,
        'expected_at': expectedAt,
      };
}

class RepairLogEntry {
  final RepairStatus status;
  final String note, userName;
  final int createdAt;
  const RepairLogEntry(this.status, this.note, this.userName, this.createdAt);
  factory RepairLogEntry.fromMap(Map<String, Object?> m) =>
      RepairLogEntry(RepairStatusX.parse(_s(m['status'])), _s(m['note']), _s(m['user_name']), _i(m['created_at']));
}

const debtTypes = [
  'دين نقدي',
  'بيع آجل',
  'طلب جهاز',
  'طلب إكسسوار',
  'رصيد / كارت',
  'صيانة',
  'أخرى',
];

class Debt {
  final int id, amount, paid, createdAt;
  final int? closedAt, invoiceId;
  final String customerName, customerPhone, debtType, note, status, userName;
  const Debt({
    required this.id,
    required this.customerName,
    this.customerPhone = '',
    required this.debtType,
    required this.amount,
    this.paid = 0,
    this.note = '',
    this.status = 'open',
    this.userName = '',
    required this.createdAt,
    this.closedAt,
    this.invoiceId,
  });
  int get remaining => amount - paid;
  bool get isClosed => status == 'closed' || remaining <= 0;
  double get progress => amount == 0 ? 1 : (paid / amount).clamp(0, 1).toDouble();
  factory Debt.fromMap(Map<String, Object?> m) => Debt(
        id: _i(m['id']),
        customerName: _s(m['customer_name']),
        customerPhone: _s(m['customer_phone']),
        debtType: _s(m['debt_type']),
        amount: _i(m['amount']),
        paid: _i(m['paid']),
        note: _s(m['note']),
        status: _s(m['status']),
        userName: _s(m['user_name']),
        createdAt: _i(m['created_at']),
        closedAt: _ni(m['closed_at']),
        invoiceId: _ni(m['invoice_id']),
      );
}

class DebtPayment {
  final int id, debtId, amount, createdAt;
  final String note, userName;
  const DebtPayment(this.id, this.debtId, this.amount, this.note, this.userName, this.createdAt);
  factory DebtPayment.fromMap(Map<String, Object?> m) => DebtPayment(
      _i(m['id']), _i(m['debt_id']), _i(m['amount']), _s(m['note']), _s(m['user_name']), _i(m['created_at']));
}

const expenseCategories = [
  'إيجار',
  'كهرباء / مولدة',
  'إنترنت',
  'رواتب',
  'بضاعة',
  'قطع غيار صيانة',
  'نقل',
  'ضيافة',
  'أخرى',
];

class Expense {
  final int id, amount, createdAt;
  final String category, note, userName;
  const Expense(this.id, this.category, this.amount, this.note, this.userName, this.createdAt);
  factory Expense.fromMap(Map<String, Object?> m) =>
      Expense(_i(m['id']), _s(m['category']), _i(m['amount']), _s(m['note']), _s(m['user_name']), _i(m['created_at']));
}

class ProtectorModel {
  final int id, groupId;
  final String brand, model;
  const ProtectorModel(this.id, this.groupId, this.brand, this.model);
  String get full => model.toLowerCase().startsWith(brand.toLowerCase()) ? model : '$brand $model';
  factory ProtectorModel.fromMap(Map<String, Object?> m) =>
      ProtectorModel(_i(m['id']), _i(m['group_id']), _s(m['brand']), _s(m['model']));
}

class ProtectorGroup {
  final int id;
  final String name, size, notes;
  final bool builtin;
  final List<ProtectorModel> models;
  final int stock;
  const ProtectorGroup(this.id, this.name, this.size, this.notes, this.builtin, this.models, {this.stock = 0});
}

class ActivityEntry {
  final int id, createdAt;
  final String userName, action, details;
  const ActivityEntry(this.id, this.userName, this.action, this.details, this.createdAt);
  factory ActivityEntry.fromMap(Map<String, Object?> m) =>
      ActivityEntry(_i(m['id']), _s(m['user_name']), _s(m['action']), _s(m['details']), _i(m['created_at']));
}
