import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/products_repo.dart';
import '../../data/repos/sales_repo.dart';
import '../inventory/inventory_screen.dart';
import '../inventory/product_form.dart';
import '../invoices/receipt_actions.dart';
import 'cart.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  String _q = '';
  int? _cat;

  PosCart get cart => PosCart.instance;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(Product p) {
    if (cart.add(p)) {
      HapticFeedback.selectionClick();
    } else {
      toast(context, 'لا توجد كمية كافية من ${p.name}', error: true);
    }
  }

  /// دعم قارئ الباركود: الضغط على Enter بعد المسح يضيف المنتج مباشرة
  Future<void> _submitSearch(String v) async {
    final p = await ProductsRepo.byBarcode(v);
    if (p != null && mounted) {
      _add(p);
      _search.clear();
      setState(() => _q = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.w >= 900;
    final products = _ProductsPane(
      search: _search,
      q: _q,
      cat: _cat,
      onQuery: (v) => setState(() => _q = v),
      onSubmit: _submitSearch,
      onCat: (c) => setState(() => _cat = c),
      onAdd: _add,
    );
    if (wide) {
      return Row(children: [
        Expanded(child: products),
        Container(
          width: context.w >= 1200 ? 400 : 350,
          margin: const EdgeInsetsDirectional.fromSTEB(0, 4, 16, 16),
          child: AppCard(padding: EdgeInsets.zero, child: _CartPanel(onCheckout: () => _checkout(context))),
        ),
      ]);
    }
    return Stack(children: [
      Positioned.fill(child: products),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: ListenableBuilder(
          listenable: cart,
          builder: (c, _) => AnimatedSlide(
            offset: cart.isEmpty ? const Offset(0, 1.6) : Offset.zero,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: _CartBar(onTap: () => showAppSheet(context, _CartPanel(onCheckout: () {
                  Navigator.pop(context);
                  _checkout(context);
                }, sheet: true))),
          ),
        ),
      ),
    ]);
  }

  Future<void> _checkout(BuildContext context) async {
    if (cart.isEmpty) return;
    final inv = await showAppSheet<Invoice>(context, const _CheckoutSheet(), maxWidth: 560);
    if (inv != null && context.mounted) {
      await showInvoiceSuccess(context, inv);
    }
  }
}

