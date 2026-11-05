import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/repos/sales_repo.dart';

/// سلة نقطة البيع (مشتركة حتى يمكن الإضافة إليها من المخزن)
class PosCart extends ChangeNotifier {
  PosCart._();
  static final PosCart instance = PosCart._();

  final List<CartLine> lines = [];
  int discount = 0;

  int get subtotal => lines.fold(0, (s, l) => s + l.total);
  int get total => (subtotal - discount).clamp(0, subtotal);
  int get units => lines.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => lines.isEmpty;

  int qtyOf(int productId) => lines.where((l) => l.product.id == productId).fold(0, (s, l) => s + l.qty);

  /// يعيد false إذا لا توجد كمية كافية
  bool add(Product p) {
    final existing = lines.where((l) => l.product.id == p.id).firstOrNull;
    if ((existing?.qty ?? 0) + 1 > p.qty) return false;
    if (existing != null) {
      existing.qty++;
    } else {
      lines.add(CartLine(p));
    }
    notifyListeners();
    return true;
  }

  /// وضع عدد محدد للمنتج في السلة (مثلاً 100 قطعة مرة واحدة)
  bool putQty(Product p, int qty) {
    if (qty > p.qty) return false;
    final existing = lines.where((l) => l.product.id == p.id).firstOrNull;
    if (qty <= 0) {
      if (existing != null) lines.remove(existing);
    } else if (existing != null) {
      existing.qty = qty;
    } else {
      lines.add(CartLine(p, qty: qty));
    }
    if (discount > subtotal) discount = subtotal;
    notifyListeners();
    return true;
  }

  bool setQty(CartLine l, int qty) {
    if (qty > l.product.qty) return false;
    if (qty <= 0) {
      lines.remove(l);
    } else {
      l.qty = qty;
    }
    if (discount > subtotal) discount = subtotal;
    notifyListeners();
    return true;
  }

  void setPrice(CartLine l, int price) {
    l.price = price;
    notifyListeners();
  }

  void setDiscount(int d) {
    discount = d.clamp(0, subtotal);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    discount = 0;
    notifyListeners();
  }
}
