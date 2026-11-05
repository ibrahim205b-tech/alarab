import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/protectors_repo.dart';
import '../inventory/inventory_screen.dart';
import 'link_stock_page.dart';

/// قسم توافقات لاصقات الحماية: اكتب اسم أي جهاز فتظهر كل الأجهزة التي تركب عليها نفس اللاصقة
class ProtectorsScreen extends StatefulWidget {
  const ProtectorsScreen({super.key});
  @override
  State<ProtectorsScreen> createState() => _ProtectorsScreenState();
}

class _ProtectorsScreenState extends State<ProtectorsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'prot-fab',
        onPressed: () => _editGroup(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مجموعة توافق'),
      ),
      body: DataView<List<ProtectorGroup>>(
        load: ProtectorsRepo.groups,
        builder: (context, groups) {
          final results = ProtectorsRepo.search(groups, _q);
          final exact = results.where((r) => r.exact).toList();
          final partial = results.where((r) => !r.exact).toList();
          final totalModels = groups.fold<int>(0, (s, g) => s + g.models.length);
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF0F766E)]),
                    ),
                    child: Row(children: [
                      const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('ابحث عن أي جهاز', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('${groups.length} لاصقة • $totalModels جهاز في قاعدة التوافقات',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ).animate().fadeIn().slideY(begin: -.1, end: 0),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkStockPage())),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('ربط لاصقات المخزن بالتوافقات'),
                  ),
                  const SizedBox(height: 12),
                  SearchField(
                    hint: 'مثال: A12 أو iPhone 13 أو ريدمي نوت 10',
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ]),
              ),
            ),
            if (_q.trim().isNotEmpty && results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا يوجد توافق مسجل لهذا الجهاز',
                  message: 'يمكنك إضافة الجهاز إلى مجموعة موجودة أو إنشاء مجموعة جديدة',
                  action: FilledButton.icon(onPressed: () => _editGroup(context), icon: const Icon(Icons.add), label: const Text('مجموعة جديدة')),
                ),
              ),
            if (exact.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: SectionTitle('اللاصقة المتوافقة', subtitle: 'كل هذه الأجهزة تركب عليها نفس اللاصقة')),
              ),
              _groupList(exact, highlight: true),
            ],
            if (partial.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionTitle(_q.trim().isEmpty ? 'كل مجموعات التوافق' : (exact.isEmpty ? 'نتائج مقاربة' : 'قد تقصد أيضاً')),
                ),
              ),
              _groupList(partial, highlight: false),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]);
        },
      ),
    );
  }

  Widget _groupList(List<ProtectorMatch> list, {required bool highlight}) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (c, i) => _GroupCard(match: list[i], highlight: highlight, onEdit: () => _editGroup(context, list[i].group)).stagger(i),
        ),
      );

  Future<void> _editGroup(BuildContext context, [ProtectorGroup? g]) async {
    if (g == null) {
      if (!await AdminGate.require(context, reason: 'إضافة مجموعات التوافق للمدير')) return;
    }
    if (!context.mounted) return;
    await showAppSheet(context, _GroupEditor(group: g));
  }
}

class _GroupCard extends StatelessWidget {
  final ProtectorMatch match;
  final bool highlight;
  final VoidCallback onEdit;
  const _GroupCard({required this.match, required this.highlight, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final g = match.group;
    final color = highlight ? AppColors.teal : context.cs.primary;
    return AppCard(
      borderColor: highlight ? AppColors.teal : null,
      color: highlight ? AppColors.teal.withValues(alpha: .07) : null,
      onTap: onEdit,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(icon: Icons.shield_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                [if (g.size.isNotEmpty) 'مقاس ${g.size} إنش', '${g.models.length} أجهزة', if (g.notes.isNotEmpty) g.notes].join(' • '),
                style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5),
              ),
            ]),
          ),
          Pill(g.stock > 0 ? 'متوفر ${g.stock}' : 'غير متوفر',
              color: g.stock > 0 ? AppColors.success : AppColors.danger, icon: Icons.inventory_2_rounded),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in g.models)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: match.matchedIds.contains(m.id) ? color : context.cs.surfaceContainerHigh,
                border: Border.all(color: match.matchedIds.contains(m.id) ? color : context.cs.outline.withValues(alpha: .6)),
              ),
              child: Text(
                m.full,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: match.matchedIds.contains(m.id) ? Colors.white : null,
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

Future<void> _linkFromStock(BuildContext context, ProtectorGroup g) async {
  if (!await AdminGate.require(context, reason: 'ربط التوافقات للمدير')) return;
  final items = (await ProtectorsRepo.stockProtectors()).where((p) => p.protectorGroupId != g.id).toList();
  if (!context.mounted) return;
  if (items.isEmpty) {
    toast(context, 'لا توجد لاصقات أخرى بالمخزن — أضفها من المخزن أولاً', error: true);
    return;
  }
  final chosen = await showAppSheet<Product>(
    context,
    SheetScaffold(
      title: 'اختر اللاصقة',
      icon: Icons.add_link_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('سيتم ربطها بمجموعة: ${g.name}', style: TextStyle(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final p in items)
          Builder(
            builder: (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shield_rounded, color: p.protectorGroupId == null ? AppColors.warning : c.cs.onSurfaceVariant),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(p.protectorGroupId == null ? 'غير مربوطة • الكمية ${p.qty}' : 'مربوطة بمجموعة أخرى • الكمية ${p.qty}'),
              onTap: () => Navigator.pop(c, p),
            ),
          ),
      ]),
    ),
  );
  if (chosen == null) return;
  await ProtectorsRepo.link(chosen, g.id);
  if (context.mounted) toast(context, 'تم ربط ${chosen.name}');
}

