import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/reports_repo.dart';

enum _Period { today, week, month, period, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _p = _Period.today;
  DateTimeRange? _custom;

  Future<(DateTime, DateTime)> _range() async {
    final now = DateTime.now();
    final t0 = startOfDay(now);
    final end = t0.add(const Duration(days: 1));
    return switch (_p) {
      _Period.today => (await ReportsRepo.shiftStart(), end),
      _Period.week => (t0.subtract(const Duration(days: 6)), end),
      _Period.month => (DateTime(now.year, now.month), end),
      _Period.period => (DateTime.fromMillisecondsSinceEpoch((await ReportsRepo.currentPeriod()).startedAt), end),
      _Period.custom => (_custom!.start, _custom!.end.add(const Duration(days: 1))),
    };
  }

  @override
  Widget build(BuildContext context) {
    return DataView<(ReportSummary, List<(DateTime, int)>, List<Period>, (DateTime, DateTime))>(
      reloadKey: '$_p-$_custom',
      load: () async {
        final r = await _range();
        return (await ReportsRepo.summary(r.$1, r.$2), await ReportsRepo.daily(30), await ReportsRepo.closedPeriods(), r);
      },
      builder: (context, d) {
        final (s, daily, periods, range) = d;
        final types = [InvoiceType.sale, InvoiceType.line, InvoiceType.repair];
        final maxType = types.fold<int>(0, (m, t) => (s.byType[t]?.total ?? 0) > m ? s.byType[t]!.total : m);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final p in _Period.values) ...[
                  ChoiceChip(
                    label: Text(switch (p) {
                      _Period.today => 'الوردية الحالية',
                      _Period.week => '7 أيام',
                      _Period.month => 'هذا الشهر',
                      _Period.period => 'منذ آخر تصفير',
                      _Period.custom => _custom == null ? 'فترة مخصصة' : '${dateStr(_custom!.start)} - ${dateStr(_custom!.end)}',
                    }),
                    selected: _p == p,
                    onSelected: (_) async {
                      if (p == _Period.custom) {
                        final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
                        if (r == null) return;
                        _custom = r;
                      }
                      setState(() => _p = p);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (c, cons) {
              final cols = cons.maxWidth > 700 ? 3 : 2;
              final w = (cons.maxWidth - (cols - 1) * 12) / cols;
              final tiles = [
                ('الإيرادات', s.revenue, Icons.payments_rounded, AppColors.gold),
                ('إجمالي الربح', s.grossProfit, Icons.trending_up_rounded, AppColors.success),
                ('المصروفات', s.expenses, Icons.account_balance_wallet_rounded, const Color(0xFFF97316)),
                ('صافي الربح', s.netProfit, Icons.savings_rounded, s.netProfit >= 0 ? AppColors.teal : AppColors.danger),
                ('المستلم', s.received, Icons.account_balance_wallet_rounded, AppColors.info),
                ('الصافي بالصندوق', s.cash, Icons.point_of_sale_rounded, const Color(0xFF8B5CF6)),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < tiles.length; i++)
                  SizedBox(
                    width: w,
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        IconBadge(icon: tiles[i].$3, color: tiles[i].$4, size: 38),
                        const SizedBox(height: 8),
                        Text(tiles[i].$1, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: CountUp(tiles[i].$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ).stagger(i),
                  ),
              ]);
            }),
            const SizedBox(height: 6),
            Text('${s.count} عملية بيع • ديون محصلة ${money(s.collectedDebts)} • ${dateStr(range.$1)} ← ${dateStr(range.$2.subtract(const Duration(days: 1)))}',
                style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 14),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('المبيعات حسب القسم'),
                for (final t in types)
                  ShareBar(
                    label: '${t.label} (${s.byType[t]?.count ?? 0})',
                    value: s.byType[t]?.total ?? 0,
                    max: maxType,
                    color: t.color,
                    trailing: money(s.byType[t]?.total ?? 0),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('المبيعات اليومية', subtitle: 'آخر 30 يوماً — اضغط على أي عمود'),
                DailyBars(data: daily, height: 170),
              ]),
            ),
            const SizedBox(height: 14),
            _listCard(context, 'الخطوط حسب النوع', s.lineTypes.map((e) => (e.$1, '${e.$2} خط', money(e.$3))).toList()),
            _listCard(context, 'الأكثر مبيعاً', s.topProducts.map((e) => (e.$1, '${e.$2} قطعة', money(e.$3))).toList()),
            _listCard(context, 'أداء الموظفين', s.byEmployee.map((e) => (e.$1, '${e.$2} عملية', money(e.$3))).toList()),
            _listCard(context, 'المصروفات حسب البند', s.expensesByCat.map((e) => (e.$1, '', money(e.$2))).toList()),
            if (periods.isNotEmpty)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('أرشيف الأشهر المصفّرة'),
                  for (final p in periods) _PeriodRow(p),
                ]),
              ),
          ],
        );
      },
    );
  }

  Widget _listCard(BuildContext context, String title, List<(String, String, String)> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(title),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
                Expanded(child: Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (rows[i].$2.isNotEmpty) Text(rows[i].$2, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
                const SizedBox(width: 12),
                Text(rows[i].$3, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final Period p;
  const _PeriodRow(this.p);
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> s = {};
    try {
      s = jsonDecode(p.summary) as Map<String, dynamic>;
    } catch (_) {}
    int v(String k) => (s[k] as num?)?.toInt() ?? 0;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const IconBadge(icon: Icons.archive_rounded, color: AppColors.gold, size: 38),
      title: Text('${dateMs(p.startedAt)} ← ${p.closedAt == null ? '' : dateMs(p.closedAt!)}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('الإيرادات ${money(v('revenue'))} • صفّرها ${p.closedBy}'),
      children: [
        InfoRow('الخطوط', '${v('lines')} خط • ${money(v('lines_total'))}'),
        InfoRow('بيع المنتجات', money(v('sales_total'))),
        InfoRow('الصيانة', money(v('repairs_total'))),
        InfoRow('الربح', money(v('profit'))),
        InfoRow('المصروفات', money(v('expenses'))),
        InfoRow('صافي الربح', money(v('net')), bold: true),
      ],
    );
  }
}
