import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/lines_repo.dart';

/// إدارة شركات الاتصال وأنواع الخطوط والخدمات
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطوط والخدمات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _typeDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('نوع خط جديد'),
      ),
      body: DataView<(List<Carrier>, List<LineType>, List<Service>)>(
        load: () async => (await LinesRepo.carriers(), await LinesRepo.lineTypes(), await LinesRepo.services()),
        builder: (context, d) {
          final (carriers, types, services) = d;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              SectionTitle('شركات الاتصال',
                  trailing: TextButton.icon(onPressed: () => _carrierDialog(context), icon: const Icon(Icons.add), label: const Text('شركة'))),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in carriers)
                  InputChip(
                    avatar: CircleAvatar(backgroundColor: Color(c.color), radius: 8),
                    label: Text(c.name),
                    onPressed: () => _carrierDialog(context, c),
                    onDeleted: () => guard(context, () => LinesRepo.deleteCarrier(c.id)),
                  ),
              ]),
              const SizedBox(height: 20),
              for (final c in carriers) ...[
                SectionTitle(c.name, subtitle: 'أنواع الخطوط والخدمات'),
                for (final t in types.where((t) => t.carrierId == c.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TypeCard(type: t, services: services.where((s) => s.lineTypeId == t.id).toList(), carriers: carriers),
                  ),
                if (!types.any((t) => t.carrierId == c.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('لا توجد أنواع خطوط لـ ${c.name}', style: TextStyle(color: context.cs.onSurfaceVariant)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final LineType type;
  final List<Service> services;
  final List<Carrier> carriers;
  const _TypeCard({required this.type, required this.services, required this.carriers});

  @override
  Widget build(BuildContext context) {
    final color = Color(type.color);
    return Opacity(
      opacity: type.active ? 1 : .55,
      child: AppCard(
        borderColor: color.withValues(alpha: .4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBadge(icon: Icons.sim_card_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(type.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Switch(value: type.active, onChanged: (v) => LinesRepo.updateLineType(type.id, active: v)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') _typeDialog(context, type);
                if (v == 'delete' &&
                    await confirm(context, 'حذف "${type.name}"؟', 'ستُحذف خدماته أيضاً (المبيعات السابقة تبقى)', danger: true, ok: 'حذف')) {
                  await LinesRepo.deleteLineType(type.id);
                }
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          for (final s in services)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(s.active ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: s.active ? color : context.cs.onSurfaceVariant),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              subtitle: Text('السعر ${money(s.price)}${s.cost > 0 ? ' • الكلفة ${money(s.cost)}' : ''}'),
              trailing: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _serviceDialog(context, type, s)),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _serviceDialog(context, type),
            icon: const Icon(Icons.add_rounded),
            label: Text('إضافة خدمة لـ ${type.name}'),
          ),
        ]),
      ),
    );
  }
}

Future<void> _carrierDialog(BuildContext context, [Carrier? c]) async {
  final name = TextEditingController(text: c?.name);
  var color = c?.color ?? palette.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(c == null ? 'شركة اتصال جديدة' : 'تعديل الشركة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 14),
          ColorPicker(value: color, onChanged: (v) => set(() => color = v)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  if (c == null) {
    await LinesRepo.addCarrier(name.text, color);
  } else {
    await LinesRepo.updateCarrier(c.id, name.text, color);
  }
}

Future<void> _typeDialog(BuildContext context, [LineType? t]) async {
  final carriers = await LinesRepo.carriers();
  if (!context.mounted) return;
  if (carriers.isEmpty) {
    toast(context, 'أضف شركة اتصال أولاً', error: true);
    return;
  }
  final name = TextEditingController(text: t?.name);
  var color = t?.color ?? palette[6];
  var carrierId = t?.carrierId ?? carriers.first.id;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(t == null ? 'نوع خط جديد' : 'تعديل نوع الخط'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, children: [
              for (final c in carriers) ChoiceChip(label: Text(c.name), selected: carrierId == c.id, onSelected: (_) => set(() => carrierId = c.id)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم النوع (مثلاً: ريد)')),
            const SizedBox(height: 14),
            ColorPicker(value: color, onChanged: (v) => set(() => color = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  if (t == null) {
    await LinesRepo.addLineType(carrierId, name.text, color);
  } else {
    await LinesRepo.updateLineType(t.id, name: name.text, color: color, carrierId: carrierId);
  }
}

Future<void> _serviceDialog(BuildContext context, LineType type, [Service? s]) async {
  final name = TextEditingController(text: s?.name ?? '${type.name} ');
  final price = TextEditingController(text: s == null ? '' : numFmt(s.price));
  final cost = TextEditingController(text: s == null || s.cost == 0 ? '' : numFmt(s.cost));
  var active = s?.active ?? true;
  final res = await showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(s == null ? 'خدمة جديدة — ${type.name}' : 'تعديل الخدمة'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الخدمة (مثلاً: ريد 15)')),
              const SizedBox(height: 12),
              MoneyField(controller: price, label: 'سعر البيع'),
              const SizedBox(height: 12),
              MoneyField(controller: cost, label: 'الكلفة علينا (اختياري لحساب الربح)'),
              if (s != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الخدمة متاحة للبيع'),
                  value: active,
                  onChanged: (v) => set(() => active = v),
                ),
            ]),
          ),
        ),
        actions: [
          if (s != null)
            TextButton(
              onPressed: () => Navigator.pop(d, 'delete'),
              child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('حفظ')),
        ],
      ),
    ),
  );
  if (res == 'delete' && s != null) {
    await LinesRepo.deleteService(s.id);
    return;
  }
  if (res != 'save' || name.text.trim().isEmpty) return;
  if (!context.mounted) return;
  if (parseMoney(price.text) <= 0) {
    toast(context, 'أدخل سعر الخدمة', error: true);
    return;
  }
  if (s == null) {
    await LinesRepo.addService(type.id, name.text, parseMoney(price.text), parseMoney(cost.text));
  } else {
    await LinesRepo.updateService(s.id, name: name.text, price: parseMoney(price.text), cost: parseMoney(cost.text), active: active);
  }
}
