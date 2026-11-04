import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/debts_repo.dart';
import '../../data/repos/products_repo.dart';
import '../../data/repos/repairs_repo.dart';
import '../../data/repos/reports_repo.dart';
import '../../data/repos/sales_repo.dart';
import '../../services/session.dart';
import '../debts/debt_sheet.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/product_form.dart';
import '../invoices/invoices_screen.dart';
import '../lines/line_sale_sheet.dart';
import '../repairs/repair_form.dart';
import '../shell/shell.dart';
import '../shift/shift_reset.dart';

class _DashData {
  final ReportSummary today, yesterday;
  final List<(DateTime, int)> week;
  final Map<RepairStatus, int> repairs;
  final (int, int) debts;
  final int lowStock;
  final List<Invoice> recent;
  final DateTime shift;
  _DashData(this.today, this.yesterday, this.week, this.repairs, this.debts, this.lowStock, this.recent, this.shift);
  /// هل تم تصفير الوردية اليوم؟
  bool get resetToday => shift.isAfter(startOfDay(DateTime.now()));
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<_DashData> _load() async {
    final t0 = startOfDay(DateTime.now());
    final t1 = t0.add(const Duration(days: 1));
    final y0 = t0.subtract(const Duration(days: 1));
    final stats = await ProductsRepo.stats();
    final shift = await ReportsRepo.shiftStart();
    return _DashData(
      await ReportsRepo.summary(shift, t1),
      await ReportsRepo.summary(y0, t0),
      await ReportsRepo.daily(7),
      await RepairsRepo.counts(),
      await DebtsRepo.openSummary(),
      stats.$5,
      await SalesRepo.list(limit: 8, includeVoid: false, from: shift),
      shift,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DataView<_DashData>(
      load: _load,
      builder: (context, d) {
        final wide = context.w >= 900;
        final hero = _HeroCard(d: d);
        final stats = _StatsGrid(d: d);
        final actions = const _QuickActions();
        final chart = AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('مبيعات آخر 7 أيام'),
            DailyBars(data: d.week),
          ]),
        );
        final recent = AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('عمليات الوردية الحالية',
                trailing: TextButton(onPressed: () => ShellNav.go(Section.invoices), child: const Text('الكل'))),
            if (d.recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('لا توجد عمليات في هذه الوردية بعد', textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
              ),
            for (var i = 0; i < d.recent.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: InvoiceTile(invoice: d.recent[i]).stagger(i)),
          ]),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Greeting(),
            const SizedBox(height: 14),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: Column(children: [hero, const SizedBox(height: 14), stats])),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: Column(children: [actions, const SizedBox(height: 14), chart])),
              ])
            else ...[
              hero,
              const SizedBox(height: 14),
              actions,
              const SizedBox(height: 14),
              stats,
              const SizedBox(height: 14),
              chart,
            ],
            const SizedBox(height: 14),
            recent,
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'صباح الخير' : (h < 18 ? 'نهارك سعيد' : 'مساء الخير');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$greet، ${Session.instance.user?.name ?? ''} 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      Text(longDate(DateTime.now()), style: TextStyle(color: context.cs.onSurfaceVariant)),
    ]).animate().fadeIn(duration: 400.ms).slideX(begin: .05, end: 0);
  }
}

class _HeroCard extends StatelessWidget {
  final _DashData d;
  const _HeroCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final today = d.today, yesterday = d.yesterday;
    final diff = d.resetToday || yesterday.revenue == 0 ? null : ((today.revenue - yesterday.revenue) / yesterday.revenue * 100).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF4DB97), AppColors.gold, Color(0xFF8E6A22)],
        ),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Stack(children: [
        PositionedDirectional(
          end: -20,
          top: -20,
          child: Icon(Icons.auto_graph_rounded, size: 140, color: AppColors.ink.withValues(alpha: .07)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(d.resetToday ? 'مبيعات الوردية • منذ ${timeStr(d.shift)}' : 'مبيعات اليوم',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Spacer(),
            if (diff != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(diff >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: AppColors.ink),
                  const SizedBox(width: 4),
                  Text('${diff.abs()}% عن أمس', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              ),
          ]),
          const SizedBox(height: 6),
          CountUp(today.revenue, style: const TextStyle(color: AppColors.ink, fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _heroStat(Icons.receipt_long_rounded, '${today.count} عملية'),
            _heroStat(Icons.sim_card_rounded, '${today.byType[InvoiceType.line]?.count ?? 0} خط'),
            if (Session.instance.isAdmin) _heroStat(Icons.savings_rounded, 'ربح ${money(today.grossProfit)}'),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(child: _money('المستلم', today.received)),
              Expanded(child: _money('المصروفات', today.expenses)),
              Expanded(child: _money('بالصندوق', today.cash)),
            ]),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Pressable(
              onTap: () => confirmShiftReset(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Session.instance.isAdmin ? Icons.restart_alt_rounded : Icons.lock_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 6),
                  const Text('تصفير الوردية', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: .96, end: 1, curve: Curves.easeOutCubic);
  }

  Widget _money(String label, int v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: AppColors.ink.withValues(alpha: .7), fontSize: 12, fontWeight: FontWeight.w700)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(money(v), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ]);

  Widget _heroStat(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 18, color: AppColors.ink.withValues(alpha: .75)),
        const SizedBox(width: 4),
        Text(t, style: TextStyle(color: AppColors.ink.withValues(alpha: .85), fontWeight: FontWeight.w700)),
      ]);
}

