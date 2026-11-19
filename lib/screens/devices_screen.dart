import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_device_screen.dart';
import 'configure_screen.dart';
import 'device_settings_screen.dart';

/// Manage devices: list, add, settings, and devices waiting for deletion.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DevicesState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.yellow,
        foregroundColor: Brand.navy,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDeviceScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add device', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refresh(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            if (state.error != null) ErrorBanner(state.error!, onRetry: () => state.refresh()),
            if (state.devices.isEmpty && state.loadedOnce)
              const EmptyState(
                icon: Icons.developer_board_off_rounded,
                title: 'No devices yet',
                message: 'Tap "Add device" and choose your device model.',
              ),
            for (final d in state.devices) ...[
              _DeviceRow(device: d),
              const SizedBox(height: 10),
            ],
            if (state.pending.isNotEmpty) ...[
              const SectionTitle('Waiting for deletion', icon: Icons.auto_delete_rounded),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'Deleted devices are kept for 15 days or until an administrator confirms. Restore one to use it again.',
                  style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.4),
                ),
              ),
              for (final d in state.pending) ...[
                _PendingRow(device: d),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final color = !d.enabled ? Brand.muted : (d.online ? Brand.good : Brand.danger);
    return Panel(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceSettingsScreen(deviceId: d.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(Icons.developer_board_rounded, color: d.enabled ? Brand.navy : Brand.muted, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(d.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  ],
                ),
              ),
              StatusPill(!d.enabled ? 'Deactivated' : (d.online ? 'Online' : 'Offline'), color: color, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(Icons.memory_rounded, d.model?.name ?? 'No model'),
              _Meta(Icons.qr_code_rounded, d.serial),
              _Meta(Icons.cable_rounded, '${d.inputs.length} in · ${d.outputs.length} out'),
              _Meta(Icons.schedule_rounded, 'Seen ${timeAgo(d.lastSeen)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigureScreen(deviceId: d.id))),
                  icon: const Icon(Icons.settings_input_component_rounded, size: 18),
                  label: const Text('Configure'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceSettingsScreen(deviceId: d.id))),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Brand.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12.5, color: Brand.text, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PendingRow extends StatefulWidget {
  const _PendingRow({required this.device});

  final Device device;

  @override
  State<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends State<_PendingRow> {
  bool _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await context.read<DevicesState>().restore(widget.device.id);
      if (mounted) showToast(context, '${widget.device.displayName} restored');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final days = d.purgeDueAt?.difference(DateTime.now()).inDays;
    return Panel(
      color: fade(Brand.warning, 0.05),
      border: fade(Brand.warning, 0.3),
      child: Row(
        children: [
          const IconBadge(Icons.auto_delete_rounded, color: Brand.warning, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  days == null ? d.serial : 'Removed on ${formatDate(d.purgeDueAt)} (${days < 0 ? 0 : days} days left)',
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
              : TextButton.icon(onPressed: _restore, icon: const Icon(Icons.restore_rounded), label: const Text('Restore')),
        ],
      ),
    );
  }
}
