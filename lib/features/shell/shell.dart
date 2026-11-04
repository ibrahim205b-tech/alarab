import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/session.dart';
import '../admin/admin_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../debts/debt_sheet.dart';
import '../debts/debts_screen.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/inventory_screen.dart';
import '../invoices/invoices_screen.dart';
import '../lines/lines_screen.dart';
import '../pos/pos_screen.dart';
import '../protectors/protectors_screen.dart';
import '../repairs/repairs_screen.dart';
import '../reports/reports_screen.dart';

enum Section { dashboard, pos, lines, repairs, inventory, debts, protectors, invoices, expenses, reports, admin }

extension SectionX on Section {
  String get title => switch (this) {
        Section.dashboard => 'الرئيسية',
        Section.pos => 'نقطة البيع',
        Section.lines => 'الخطوط والخدمات',
        Section.repairs => 'الصيانة',
        Section.inventory => 'المخزن',
        Section.debts => 'الديون والطلبات',
        Section.protectors => 'توافقات اللاصقات',
        Section.invoices => 'الفواتير',
        Section.expenses => 'المصروفات',
        Section.reports => 'التقارير',
        Section.admin => 'الإدارة',
      };
  String get short => switch (this) {
        Section.pos => 'البيع',
        Section.lines => 'الخطوط',
        Section.debts => 'الديون',
        Section.protectors => 'التوافقات',
        _ => title,
      };
  IconData get icon => switch (this) {
        Section.dashboard => Icons.space_dashboard_rounded,
        Section.pos => Icons.point_of_sale_rounded,
        Section.lines => Icons.sim_card_rounded,
        Section.repairs => Icons.build_circle_rounded,
        Section.inventory => Icons.inventory_2_rounded,
        Section.debts => Icons.menu_book_rounded,
        Section.protectors => Icons.shield_rounded,
        Section.invoices => Icons.receipt_long_rounded,
        Section.expenses => Icons.account_balance_wallet_rounded,
        Section.reports => Icons.insights_rounded,
        Section.admin => Icons.admin_panel_settings_rounded,
      };
  Color get color => switch (this) {
        Section.dashboard => AppColors.gold,
        Section.pos => AppColors.info,
        Section.lines => AppColors.asiacell,
        Section.repairs => AppColors.warning,
        Section.inventory => AppColors.purple,
        Section.debts => const Color(0xFFEC4899),
        Section.protectors => AppColors.teal,
        Section.invoices => AppColors.success,
        Section.expenses => const Color(0xFFF97316),
        Section.reports => const Color(0xFF0EA5E9),
        Section.admin => AppColors.gold,
      };
  bool get adminOnly => this == Section.reports || this == Section.admin;
}