class _GroupEditor extends StatefulWidget {
  final ProtectorGroup? group;
  const _GroupEditor({this.group});
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group?.name);
  late final _size = TextEditingController(text: widget.group?.size);
  late final _notes = TextEditingController(text: widget.group?.notes);
  final _brand = TextEditingController();
  final _model = TextEditingController();
  late final List<(String, String)> _pending = [];

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return DataView<List<ProtectorGroup>>(
      load: ProtectorsRepo.groups,
      builder: (context, groups) {
        final current = g == null ? null : groups.where((x) => x.id == g.id).firstOrNull;
        final models = current?.models ?? const <ProtectorModel>[];
        return SheetScaffold(
          title: g == null ? 'مجموعة توافق جديدة' : g.name,
          icon: Icons.shield_rounded,
          footer: g == null
              ? FilledButton.icon(
                  onPressed: () async {
                    if (_name.text.trim().isEmpty || _pending.isEmpty) {
                      toast(context, 'اكتب اسم اللاصقة وأضف جهازاً واحداً على الأقل', error: true);
                      return;
                    }
                    await ProtectorsRepo.addGroup(_name.text, _size.text, _notes.text, _pending);
                    if (context.mounted) {
                      Navigator.pop(context);
                      toast(context, 'تمت إضافة المجموعة');
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ المجموعة'),
                )
              : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (g == null) ...[
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم اللاصقة (مثلاً: A12 / A32 5G)', prefixIcon: Icon(Icons.label_rounded))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _size, decoration: const InputDecoration(labelText: 'المقاس (إنش)'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظة'))),
              ]),
              const SizedBox(height: 16),
            ],
            if (current != null) ...[
              FutureBuilder<List<Product>>(
                future: ProtectorsRepo.productsFor(current.id),
                builder: (c, s) {
                  final ps = s.data ?? const <Product>[];
                  if (ps.isEmpty) {
                    return Text('لا توجد لاصقات مرتبطة بهذه المجموعة في المخزن — اربطها من نموذج المنتج (قسم لاصقات حماية)',
                        style: TextStyle(color: context.cs.onSurfaceVariant));
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('المتوفر بالمخزن'),
                    for (final p in ps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const IconBadge(icon: Icons.shield_rounded, color: AppColors.teal, size: 38),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Pill('${p.qty}', color: p.qty > 0 ? AppColors.success : AppColors.danger),
                        onTap: () => showProductDetails(context, p.id),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 14),
            ],
            if (current != null) ...[
              OutlinedButton.icon(
                onPressed: () => _linkFromStock(context, current),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('ربط لاصقة من المخزن بهذه المجموعة'),
              ),
              const SizedBox(height: 14),
            ],
            const SectionTitle('الأجهزة المتوافقة'),
            for (final m in models)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.smartphone_rounded),
                title: Text(m.full, textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                  onPressed: () async {
                    if (!await AdminGate.require(context)) return;
                    await ProtectorsRepo.deleteModel(m.id);
                  },
                ),
              ),
            for (final m in _pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.smartphone_rounded, color: AppColors.success),
                title: Text('${m.$1} ${m.$2}', textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _pending.remove(m))),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _brand, decoration: const InputDecoration(labelText: 'الشركة', hintText: 'Samsung'))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextField(controller: _model, decoration: const InputDecoration(labelText: 'الموديل', hintText: 'Galaxy A12'))),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () async {
                  if (_model.text.trim().isEmpty) return;
                  if (current != null) {
                    if (!await AdminGate.require(context, reason: 'تعديل التوافقات للمدير')) return;
                    await ProtectorsRepo.addModel(current.id, _brand.text, _model.text);
                  } else {
                    setState(() => _pending.add((_brand.text.trim(), _model.text.trim())));
                  }
                  _model.clear();
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (current != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (!await AdminGate.require(context)) return;
                  if (!context.mounted) return;
                  if (!await confirm(context, 'حذف المجموعة؟', current.name, danger: true, ok: 'حذف')) return;
                  await ProtectorsRepo.deleteGroup(current.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('حذف المجموعة'),
              ),
            ],
          ]),
        );
      },
    );
  }
}
