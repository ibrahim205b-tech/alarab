import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/lines_repo.dart';
import '../../data/repos/reports_repo.dart';
import '../../data/repos/sales_repo.dart';
import '../../services/session.dart';
import '../invoices/receipt_actions.dart';
import 'line_sale_sheet.dart';

class LinesScreen extends StatefulWidget {
  const LinesScreen({super.key});
  @override
  State<LinesScreen> createState() => _LinesScreenState();
}

class _LinesScreenState extends State<LinesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'line-fab',
        onPressed: () => showLineSaleSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة خط مباع'),
      ).animate().scaleXY(begin: 0, end: 1, delay: 200.ms, curve: Curves.easeOutBack),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.cs.outline.withValues(alpha: .5)),
            ),
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(height: 46, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.widgets_rounded, size: 20), SizedBox(width: 8), Text('الخدمات')])),
                Tab(height: 46, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.receipt_rounded, size: 20), SizedBox(width: 8), Text('الخطوط المباعة')])),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: const [_ServicesTab(), _SoldTab()]),
        ),
      ]),
    );
  }
}

// =====================================================================
// الواجهة الأولى: الخدمات
// =====================================================================

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    return DataView<(List<LineType>, List<Service>, List<LineSale>)>(
      load: () async {
        final today = await ReportsRepo.shiftStart();
        return (
          await LinesRepo.lineTypes(activeOnly: true),
          await LinesRepo.services(activeOnly: true),
          await LinesRepo.sales(from: today),
        );
      },
      builder: (context, d) {
        final (types, services, todaySales) = d;
        final todayTotal = todaySales.fold<int>(0, (s, e) => s + e.amount);
        final byCarrier = <String, List<LineType>>{};
        for (final t in types) {
          byCarrier.putIfAbsent(t.carrierName, () => []).add(t);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _TodayBanner(count: todaySales.length, total: todayTotal),
            const SizedBox(height: 18),
            if (types.isEmpty)
              const EmptyState(icon: Icons.sim_card_alert_rounded, title: 'لا توجد خدمات بعد', message: 'أضف أنواع الخطوط والخدمات من قسم الإدارة'),
            for (final entry in byCarrier.entries) ...[
              SectionTitle(entry.key, subtitle: '${entry.value.length} أنواع خطوط'),
              for (var i = 0; i < entry.value.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LineTypeCard(
                    type: entry.value[i],
                    services: services.where((s) => s.lineTypeId == entry.value[i].id).toList(),
                    soldToday: todaySales.where((s) => s.lineTypeId == entry.value[i].id).length,
                  ).stagger(i),
                ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _TodayBanner extends StatelessWidget {
  final int count, total;
  const _TodayBanner({required this.count, required this.total});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE5202E), Color(0xFF8E1520)],
        ),
        boxShadow: [BoxShadow(color: AppColors.asiacell.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مبيعات خطوط الوردية', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            CountUp(total, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          ]),
        ),
        Column(children: [
          CountUp(count, asMoney: false, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const Text('خط', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        ]),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _LineTypeCard extends StatelessWidget {
  final LineType type;
  final List<Service> services;
  final int soldToday;
  const _LineTypeCard({required this.type, required this.services, required this.soldToday});

  @override
  Widget build(BuildContext context) {
    final color = Color(type.color);
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: .35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(icon: Icons.sim_card_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${services.length} خدمات', style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ),
          if (soldToday > 0) Pill('اليوم $soldToday', color: color, icon: Icons.trending_up_rounded),
        ]),
        const SizedBox(height: 12),
        if (services.isEmpty)
          Text('لا توجد خدمات — أضفها من الإدارة', style: TextStyle(color: context.cs.onSurfaceVariant))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in services)
              Pressable(
                onTap: () => showLineSaleSheet(context, type: type, service: s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: color.withValues(alpha: .1),
                    border: Border.all(color: color.withValues(alpha: .3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(money(s.price), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ]),
                ),
              ),
          ]),
      ]),
    );
  }
}

// =====================================================================
// الواجهة الثانية: الخطوط المباعة
// =====================================================================

enum _Range { today, period, all }

class _SoldTab extends StatefulWidget {
  const _SoldTab();
  @override
  State<_SoldTab> createState() => _SoldTabState();
}

class _SoldTabState extends State<_SoldTab> {
  _Range _range = _Range.today;
  int? _typeId;

