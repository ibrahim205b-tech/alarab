import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/users_repo.dart';
import '../../services/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<AppUser> _users = [];
  AppUser? _selected;
  final _pad = GlobalKey<PinPadState>();

  @override
  void initState() {
    super.initState();
    UsersRepo.all(activeOnly: true).then((u) {
      if (!mounted) return;
      setState(() {
        _users = u;
        if (u.length == 1) _selected = u.first;
      });
    });
  }

  Future<void> _submit(String pin) async {
    final u = _selected;
    if (u == null) return;
    if (await UsersRepo.verify(u.id, pin)) {
      HapticFeedback.mediumImpact();
      Session.instance.login(u);
    } else {
      _pad.currentState?.shakeError();
      if (mounted) toast(context, 'الرمز غير صحيح', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.w > 820;
    final brand = Column(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: wide ? 120 : 84),
      const SizedBox(height: 18),
      BrandTitle(size: wide ? 34 : 26),
    ]);

    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('من يعمل الآن؟', style: TextStyle(fontSize: 16, color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _users.length; i++)
              _UserChip(
                user: _users[i],
                selected: _selected?.id == _users[i].id,
                onTap: () {
                  setState(() => _selected = _users[i]);
                  _pad.currentState?.reset();
                },
              ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: .2, end: 0),
          ],
        ),
        const SizedBox(height: 26),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _selected == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('اختر اسمك للمتابعة', style: TextStyle(color: context.cs.onSurfaceVariant)),
                )
              : Column(key: ValueKey(_selected!.id), children: [
                  Text('أدخل الرمز السري', style: TextStyle(color: context.cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  PinPad(key: _pad, onComplete: _submit),
                ]),
        ),
      ]),
    );

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: wide
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Expanded(child: brand),
                      const SizedBox(width: 40),
                      Expanded(child: Center(child: panel.animate().fadeIn(delay: 250.ms).slideX(begin: -.06, end: 0))),
                    ])
                  : Column(children: [
                      brand,
                      const SizedBox(height: 36),
                      panel.animate().fadeIn(delay: 250.ms).slideY(begin: .08, end: 0),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  final AppUser user;
  final bool selected;
  final VoidCallback onTap;
  const _UserChip({required this.user, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = user.isAdmin ? AppColors.gold : AppColors.teal;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? color.withValues(alpha: .18) : context.cs.surfaceContainer,
          border: Border.all(color: selected ? color : context.cs.outline, width: selected ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .25),
            child: Text(user.name.characters.first, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(user.roleLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
