import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../core/license_crypto.dart';
import '../../data/repos/users_repo.dart';
import '../../services/license.dart';
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
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => showPinRecovery(context),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('نسيت الرمز السري؟'),
                  ),
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

/// استرجاع رمز المدير عند نسيانه: الزبون يرسل رمز الجهاز للمطور
/// فيعطيه كود استرجاع يمكّنه من تعيين رمز جديد دون فقد أي بيانات.
Future<void> showPinRecovery(BuildContext context) =>
    showAppSheet(context, const _PinRecovery(), maxWidth: 460);

class _PinRecovery extends StatefulWidget {
  const _PinRecovery();
  @override
  State<_PinRecovery> createState() => _PinRecoveryState();
}

class _PinRecoveryState extends State<_PinRecovery> {
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _verified = false;
  String? _error;
  List<AppUser> _admins = [];
  AppUser? _target;

  LicenseService get lic => LicenseService.instance;

  Future<void> _check() async {
    if (verifyReset(lic.deviceId, _code.text)) {
      final a = await UsersRepo.admins();
      if (!mounted) return;
      setState(() {
        _verified = true;
        _admins = a;
        _target = a.isNotEmpty ? a.first : null;
        _error = null;
      });
    } else {
      setState(() => _error = 'كود الاسترجاع غير صحيح أو لا يخص هذا الجهاز');
    }
  }

  Future<void> _apply() async {
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'الرمز الجديد يجب أن يكون أربعة أرقام');
      return;
    }
    if (_pin.text != _pin2.text) {
      setState(() => _error = 'الرمز غير متطابق');
      return;
    }
    if (_target == null) return;
    await UsersRepo.resetPin(_target!.id, _pin.text);
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, 'تم تعيين رمز جديد لحساب ${_target!.name} — سجل الدخول به الآن');
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration pinDeco(String l) =>
        InputDecoration(labelText: l, counterText: '', prefixIcon: const Icon(Icons.lock_rounded));
    return SheetScaffold(
      title: 'استرجاع رمز المدير',
      icon: Icons.lock_reset_rounded,
      footer: _verified
          ? FilledButton.icon(onPressed: _apply, icon: const Icon(Icons.check_rounded), label: const Text('تعيين الرمز الجديد'))
          : FilledButton.icon(onPressed: _check, icon: const Icon(Icons.verified_user_rounded), label: const Text('تحقق من الكود')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_verified) ...[
          Text('إذا نسيت رمز المدير أرسل رمز الجهاز أدناه إلى المطور عبر واتساب '
              'ليعطيك كود استرجاع\nبياناتك تبقى محفوظة بالكامل',
              style: TextStyle(color: context.cs.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 16),
          Text('رمز الجهاز', style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: lic.deviceIdShown));
              toast(context, 'تم نسخ رمز الجهاز');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cs.outline),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(lic.deviceIdShown,
                      textDirection: TextDirection.ltr, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                ),
                Icon(Icons.copy_rounded, size: 20, color: context.cs.onSurfaceVariant),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
            inputFormatters: [_RecoveryFormatter()],
            decoration: InputDecoration(
              hintText: 'XXXXX-XXXXX',
              hintTextDirection: TextDirection.ltr,
              labelText: 'كود الاسترجاع',
              prefixIcon: const Icon(Icons.vpn_key_rounded),
              errorText: _error,
            ),
          ),
        ] else ...[
          Row(children: [
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(width: 8),
            const Expanded(child: Text('تم التحقق — عيّن رمزا جديدا', style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 14),
          if (_admins.length > 1) ...[
            const Text('اختر حساب المدير', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in _admins)
                ChoiceChip(label: Text(a.name), selected: _target?.id == a.id, onSelected: (_) => setState(() => _target = a)),
            ]),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _pin,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: pinDeco('الرمز الجديد (أربعة أرقام)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pin2,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: pinDeco('تأكيد الرمز الجديد'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
        ],
      ]),
    );
  }
}

class _RecoveryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = normalizeCode(newValue.text);
    final limited = clean.length > 10 ? clean.substring(0, 10) : clean;
    final text = limited.length > 5 ? '${limited.substring(0, 5)}-${limited.substring(5)}' : limited;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
