import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/protectors_repo.dart';

/// ربط اللاصقات الموجودة بالمخزن بمجموعات التوافق — تلقائياً دفعة واحدة أو يدوياً
class LinkStockPage extends StatelessWidget {
  const LinkStockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ربط لاصقات المخزن')),
      body: DataView<(List<Product>, List<ProtectorGroup>)>(
        load: () async => (await ProtectorsRepo.stockProtectors(), await ProtectorsRepo.groups()),
        builder: (context, d) {
          final (items, groups) = d;
          final unlinked = items.where((p) => p.protectorGroupId == null).toList();
          final suggestions = {for (final p in unlinked) p.id: ProtectorsRepo.suggest(groups, p)};
          final canAuto = suggestions.values.where((s) => s != null).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              AppCard(
                borderColor: AppColors.teal.withValues(alpha: .5),
                color: AppColors.teal.withValues(alpha: .07),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const IconBadge(icon: Icons.auto_fix_high_rounded, color: AppColors.teal, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${items.length} لاصقة بالمخزن', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        Text('${items.length - unlinked.length} مربوطة • ${unlinked.length} غير مربوطة',
                            style: TextStyle(color: context.cs.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'الربط التلقائي يقرأ اسم الجهاز من اسم المنتج (مثلاً "لاصقة 9D A12") ويربطه بمجموعته. '
                    'اللاصقات التي لا يتعرف عليها اختر مجموعتها بالضغط عليها.',
                    style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: canAuto == 0
                        ? null
                        : () async {
                            if (!await AdminGate.require(context, reason: 'ربط التوافقات للمدير')) return;
                            if (!context.mounted) return;
                            final n = await ProtectorsRepo.autoLinkAll();
                            if (context.mounted) toast(context, 'تم ربط $n لاصقة تلقائياً');
                          },
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(canAuto == 0 ? 'لا توجد لاصقات يمكن ربطها تلقائياً' : 'ربط $canAuto لاصقة تلقائياً'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'لا توجد لاصقات بالمخزن',
                  message: 'أضف اللاصقات من المخزن ← إضافة منتج ← قسم "لاصقات حماية"',
                ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Row(
                    product: items[i],
                    group: groups.where((g) => g.id == items[i].protectorGroupId).firstOrNull,
                    suggestion: suggestions[items[i].id],
                    groups: groups,
                  ).stagger(i),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Product product;
  final ProtectorGroup? group;
  final (ProtectorGroup, ProtectorModel)? suggestion;
  final List<ProtectorGroup> groups;
  const _Row({required this.product, required this.group, required this.suggestion, required this.groups});

  @override
  Widget build(BuildContext context) {
    final linked = group != null;
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: linked ? AppColors.success.withValues(alpha: .4) : null,
      onTap: () => _pick(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(icon: Icons.shield_rounded, color: linked ? AppColors.success : AppColors.warning, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(linked ? group!.name : 'غير مربوطة — اضغط لاختيار المجموعة',
                  style: TextStyle(fontSize: 12.5, color: linked ? AppColors.success : context.cs.onSurfaceVariant)),
            ]),
          ),
          Pill('${product.qty}', color: product.qty > 0 ? AppColors.success : AppColors.danger, icon: Icons.inventory_2_rounded),
        ]),
        if (!linked && suggestion != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text('مقترح: ${suggestion!.$1.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal)),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () async {
                if (!await AdminGate.require(context, reason: 'ربط التوافقات للمدير')) return;
                await ProtectorsRepo.link(product, suggestion!.$1.id);
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('ربط'),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _pick(BuildContext context) async {
    if (!await AdminGate.require(context, reason: 'ربط التوافقات للمدير')) return;
    if (!context.mounted) return;
    final chosen = await pickProtectorGroup(context, groups, title: product.name, allowNone: group != null);
    if (chosen == null) return;
    await ProtectorsRepo.link(product, chosen == -1 ? null : chosen);
    if (context.mounted) toast(context, chosen == -1 ? 'تم فك الربط' : 'تم الربط');
  }
}

/// اختيار مجموعة توافق مع بحث. يعيد id المجموعة، أو -1 لفك الربط، أو null للإلغاء
Future<int?> pickProtectorGroup(BuildContext context, List<ProtectorGroup> groups, {required String title, bool allowNone = false}) {
  return showAppSheet<int>(context, _GroupPicker(groups: groups, title: title, allowNone: allowNone));
}

class _GroupPicker extends StatefulWidget {
  final List<ProtectorGroup> groups;
  final String title;
  final bool allowNone;
  const _GroupPicker({required this.groups, required this.title, required this.allowNone});
  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final results = ProtectorsRepo.search(widget.groups, _q);
    return SheetScaffold(
      title: 'مجموعة التوافق',
      icon: Icons.shield_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: TextStyle(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        SearchField(hint: 'اكتب اسم الجهاز: A12، ايفون 13...', autofocus: true, onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 10),
        if (widget.allowNone)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_off_rounded, color: AppColors.danger),
            title: const Text('فك الربط', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, -1),
          ),
        for (final r in results.take(40))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shield_rounded, color: r.exact ? AppColors.teal : context.cs.onSurfaceVariant),
            title: Text(r.group.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(r.group.models.map((m) => m.model).join('، '), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, r.group.id),
          ),
      ]),
    );
  }
}