/// للتنقل بين الأقسام من أي مكان
class ShellNav {
  static final current = ValueNotifier<Section>(Section.dashboard);
  static void go(Section s) => current.value = s;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    ShellNav.current.value = Section.dashboard;
  }

  Future<void> _select(Section s) async {
    if (s == ShellNav.current.value) return;
    if (s.adminOnly && !await AdminGate.require(context, reason: 'قسم ${s.title} خاص بالمدير')) return;
    ShellNav.go(s);
  }

  Widget _page(Section s) => switch (s) {
        Section.dashboard => const DashboardScreen(),
        Section.pos => const PosScreen(),
        Section.lines => const LinesScreen(),
        Section.repairs => const RepairsScreen(),
        Section.inventory => const InventoryScreen(),
        Section.debts => const DebtsScreen(),
        Section.protectors => const ProtectorsScreen(),
        Section.invoices => const InvoicesScreen(),
        Section.expenses => const ExpensesScreen(),
        Section.reports => const ReportsScreen(),
        Section.admin => const AdminScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Section>(
      valueListenable: ShellNav.current,
      builder: (context, section, _) {
        final wide = context.w >= 900;
        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .025), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(section), child: _page(section)),
        );

        final content = Column(children: [
          _TopBar(section: section),
          Expanded(child: body),
        ]);

        if (wide) {
          return Scaffold(
            body: Row(children: [
              _SideNav(current: section, onSelect: _select),
              Expanded(child: SafeArea(left: false, right: false, child: content)),
            ]),
          );
        }

        const mainTabs = [Section.dashboard, Section.pos, Section.lines, Section.repairs];
        final idx = mainTabs.contains(section) ? mainTabs.indexOf(section) : 4;
        return Scaffold(
          body: SafeArea(bottom: false, child: content),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) {
              if (i < 4) {
                _select(mainTabs[i]);
              } else {
                _showMore(section);
              }
            },
            destinations: [
              for (final s in mainTabs) NavigationDestination(icon: Icon(s.icon), label: s.short),
              NavigationDestination(
                icon: Icon(idx == 4 ? section.icon : Icons.grid_view_rounded),
                label: idx == 4 ? section.short : 'المزيد',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMore(Section current) {
    const more = [
      Section.inventory, Section.debts, Section.protectors, Section.invoices,
      Section.expenses, Section.reports, Section.admin, Section.dashboard,
    ];
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .85,
            children: [
              for (var i = 0; i < more.length; i++)
                Pressable(
                  onTap: () {
                    Navigator.pop(c);
                    _select(more[i]);
                  },
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconBadge(icon: more[i].icon, color: more[i].color, size: 54),
                    const SizedBox(height: 8),
                    Text(more[i].short,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: more[i] == current ? c.cs.primary : null)),
                    if (more[i].adminOnly) Icon(Icons.lock_rounded, size: 12, color: c.cs.onSurfaceVariant),
                  ]),
                ).stagger(i, step: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Section section;
  const _TopBar({required this.section});

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user!;
    final compact = context.w < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, 6),
      child: Row(children: [
        if (context.w < 900) ...[
          const BrandMark(size: 38, animate: false),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.05, 0), end: Offset.zero).animate(a), child: c)),
            child: Text(section.title,
                key: ValueKey(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 20 : 24, fontWeight: FontWeight.w800)),
          ),
        ),
        // زر الدين ظاهر دائماً بأعلى الشاشة
        _DebtButton(compact: compact),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'الحساب',
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (v) async {
            if (v == 'theme') ThemeController.instance.toggle();
            if (v == 'logout') Session.instance.logout();
          },
          itemBuilder: (c) => [
            PopupMenuItem(
              enabled: false,
              child: Row(children: [
                Icon(user.isAdmin ? Icons.verified_user_rounded : Icons.badge_rounded, color: c.cs.primary),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: TextStyle(fontWeight: FontWeight.w800, color: c.cs.onSurface)),
                  Text(user.roleLabel, style: TextStyle(fontSize: 12, color: c.cs.onSurfaceVariant)),
                ]),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'theme',
              child: Row(children: [
                Icon(c.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                const SizedBox(width: 10),
                Text(c.isDark ? 'الوضع الفاتح' : 'الوضع الداكن'),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [Icon(Icons.logout_rounded, color: AppColors.danger), SizedBox(width: 10), Text('تسجيل الخروج')]),
            ),
          ],
          child: CircleAvatar(
            radius: 21,
            backgroundColor: (user.isAdmin ? AppColors.gold : AppColors.teal).withValues(alpha: .2),
            child: Text(user.name.characters.first,
                style: TextStyle(fontWeight: FontWeight.w800, color: user.isAdmin ? AppColors.gold : AppColors.teal)),
          ),
        ),
      ]),
    );
  }
}

class _DebtButton extends StatelessWidget {
  final bool compact;
  const _DebtButton({required this.compact});
  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEC4899);
    return Pressable(
      onTap: () => showDebtSheet(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFBE185D)]),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.post_add_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(compact ? 'دين' : 'إضافة دين / طلب',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms).scaleXY(begin: .8, end: 1, curve: Curves.easeOutBack);
  }
}

class _SideNav extends StatelessWidget {
  final Section current;
  final ValueChanged<Section> onSelect;
  const _SideNav({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final extended = context.w >= 1150;
    return Container(
      width: extended ? 250 : 92,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.inkSurface : Colors.white,
        border: BorderDirectional(end: BorderSide(color: cs.outline.withValues(alpha: .5))),
      ),
      child: SafeArea(
        right: false,
        left: false,
        child: Column(children: [
          const SizedBox(height: 16),
          const BrandMark(size: 52),
          if (extended) ...[
            const SizedBox(height: 10),
            const Text('مبيعات علي العراب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < Section.values.length; i++)
                  _NavItem(
                    section: Section.values[i],
                    selected: current == Section.values[i],
                    extended: extended,
                    onTap: () => onSelect(Section.values[i]),
                  ).animate().fadeIn(delay: (25 * i).ms).slideX(begin: .2, end: 0),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Section section;
  final bool selected, extended;
  final VoidCallback onTap;
  const _NavItem({required this.section, required this.selected, required this.extended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = section.color;
    final item = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected ? c.withValues(alpha: .16) : Colors.transparent,
        border: Border.all(color: selected ? c.withValues(alpha: .5) : Colors.transparent),
      ),
      child: extended
          ? Row(children: [
              Icon(section.icon, color: selected ? c : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(section.title,
                    style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? cs.onSurface : cs.onSurfaceVariant)),
              ),
              if (section.adminOnly) Icon(Icons.lock_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: .6)),
            ])
          : Column(children: [
              Icon(section.icon, color: selected ? c : cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(section.short,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? cs.onSurface : cs.onSurfaceVariant)),
            ]),
    );
    return Pressable(onTap: onTap, child: Tooltip(message: section.title, child: item));
  }
}
