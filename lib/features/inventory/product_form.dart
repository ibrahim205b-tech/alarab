import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/products_repo.dart';
import '../../data/repos/protectors_repo.dart';
import '../scan/scanner_page.dart';

/// نموذج إضافة/تعديل منتج
Future<void> showProductForm(BuildContext context, {Product? edit, int? categoryId, String? barcode}) =>
    showAppSheet(context, _ProductForm(edit: edit, categoryId: categoryId, barcode: barcode), maxWidth: 760);

class _ProductForm extends StatefulWidget {
  final Product? edit;
  final int? categoryId;
  final String? barcode;
  const _ProductForm({this.edit, this.categoryId, this.barcode});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final Product? e = widget.edit;
  late final _name = TextEditingController(text: e?.name);
  late final _brand = TextEditingController(text: e?.brand);
  late final _model = TextEditingController(text: e?.model);
  late final _storage = TextEditingController(text: e?.storage);
  late final _color = TextEditingController(text: e?.color);
  late final _imei = TextEditingController(text: e?.imei);
  late final _barcode = TextEditingController(text: e?.barcode ?? widget.barcode);
  late final _cost = TextEditingController(text: e == null || e!.cost == 0 ? '' : numFmt(e!.cost));
  late final _price = TextEditingController(text: e == null ? '' : numFmt(e!.price));
  late final _qty = TextEditingController(text: e == null ? '1' : '${e!.qty}');
  late final _minQty = TextEditingController(text: '${e?.minQty ?? 1}');
  late final _notes = TextEditingController(text: e?.notes);
  late String _condition = e?.condition ?? 'new';
  int? _categoryId;
  int? _groupId;
  List<Category> _cats = [];
  List<ProtectorGroup> _groups = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _categoryId = e?.categoryId ?? widget.categoryId;
    _groupId = e?.protectorGroupId;
    ProductsRepo.categories().then((c) {
      if (mounted) setState(() => _cats = c);
    });
    ProtectorsRepo.groups().then((g) {
      if (mounted) setState(() => _groups = g);
    });
  }

  Category? get _cat => _cats.where((c) => c.id == _categoryId).firstOrNull;
  bool get _isPhone => _cat?.icon == 'phone' || _cat?.icon == 'tablet';
  bool get _isProtector => _cat?.icon == 'shield';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final p = Product(
      id: e?.id ?? 0,
      name: _name.text.trim(),
      categoryId: _categoryId,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      storage: _storage.text.trim(),
      color: _color.text.trim(),
      imei: _imei.text.trim(),
      barcode: _barcode.text.trim(),
      condition: _condition,
      cost: parseMoney(_cost.text),
      price: parseMoney(_price.text),
      minQty: int.tryParse(_minQty.text) ?? 1,
      protectorGroupId: _isProtector ? _groupId : null,
      notes: _notes.text.trim(),
    );
    final ok = await guard(context, () async {
      if (e == null) {
        await ProductsRepo.create(p, int.tryParse(_qty.text) ?? 0);
      } else {
        await ProductsRepo.update(p);
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) {
      Navigator.pop(context);
      toast(context, e == null ? 'تمت إضافة "${p.name}" للمخزن' : 'تم حفظ التعديلات');
    }
  }

  Widget _row(List<Widget> children) => LayoutBuilder(builder: (c, cons) {
        if (cons.maxWidth < 420) {
          return Column(children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: children[i])],
        ]);
      });

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: e == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
      icon: e == null ? Icons.add_box_rounded : Icons.edit_rounded,
      footer: FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: Text(e == null ? 'إضافة للمخزن' : 'حفظ التعديلات'),
      ),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('القسم', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _cats)
              ChoiceChip(
                avatar: Icon(categoryIcon(c.icon), size: 18, color: c.c),
                label: Text(c.name),
                selected: _categoryId == c.id,
                selectedColor: c.c.withValues(alpha: .22),
                onSelected: (_) => setState(() => _categoryId = c.id),
              ),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسم المنتج *', prefixIcon: Icon(Icons.label_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'اسم المنتج مطلوب' : null,
          ),
          const SizedBox(height: 12),
          _row([
            TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'الشركة / الماركة', prefixIcon: Icon(Icons.business_rounded))),
            TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'الموديل', prefixIcon: Icon(Icons.devices_rounded))),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: !_isPhone
                ? const SizedBox(width: double.infinity)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'new', label: Text('جديد'), icon: Icon(Icons.fiber_new_rounded)),
                        ButtonSegment(value: 'used', label: Text('مستعمل'), icon: Icon(Icons.history_rounded)),
                      ],
                      selected: {_condition},
                      onSelectionChanged: (s) => setState(() => _condition = s.first),
                    ),
                    const SizedBox(height: 12),
                    _row([
                      TextFormField(controller: _storage, decoration: const InputDecoration(labelText: 'السعة (مثلاً 128GB)', prefixIcon: Icon(Icons.sd_storage_rounded))),
                      TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'اللون', prefixIcon: Icon(Icons.palette_rounded))),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imei,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'IMEI / الرقم التسلسلي',
                        prefixIcon: const Icon(Icons.qr_code_2_rounded),
                        suffixIcon: ScanButton(title: 'امسح IMEI', onCode: (v) => setState(() => _imei.text = v)),
                      ),
                    ),
                  ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: !_isProtector
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<int?>(
                      initialValue: _groups.any((g) => g.id == _groupId) ? _groupId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'مجموعة التوافق (الأجهزة التي يركب عليها)', prefixIcon: Icon(Icons.shield_rounded)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون')),
                        for (final g in _groups)
                          DropdownMenuItem(value: g.id, child: Text('${g.name} (${g.models.length})', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcode,
            decoration: InputDecoration(
              labelText: 'الباركود (اختياري)',
              prefixIcon: const Icon(Icons.qr_code_rounded),
              suffixIcon: ScanButton(onCode: (v) => setState(() => _barcode.text = v)),
            ),
          ),
          const SizedBox(height: 16),
          _row([
            MoneyField(controller: _cost, label: 'سعر الشراء (الكلفة)'),
            MoneyField(controller: _price, label: 'سعر البيع *', validator: (v) => v <= 0 ? 'سعر البيع مطلوب' : null),
          ]),
          const SizedBox(height: 12),
          if (e == null) ...[
            QtyField(controller: _qty, label: 'الكمية *'),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _minQty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'تنبيه عند نزول الكمية إلى', prefixIcon: Icon(Icons.notifications_active_rounded)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes_rounded)),
          ),
        ]),
      ),
    );
  }
}
