import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand.dart';
import '../../core/widgets.dart';
import '../../data/repos/settings_repo.dart';
import '../../data/repos/users_repo.dart';
import '../../services/session.dart';

/// الإعداد الأول: إنشاء حساب المدير
class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shop = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await SettingsRepo.instance.setMany({'shop_name': _shop.text.trim(), 'shop_phone': _phone.text.trim()});
    final u = await UsersRepo.create(_name.text, _pin.text, 'admin');
    Session.instance.login(u);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: BrandMark(size: 92)),
                    const SizedBox(height: 18),
                    const Center(child: BrandTitle()),
                    const SizedBox(height: 28),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('أهلاً بك 👋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('أدخل اسم محلك واسمك لتبدأ. المدير وحده يستطيع التعديل والحذف.',
                            style: TextStyle(color: context.cs.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _shop,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'اسم المحل', hintText: 'مثال: محل النور للموبايلات', prefixIcon: Icon(Icons.storefront_rounded)),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم هاتف المحل (للفواتير)', prefixIcon: Icon(Icons.call_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'اسمك (المدير)', hintText: 'مثال: أحمد', prefixIcon: Icon(Icons.person_rounded)),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pin,
                              obscureText: true,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'رمز سري (4 أرقام)', counterText: '', prefixIcon: Icon(Icons.lock_rounded)),
                              validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '') ? null : '4 أرقام',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pin2,
                              obscureText: true,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'تأكيد الرمز', counterText: '', prefixIcon: Icon(Icons.lock_outline_rounded)),
                              validator: (v) => v == _pin.text ? null : 'غير متطابق',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.rocket_launch_rounded),
                          label: const Text('ابدأ العمل'),
                        ),
                      ]),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: .1, end: 0, curve: Curves.easeOutCubic),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
