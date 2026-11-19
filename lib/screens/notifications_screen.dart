import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/notifications_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Color _color(String level) {
    switch (level) {
      case 'danger':
        return Brand.danger;
      case 'warning':
        return Brand.warning;
      case 'success':
        return Brand.good;
      default:
        return Brand.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & messages'),
        actions: [
          if (state.unread > 0)
            TextButton.icon(
              onPressed: state.markAllRead,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (state.error != null && state.items.isEmpty) ErrorBanner(state.error!, onRetry: state.fetch),
            if (state.loading && state.items.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No messages yet',
                message: 'You will be told here (and on your phone) when a device goes online or offline, '
                    'and when a gas, smoke, leak, motion or door sensor raises an alert.',
              ),
            for (final n in state.items) ...[
              _Tile(n: n, color: _color(n.level)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n, required this.color});

  final AppNotification n;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: n.read ? null : fade(Brand.yellow, 0.10),
      border: n.read ? null : fade(Brand.yellow, 0.5),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(n.icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.body, style: const TextStyle(color: Brand.muted, fontSize: 13, height: 1.35)),
                ],
                const SizedBox(height: 4),
                Text(timeAgo(n.createdAt), style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
