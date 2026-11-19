import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/auth_state.dart';
import '../state/devices_state.dart';
import '../state/notifications_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showToast(context, 'Could not open ${uri.scheme} link', error: true);
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirm(context, title: 'Sign out?', message: 'You will need your password to sign in again.', confirmLabel: 'Sign out');
    if (!ok || !context.mounted) return;
    final devices = context.read<DevicesState>();
    final notes = context.read<NotificationsState>();
    await context.read<AuthState>().logout();
    devices.reset();
    notes.reset();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final server = auth.server;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Panel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Brand.navy,
                  child: Text(user?.initials ?? '?', style: const TextStyle(color: Brand.yellow, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Signed in', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(user == null ? '' : '@${user.username}', style: const TextStyle(color: Brand.muted)),
                      if (user != null && user.email.isNotEmpty) Text(user.email, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                      if (user != null && user.accountTypeLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        StatusPill(user.accountTypeLabel, color: Brand.blue, icon: Icons.verified_user_rounded, dense: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Help & support', icon: Icons.support_agent_rounded),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  icon: Icons.chat_rounded,
                  color: const Color(0xFF25D366),
                  title: 'WhatsApp',
                  subtitle: AppConfig.supportPhoneDisplay,
                  onTap: () => _launch(context, Uri.parse('https://wa.me/${AppConfig.supportPhone.replaceAll('+', '')}')),
                ),
                const Divider(height: 1, indent: 64),
                _Tile(
                  icon: Icons.call_rounded,
                  title: 'Call us',
                  subtitle: AppConfig.supportPhoneDisplay,
                  onTap: () => _launch(context, Uri.parse('tel:${AppConfig.supportPhone}')),
                ),
                const Divider(height: 1, indent: 64),
                _Tile(
                  icon: Icons.mail_rounded,
                  title: 'Email',
                  subtitle: AppConfig.supportEmail,
                  onTap: () => _launch(context, Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=Smart Home app help')),
                ),
                const Divider(height: 1, indent: 64),
                _Tile(
                  icon: Icons.smart_toy_rounded,
                  title: 'AI help portal',
                  subtitle: 'Ask questions about your system',
                  onTap: () => _launch(context, Uri.parse('$server/help/')),
                ),
              ],
            ),
          ),
          const SectionTitle('Website', icon: Icons.public_rounded),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(
                  icon: Icons.dashboard_customize_rounded,
                  title: 'Open the web dashboard',
                  subtitle: 'Logs, full configuration and more',
                  onTap: () => _launch(context, Uri.parse('$server/home/')),
                ),
                const Divider(height: 1, indent: 64),
                _Tile(
                  icon: Icons.business_rounded,
                  title: AppConfig.company,
                  subtitle: 'Company website',
                  onTap: () => _launch(context, Uri.parse('$server/')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Brand.danger, side: BorderSide(color: fade(Brand.danger, 0.4))),
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 18),
          Text(
            '${AppConfig.appName} 1.0 · $server',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color = Brand.blue});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: IconBadge(icon, color: color, size: 40),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded, color: Brand.muted),
      onTap: onTap,
    );
  }
}