  @override
  Widget build(BuildContext context) {
    return DataView<(List<LineSale>, List<LineType>)>(
      reloadKey: '$_range-$_typeId',
      load: () async {
        final types = await LinesRepo.lineTypes();
        List<LineSale> sales;
        switch (_range) {
          case _Range.today:
            sales = await LinesRepo.sales(from: await ReportsRepo.shiftStart(), lineTypeId: _typeId);
          case _Range.period:
            final n = DateTime.now();
            sales = await LinesRepo.sales(from: DateTime(n.year, n.month), lineTypeId: _typeId);
          case _Range.all:
            sales = await LinesRepo.sales(lineTypeId: _typeId);
        }
        return (sales, types);
      },
      builder: (context, d) {
        final (sales, types) = d;
        final total = sales.fold<int>(0, (s, e) => s + e.amount);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegmentedButton<_Range>(
                  segments: const [
                    ButtonSegment(value: _Range.today, label: Text('الوردية'), icon: Icon(Icons.today_rounded)),
                    ButtonSegment(value: _Range.period, label: Text('هذا الشهر'), icon: Icon(Icons.calendar_month_rounded)),
                    ButtonSegment(value: _Range.all, label: Text('الكل'), icon: Icon(Icons.all_inclusive_rounded)),
                  ],
                  selected: {_range},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('كل الأنواع'), selected: _typeId == null, onSelected: (_) => setState(() => _typeId = null)),
                    for (final t in types) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(t.name),
                        selected: _typeId == t.id,
                        selectedColor: Color(t.color).withValues(alpha: .25),
                        avatar: CircleAvatar(backgroundColor: Color(t.color), radius: 5),
                        onSelected: (_) => setState(() => _typeId = t.id),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MiniStat(label: 'عدد الخطوط', value: '${sales.length}', icon: Icons.sim_card_rounded, color: AppColors.asiacell)),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'المجموع', value: money(total), icon: Icons.payments_rounded, color: AppColors.success)),
                ]),
              ]),
            ),
          ),
          if (sales.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.sim_card_outlined, title: 'لا توجد خطوط مباعة', message: 'اضغط "إضافة خط مباع" لتسجيل أول عملية'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList.separated(
                itemCount: sales.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (c, i) {
                  final s = sales[i];
                  final type = types.where((t) => t.id == s.lineTypeId).firstOrNull;
                  return _SoldTile(sale: s, color: Color(type?.color ?? AppColors.asiacell.toARGB32())).stagger(i);
                },
              ),
            ),
        ]);
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          IconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12)),
              FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
          ),
        ]),
      );
}

class _SoldTile extends StatelessWidget {
  final LineSale sale;
  final Color color;
  const _SoldTile({required this.sale, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _showDetails(context),
      child: Row(children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)]),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text('#${sale.number}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sale.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${sale.carrierName} • ${sale.lineTypeName}${sale.customerPhone.isNotEmpty ? ' • ${sale.customerPhone}' : ''}',
                style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
            Text('${timeStr(DateTime.fromMillisecondsSinceEpoch(sale.createdAt))} • ${dateMs(sale.createdAt)} • ${sale.userName}',
                style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 11.5)),
          ]),
        ),
        Text(money(sale.amount), style: TextStyle(fontWeight: FontWeight.w800, color: context.cs.primary, fontSize: 15)),
      ]),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final inv = sale.invoiceId == null ? null : await SalesRepo.get(sale.invoiceId!);
    if (!context.mounted) return;
    await showAppSheet(
      context,
      Builder(
        builder: (c) => SheetScaffold(
          title: 'الخط #${sale.number}',
          icon: Icons.sim_card_rounded,
          footer: inv == null ? null : ReceiptButtons(doc: invoicePdf(inv), name: inv.code),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow('الشركة', sale.carrierName, icon: Icons.cell_tower_rounded),
            InfoRow('نوع الخط', sale.lineTypeName, icon: Icons.sim_card_rounded),
            InfoRow('الخدمة', sale.serviceName, icon: Icons.widgets_rounded),
            InfoRow('المبلغ', money(sale.amount), icon: Icons.payments_rounded, bold: true),
            if (sale.customerPhone.isNotEmpty) InfoRow('الرقم', sale.customerPhone, icon: Icons.phone_rounded),
            InfoRow('الوقت', dateTimeMs(sale.createdAt), icon: Icons.schedule_rounded),
            InfoRow('الموظف', sale.userName, icon: Icons.badge_rounded),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!await AdminGate.require(c, reason: 'تعديل المبيعات للمدير فقط')) return;
                    if (!c.mounted) return;
                    Navigator.pop(c);
                    if (context.mounted) await showLineSaleSheet(context, edit: sale);
                  },
                  icon: Icon(Session.instance.isAdmin ? Icons.edit_rounded : Icons.lock_rounded),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    if (!await AdminGate.require(c, reason: 'حذف المبيعات للمدير فقط')) return;
                    if (!c.mounted) return;
                    if (!await confirm(c, 'حذف الخط #${sale.number}؟', 'سيتم إلغاء الفاتورة وخصمها من المبيعات', danger: true, ok: 'حذف')) return;
                    await LinesRepo.deleteSale(sale);
                    if (c.mounted) {
                      Navigator.pop(c);
                      toast(c, 'تم حذف الخط');
                    }
                  },
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('حذف'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
