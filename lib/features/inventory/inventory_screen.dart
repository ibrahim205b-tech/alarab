import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/products_repo.dart';
import '../../services/session.dart';
import '../pos/cart.dart';
import '../shell/shell.dart';
import 'product_form.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int? _cat;
  String _q = '';
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inv-fab',
        onPressed: () => showProductForm(context, categoryId: _cat),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة منتج'),
      ).animate().scaleXY(begin: 0, end: 1, delay: 200.ms, curve: Curves.easeOutBack),
      body: DataView<(List<Product>, List<Category>, (int, int, int, int, int))>(
        reloadKey: '$_cat-$_q-$_lowOnly',
        load: () async => (
          await ProductsRepo.search(query: _q, categoryId: _cat, lowOnly: _lowOnly),
          await ProductsRepo.categories(),
          await ProductsRepo.stats(),
        ),
        builder: (context, d) {
          final (products, cats, (count, units, costValue, saleValue, low)) = d;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: 84,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      _Stat('الأصناف', numFmt(count), Icons.category_rounded, AppColors.purple),
                      _Stat('القطع', numFmt(units), Icons.inventory_rounded, AppColors.info),
                      if (Session.instance.isAdmin) _Stat('قيمة المخزن (كلفة)', money(costValue), Icons.savings_rounded, AppColors.gold),
                      if (Session.instance.isAdmin) _Stat('قيمة البيع', money(saleValue), Icons.sell_rounded, AppColors.success),
                      _Stat('نواقص', numFmt(low), Icons.warning_amber_rounded, AppColors.danger, onTap: () => setState(() => _lowOnly = !_lowOnly), active: _lowOnly),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SearchField(hint: 'بحث بالاسم، الموديل، IMEI أو الباركود...', onChanged: (v) => setState(() => _q = v)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      ChoiceChip(label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                      for (final c in cats) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: Icon(categoryIcon(c.icon), size: 18, color: c.c),
                          label: Text(c.name),
                          selected: _cat == c.id,
                          selectedColor: c.c.withValues(alpha: .22),
                          onSelected: (_) => setState(() => _cat = c.id),
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
                  icon: Icons.inventory_2_outlined,
                  title: _q.isNotEmpty || _lowOnly ? 'لا توجد نتائج' : 'المخزن فارغ',
                  message: 'أضف منتجاتك ليتم تسجيل كل قطعة في المحل',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 172,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => ProductCard(
                      product: products[i],
                      category: cats.where((x) => x.id == products[i].categoryId).firstOrNull,
                      onTap: () => showProductDetails(context, products[i].id),
                    ).stagger(i, step: 25),
                    childCount: products.length,
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool active;
  const _Stat(this.label, this.value, this.icon, this.color, {this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: AppCard(
          onTap: onTap,
          borderColor: active ? color : null,
          color: active ? color.withValues(alpha: .12) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 40),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      );
}

class ProductCard extends StatelessWidget {
  final Product product;
  final Category? category;
  final VoidCallback onTap;
  final Widget? badge;
  const ProductCard({super.key, required this.product, this.category, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final color = category?.c ?? AppColors.gold;
    final qtyColor = p.outOfStock ? AppColors.danger : (p.lowStock ? AppColors.warning : AppColors.success);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(icon: categoryIcon(category?.icon ?? 'box'), color: color, size: 42),
          const Spacer(),
          ?badge,
          Pill('${p.qty}', color: qtyColor, icon: Icons.inventory_2_rounded),
        ]),
        const SizedBox(height: 10),
        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
        const SizedBox(height: 2),
        Text(p.subtitle.isEmpty ? (category?.name ?? '') : p.subtitle,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12)),
        const Spacer(),
        Row(children: [
          Expanded(
            child: FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: Text(money(p.price), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.cs.primary)),
            ),
          ),
          if (p.condition == 'used') const Pill('مستعمل', color: AppColors.info),
        ]),
      ]),
    );
  }
}

Future<void> showProductDetails(BuildContext context, int productId) =>
    showAppSheet(context, _ProductDetails(productId: productId), maxWidth: 680);

class _ProductDetails extends StatelessWidget {
  final int productId;
  const _ProductDetails({required this.productId});

