import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../main.dart';
import '../state/auth_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _user;
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;
  bool _errorIsWarning = false;

  @override
  void initState() {
    super.initState();
    _user = TextEditingController(text: context.read<AuthState>().lastUsername);
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(_user.text, _pass.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorIsWarning = e.code == 'inactive';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String path) async {
    final server = context.read<AuthState>().server;
    await launchUrl(Uri.parse('$server$path'), mode: LaunchMode.externalApplication);
  }

  Future<void> _serverSettings() async {
    final auth = context.read<AuthState>();
    final ctrl = TextEditingController(text: auth.server);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Server', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Leave the default unless our team gave you another address.', style: TextStyle(color: Brand.muted)),
            const SizedBox(height: 14),
            TextField(controller: ctrl, keyboardType: TextInputType.url, decoration: fieldDecoration('Server address', icon: Icons.dns_rounded)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, AppConfig.defaultServer), child: const Text('Use default')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) await auth.setServer(value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final notice = auth.notice;
    return Scaffold(
      backgroundColor: Brand.navy,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.hero),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(child: BrandMark(size: 68)),
                    const SizedBox(height: 18),
                    const Text('Smart Home',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(AppConfig.company,
                        textAlign: TextAlign.center, style: TextStyle(color: fade(Colors.white, 0.75), fontSize: 14)),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: fade(Colors.black, 0.18), blurRadius: 30, offset: const Offset(0, 12))],
                      ),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text('Use the same account as the website.', style: TextStyle(color: Brand.muted)),
                            const SizedBox(height: 18),
                            if (notice != null && _error == null) ...[
                              _Message(notice, warning: true),
                              const SizedBox(height: 14),
                            ],
                            if (_error != null) ...[
                              _Message(_error!, warning: _errorIsWarning),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _user,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: fieldDecoration('Username', icon: Icons.person_rounded),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pass,
                              obscureText: _hide,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: fieldDecoration(
                                'Password',
                                icon: Icons.lock_rounded,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _hide = !_hide),
                                  icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _open('/home/password-reset/'),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                                  : const Text('Sign in'),
                            ),
                            if (_busy)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text('The first sign-in can take up to a minute while the server wakes up.',
                                    textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                              ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _open('/signup/'),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Create an account on the website'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://wa.me/${AppConfig.supportPhone.replaceAll('+', '')}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.chat_rounded, color: Brand.yellow),
                          label: const Text('Need help?', style: TextStyle(color: Colors.white)),
                        ),
                        TextButton.icon(
                          onPressed: _serverSettings,
                          icon: Icon(Icons.dns_rounded, color: fade(Colors.white, 0.7)),
                          label: Text('Server', style: TextStyle(color: fade(Colors.white, 0.7))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? Brand.warning : Brand.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fade(color, 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning ? Icons.hourglass_top_rounded : Icons.error_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Brand.text, height: 1.35))),
        ],
      ),
    );
  }
}