class _StatsGrid extends StatelessWidget {
  final _DashData d;
  const _StatsGrid({required this.d});

  @override
  Widget build(BuildContext context) {
    final inShop = d.repairs.entries.where((e) => e.key.isOpen).fold<int>(0, (s, e) => s + e.value);
    final items = [
      _StatItem('مبيعات المنتجات', money(d.today.byType[InvoiceType.sale]?.total ?? 0), Icons.shopping_bag_rounded, AppColors.info, Section.pos),
      _StatItem('مبيعات الخطوط', money(d.today.byType[InvoiceType.line]?.total ?? 0), Icons.sim_card_rounded, AppColors.asiacell, Section.lines),
      _StatItem('أجهزة بالصيانة', '$inShop جهاز', Icons.build_circle_rounded, AppColors.warning, Section.repairs),
      _StatItem('ديون مستحقة', money(d.debts.$2), Icons.menu_book_rounded, const Color(0xFFEC4899), Section.debts),
      _StatItem('نواقص المخزن', '${d.lowStock} صنف', Icons.warning_amber_rounded, AppColors.danger, Section.inventory),
      _StatItem('المصروفات', money(d.today.expenses), Icons.account_balance_wallet_rounded, const Color(0xFFF97316), Section.expenses),
    ];
    return LayoutBuilder(builder: (c, cons) {
      final cols = cons.maxWidth > 560 ? 3 : 2;
      final w = (cons.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: w,
            child: AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => ShellNav.go(items[i].go),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconBadge(icon: items[i].icon, color: items[i].color, size: 40),
                const SizedBox(height: 10),
                Text(items[i].label, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(items[i].value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
            ).stagger(i),
          ),
      ]);
    });
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  final Section go;
  _StatItem(this.label, this.value, this.icon, this.color, this.go);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, Color, VoidCallback)>[
      ('بيع منتجات', Icons.point_of_sale_rounded, AppColors.info, () => ShellNav.go(Section.pos)),
      ('بيع خط', Icons.sim_card_rounded, AppColors.asiacell, () => showLineSaleSheet(context)),
      ('استلام جهاز', Icons.build_circle_rounded, AppColors.warning, () => showRepairForm(context)),
      ('إضافة منتج', Icons.add_box_rounded, AppColors.purple, () => showProductForm(context)),
      ('دين / طلب', Icons.post_add_rounded, const Color(0xFFEC4899), () => showDebtSheet(context)),
      ('مصروف', Icons.account_balance_wallet_rounded, const Color(0xFFF97316), () => showExpenseSheet(context)),
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('عمليات سريعة'),
        LayoutBuilder(builder: (c, cons) {
          final cols = cons.maxWidth > 420 ? 6 : 3;
          final w = (cons.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(spacing: 8, runSpacing: 12, children: [
            for (var i = 0; i < actions.length; i++)
              SizedBox(
                width: w,
                child: Pressable(
                  onTap: actions[i].$4,
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [actions[i].$3, actions[i].$3.withValues(alpha: .7)]),
                        boxShadow: [BoxShadow(color: actions[i].$3.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 5))],
                      ),
                      child: Icon(actions[i].$2, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(actions[i].$1, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fadeIn(delay: (50 * i).ms).scaleXY(begin: .7, end: 1, curve: Curves.easeOutBack),
              ),
          ]);
        }),
      ]),
    );
  }
}