class _ProductsPane extends StatelessWidget {
  final TextEditingController search;
  final String q;
  final int? cat;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSubmit;
  final ValueChanged<int?> onCat;
  final ValueChanged<Product> onAdd;
  const _ProductsPane({
    required this.search,
    required this.q,
    required this.cat,
    required this.onQuery,
    required this.onSubmit,
    required this.onCat,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DataView<(List<Product>, List<Category>)>(
      reloadKey: '$q-$cat',
      load: () async => (await ProductsRepo.search(query: q, categoryId: cat, inStockOnly: true), await ProductsRepo.categories()),
      builder: (context, d) {
        final (products, cats) = d;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(children: [
                TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onChanged: onQuery,
                  onSubmitted: onSubmit,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن منتج أو امسح الباركود...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'منتج جديد',
                      icon: const Icon(Icons.add_box_rounded),
                      onPressed: () => showProductForm(context, categoryId: cat),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('الكل'), selected: cat == null, onSelected: (_) => onCat(null)),
                    for (final c in cats) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(categoryIcon(c.icon), size: 18, color: c.c),
                        label: Text(c.name),
                        selected: cat == c.id,
                        selectedColor: c.c.withValues(alpha: .22),
                        onSelected: (_) => onCat(c.id),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.shopping_basket_outlined,
                title: q.isEmpty ? 'لا توجد منتجات متوفرة' : 'لا توجد نتائج',
                message: 'المنتجات المتوفرة بالمخزن تظهر هنا للبيع',
                action: FilledButton.icon(
                  onPressed: () => showProductForm(context, categoryId: cat),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة منتج'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, context.w >= 900 ? 16 : 100),
              sliver: ListenableBuilder(
                listenable: PosCart.instance,
                builder: (c, _) => SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230, mainAxisExtent: 172, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) {
                      final p = products[i];
                      final inCart = PosCart.instance.qtyOf(p.id);
                      return ProductCard(
                        product: p,
                        category: cats.where((x) => x.id == p.categoryId).firstOrNull,
                        onTap: () => onAdd(p),
                        badge: inCart == 0
                            ? null
                            : Padding(
                                padding: const EdgeInsetsDirectional.only(end: 6),
                                child: Pill('×$inCart', color: AppColors.gold, solid: true)
                                    .animate(key: ValueKey(inCart))
                                    .scaleXY(begin: 1.4, end: 1, curve: Curves.easeOutBack),
                              ),
                      ).stagger(i, step: 20);
                    },
                    childCount: products.length,
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _CartBar extends StatelessWidget {
  final VoidCallback onTap;
  const _CartBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cart = PosCart.instance;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFFF4DB97), AppColors.gold, Color(0xFFB08A3A)]),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Badge(
            label: Text('${cart.units}'),
            backgroundColor: AppColors.ink,
            child: const Icon(Icons.shopping_bag_rounded, color: AppColors.ink, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Text('عرض السلة وإتمام البيع', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 15))),
          Text(money(cart.total), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 17)),
        ]),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  final bool sheet;
  const _CartPanel({required this.onCheckout, this.sheet = false});

  @override
  Widget build(BuildContext context) {
    final cart = PosCart.instance;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final list = cart.lines.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: EmptyState(icon: Icons.shopping_bag_outlined, title: 'السلة فارغة', message: 'اضغط على أي منتج لإضافته'),
              )
            : ListView.separated(
                shrinkWrap: sheet,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: cart.lines.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (c, i) => _CartRow(line: cart.lines[i])
                    .animate(key: ValueKey(cart.lines[i].product.id))
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: -.1, end: 0),
              );
        return Column(mainAxisSize: sheet ? MainAxisSize.min : MainAxisSize.max, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              const Icon(Icons.shopping_bag_rounded),
              const SizedBox(width: 8),
              Text('السلة (${cart.units})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(context, 'إفراغ السلة؟', 'سيتم حذف كل المواد من السلة')) cart.clear();
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
                  label: const Text('إفراغ', style: TextStyle(color: AppColors.danger)),
                ),
            ]),
          ),
          if (sheet) Flexible(child: list) else Expanded(child: list),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + (sheet ? MediaQuery.paddingOf(context).bottom : 0)),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: context.cs.outline.withValues(alpha: .5)))),
            child: Column(children: [
              Row(children: [
                Text('المجموع', style: TextStyle(color: context.cs.onSurfaceVariant)),
                const Spacer(),
                Text(money(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Text('الإجمالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a), child: c)),
                  child: Text(money(cart.subtotal),
                      key: ValueKey(cart.subtotal),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.cs.primary)),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('إتمام البيع'),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartLine line;
  const _CartRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final cart = PosCart.instance;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          GestureDetector(
            onTap: () => _editPrice(context),
            child: Text('${money(line.price)} للقطعة ✎', style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
          ),
          Text(money(line.total), style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w800)),
        ]),
      ),
      _QtyButton(icon: Icons.remove_rounded, onTap: () => cart.setQty(line, line.qty - 1)),
      SizedBox(
        width: 36,
        child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      _QtyButton(
        icon: Icons.add_rounded,
        onTap: () {
          if (!cart.setQty(line, line.qty + 1)) toast(context, 'المتوفر ${line.product.qty} فقط', error: true);
        },
      ),
    ]);
  }

  Future<void> _editPrice(BuildContext context) async {
    final c = TextEditingController(text: numFmt(line.price));
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('سعر البيع لهذه العملية'),
        content: MoneyField(controller: c, label: 'السعر', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, parseMoney(c.text)), child: const Text('اعتماد')),
        ],
      ),
    );
    if (v != null && v > 0) PosCart.instance.setPrice(line, v);
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: context.cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20),
        ),
      );
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet();
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();
  String _payment = 'cash';
  bool _busy = false;

  PosCart get cart => PosCart.instance;
  int get _disc => parseMoney(_discount.text).clamp(0, cart.subtotal);
  int get _total => cart.subtotal - _disc;

  Future<void> _confirm() async {
    if (_payment == 'credit' && _name.text.trim().isEmpty) {
      toast(context, 'البيع بالآجل يحتاج اسم الزبون', error: true);
      return;
    }
    setState(() => _busy = true);
    final inv = await guard(
      context,
      () => SalesRepo.checkout(
        cart: List.of(cart.lines),
        discount: _disc,
        customerName: _name.text,
        customerPhone: _phone.text,
        payment: _payment,
        paidNow: parseMoney(_paid.text),
        note: _note.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (inv != null) {
      cart.clear();
      Navigator.pop(context, inv);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'إتمام البيع',
      icon: Icons.point_of_sale_rounded,
      footer: FilledButton.icon(
        onPressed: _busy ? null : _confirm,
        icon: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.check_circle_rounded),
        label: Text('تأكيد البيع • ${money(_total)}'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in cart.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text('${l.product.name} × ${l.qty}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(money(l.total)),
            ]),
          ),
        const Divider(height: 24),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'cash', label: Text('نقدي'), icon: Icon(Icons.payments_rounded)),
            ButtonSegment(value: 'credit', label: Text('آجل (دين)'), icon: Icon(Icons.schedule_rounded)),
          ],
          selected: {_payment},
          onSelectionChanged: (s) => setState(() => _payment = s.first),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: _payment == 'credit' ? 'اسم الزبون *' : 'اسم الزبون (اختياري)',
                prefixIcon: const Icon(Icons.person_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', prefixIcon: Icon(Icons.phone_rounded)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        MoneyField(controller: _discount, label: 'الخصم', onChanged: (_) => setState(() {})),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _payment != 'credit'
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MoneyField(controller: _paid, label: 'المدفوع الآن (والباقي يُسجل ديناً)', onChanged: (_) => setState(() {})),
                ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة على الفاتورة', prefixIcon: Icon(Icons.notes_rounded))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: context.cs.primary.withValues(alpha: .1),
            border: Border.all(color: context.cs.primary.withValues(alpha: .35)),
          ),
          child: Column(children: [
            if (_disc > 0) InfoRow('بعد الخصم', '${money(cart.subtotal)} − ${money(_disc)}'),
            Row(children: [
              const Text('الإجمالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(money(_total), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.cs.primary)),
            ]),
            if (_payment == 'credit')
              InfoRow('يُسجل ديناً', money((_total - parseMoney(_paid.text)).clamp(0, _total)), color: const Color(0xFFEC4899), bold: true),
          ]),
        ),
      ]),
    );
  }
}