  @override
  Widget build(BuildContext context) {
    return DataView<(Product?, List<StockEntry>)>(
      load: () async => (await ProductsRepo.byId(productId), await ProductsRepo.history(productId)),
      builder: (context, d) {
        final (p, log) = d;
        if (p == null) return const EmptyState(icon: Icons.delete_outline, title: 'المنتج غير موجود');
        final admin = Session.instance.isAdmin;
        return SheetScaffold(
          title: p.name,
          icon: Icons.inventory_2_rounded,
          footer: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: p.outOfStock
                    ? null
                    : () {
                        PosCart.instance.add(p);
                        Navigator.pop(context);
                        ShellNav.go(Section.pos);
                      },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('بيع'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _restock(context, p),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('إضافة كمية'),
              ),
            ),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _Big('الكمية', '${p.qty}', p.lowStock ? AppColors.warning : AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _Big('سعر البيع', money(p.price), context.cs.primary)),
              if (admin) ...[
                const SizedBox(width: 10),
                Expanded(child: _Big('الربح/قطعة', money(p.profit), AppColors.teal)),
              ],
            ]),
            const SizedBox(height: 12),
            if (p.brand.isNotEmpty) InfoRow('الماركة', p.brand, icon: Icons.business_rounded),
            if (p.model.isNotEmpty) InfoRow('الموديل', p.model, icon: Icons.devices_rounded),
            if (p.storage.isNotEmpty) InfoRow('السعة', p.storage, icon: Icons.sd_storage_rounded),
            if (p.color.isNotEmpty) InfoRow('اللون', p.color, icon: Icons.palette_rounded),
            if (p.imei.isNotEmpty) InfoRow('IMEI', p.imei, icon: Icons.qr_code_2_rounded),
            if (p.barcode.isNotEmpty) InfoRow('الباركود', p.barcode, icon: Icons.qr_code_scanner_rounded),
            InfoRow('الحالة', p.conditionLabel, icon: Icons.verified_rounded),
            if (admin) InfoRow('سعر الشراء', money(p.cost), icon: Icons.shopping_cart_checkout_rounded),
            InfoRow('أضافه', '${p.createdBy} • ${dateMs(p.createdAt)}', icon: Icons.badge_rounded),
            if (p.notes.isNotEmpty) InfoRow('ملاحظات', p.notes, icon: Icons.notes_rounded),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _AdminAction(icon: Icons.edit_rounded, label: 'تعديل', onTap: () => showProductForm(context, edit: p)),
              _AdminAction(icon: Icons.fact_check_rounded, label: 'تعديل الجرد', onTap: () => _adjust(context, p)),
              _AdminAction(
                icon: Icons.delete_rounded,
                label: 'حذف',
                danger: true,
                onTap: () async {
                  if (!await confirm(context, 'حذف ${p.name}؟', 'سيختفي المنتج من المخزن مع بقاء الفواتير القديمة', danger: true, ok: 'حذف')) return;
                  await ProductsRepo.delete(p);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ]),
            const SizedBox(height: 16),
            SectionTitle('سجل الحركة', subtitle: 'كل إضافة وبيع لهذه القطعة'),
            for (final s in log)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: IconBadge(
                  icon: s.change >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: s.change >= 0 ? AppColors.success : AppColors.danger,
                  size: 36,
                ),
                title: Text('${s.reasonLabel} ${s.ref.isNotEmpty ? '(${s.ref})' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${dateTimeMs(s.createdAt)} • ${s.userName}${s.note.isNotEmpty ? ' • ${s.note}' : ''}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${s.change > 0 ? '+' : ''}${s.change}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: s.change >= 0 ? AppColors.success : AppColors.danger)),
                  Text('= ${s.qtyAfter}', style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant)),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _restock(BuildContext context, Product p) async {
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('إضافة كمية — ${p.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: qty,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية المضافة', prefixIcon: Icon(Icons.add_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (المورد مثلاً)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(qty.text) ?? 0;
    if (n <= 0) return;
    if (context.mounted) await guard(context, () => ProductsRepo.restock(p.id, n, note: note.text), success: 'تمت إضافة $n قطعة');
  }

  Future<void> _adjust(BuildContext context, Product p) async {
    final qty = TextEditingController(text: '${p.qty}');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تعديل الجرد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الكمية المسجلة حالياً: ${p.qty}'),
          const SizedBox(height: 12),
          TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الفعلية')),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'السبب')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(qty.text);
    if (n == null || n < 0) return;
    if (context.mounted) await guard(context, () => ProductsRepo.adjust(p.id, n, note.text), success: 'تم تعديل الجرد');
  }
}

class _Big extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Big(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color))),
        ]),
      );
}

/// زر يحتاج صلاحية المدير
class _AdminAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _AdminAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final admin = Session.instance.isAdmin;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: danger ? AppColors.danger : null,
      ),
      onPressed: () async {
        if (await AdminGate.require(context)) onTap();
      },
      icon: Icon(admin ? icon : Icons.lock_rounded, size: 18),
      label: Text(label),
    );
  }
}
