import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_card.dart';
import 'add_device_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenDevices});

  final VoidCallback onOpenDevices;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _query = '';
  String _filter = 'all';
  bool _searching = false;

  List<Device> _visible(List<Device> devices) {
    final q = _query.trim().toLowerCase();
    return devices.where((d) {
      if (_filter == 'online' && !d.online) return false;
      if (_filter == 'offline' && (d.online || !d.enabled)) return false;
      if (_filter == 'alerts' && d.alerts == 0) return false;
      if (q.isEmpty) return true;
      final hay = [d.displayName, d.location, d.serial, ...d.points.map((p) => '${p.name} ${p.location}')].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DevicesState>();
    final user = context.select<AuthState, String>((a) => a.user?.firstName ?? '');
    final devices = _visible(state.devices);

    return RefreshIndicator(
      onRefresh: () => state.refresh(silent: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Hero(name: user, stats: state.stats, updatedAt: state.updatedAt, loading: state.loading)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    state.fromCache
                        ? 'No connection to the server. Showing saved devices; those on your Wi-Fi can still be controlled.'
                        : state.error!,
                    onRetry: () => state.refresh(),
                  ),
                ],
                SectionTitle(
                  'My devices',
                  icon: Icons.developer_board_rounded,
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Search',
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                    icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: Brand.muted),
                  ),
                ),
                if (_searching) ...[
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: fieldDecoration('Search device, room or sensor', icon: Icons.search_rounded),
                  ),
                  const SizedBox(height: 10),
                ],
                if (state.devices.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in const [('all', 'All'), ('online', 'Online'), ('offline', 'Offline'), ('alerts', 'Alerts')])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f.$2),
                              selected: _filter == f.$1,
                              onSelected: (_) => setState(() => _filter = f.$1),
                              showCheckmark: false,
                              selectedColor: fade(Brand.blue, 0.15),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _filter == f.$1 ? Brand.blue : Brand.text,
                              ),
                              side: BorderSide(color: _filter == f.$1 ? fade(Brand.blue, 0.5) : Brand.line),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (!state.loadedOnce && state.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.devices.isEmpty && state.error == null)
                  EmptyState(
                    icon: Icons.add_home_work_rounded,
                    title: 'Add your first device',
                    message: 'Register your controller with its model, serial number and where it is installed. '
                        'Then add the sensors and actuators connected to it.',
                    action: FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDeviceScreen())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add device'),
                    ),
                  )
                else if (devices.isEmpty)
                  const EmptyState(icon: Icons.filter_alt_off_rounded, title: 'Nothing here', message: 'No device matches this filter.')
                else
                  for (final d in devices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DeviceCard(key: ValueKey('device-${d.id}'), device: d, initiallyOpen: state.devices.length == 1),
                    ),
                if (state.pending.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Panel(
                    onTap: widget.onOpenDevices,
                    color: fade(Brand.warning, 0.07),
                    border: fade(Brand.warning, 0.3),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_delete_rounded, color: Brand.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${state.pending.length} device${state.pending.length == 1 ? ' is' : 's are'} waiting for deletion. '
                            'Open Devices to restore.',
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Brand.muted),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.stats, required this.updatedAt, required this.loading});

  final String name;
  final DashboardStats stats;
  final DateTime? updatedAt;
  final bool loading;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: Brand.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? _greeting : '$_greeting, $name',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      loading ? 'Updating…' : 'Updated ${timeAgo(updatedAt)}',
                      style: TextStyle(color: fade(Colors.white, 0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Brand.yellow, foregroundColor: Brand.navy),
                tooltip: 'Add device',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDeviceScreen())),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Kpi(icon: Icons.wifi_rounded, value: '${stats.online}/${stats.devices}', label: 'Online', color: Brand.good),
              const SizedBox(width: 10),
              _Kpi(icon: Icons.sensors_rounded, value: '${stats.sensors}', label: 'Sensors', color: const Color(0xFF7CC4FF)),
              const SizedBox(width: 10),
              _Kpi(icon: Icons.power_rounded, value: '${stats.outputsOn}/${stats.actuators}', label: 'Outputs on', color: Brand.yellow),
              const SizedBox(width: 10),
              _Kpi(
                icon: Icons.warning_amber_rounded,
                value: '${stats.alerts}',
                label: 'Alerts',
                color: stats.alerts > 0 ? const Color(0xFFFF7B7B) : fade(Colors.white, 0.7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.value, required this.label, required this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: fade(Colors.white, 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fade(Colors.white, 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fade(Colors.white, 0.72), fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
