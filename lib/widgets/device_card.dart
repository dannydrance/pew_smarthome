import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/configure_screen.dart';
import '../screens/device_settings_screen.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import 'common.dart';
import 'point_widgets.dart';

/// Device in the dashboard list. Tapping opens it in place to show readings and controls.
class DeviceCard extends StatefulWidget {
  const DeviceCard({super.key, required this.device, this.initiallyOpen = false});

  final Device device;
  final bool initiallyOpen;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  late bool _open = widget.initiallyOpen;
  DevicesState? _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<DevicesState>();
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _state?.watch(widget.device.id));
    }
  }

  @override
  void dispose() {
    _state?.unwatch(widget.device.id);
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _state!.watch(widget.device.id);
    } else {
      _state!.unwatch(widget.device.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final mode = context.select<DevicesState, LinkMode>((s) => s.modeOf(d.id));
    final reachable = d.online || mode == LinkMode.local;
    final statusColor = !d.enabled ? Brand.muted : (reachable ? Brand.good : Brand.danger);
    final statusText = !d.enabled ? 'Deactivated' : (reachable ? 'Online' : 'Offline');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _open ? fade(Brand.blue, 0.45) : Brand.line),
        boxShadow: _open ? [BoxShadow(color: fade(Brand.navy, 0.08), blurRadius: 18, offset: const Offset(0, 6))] : null,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconBadge(Icons.developer_board_rounded, color: d.enabled ? Brand.navy : Brand.muted, size: 48, filled: d.enabled),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, size: 14, color: Brand.muted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(d.location.isEmpty ? 'No location' : d.location,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              StatusPill(statusText, color: statusColor, dense: true),
                              if (mode == LinkMode.local)
                                const StatusPill('Local Wi-Fi', color: Brand.good, icon: Icons.router_rounded, dense: true)
                              else if (mode == LinkMode.cloud)
                                const StatusPill('Internet', color: Brand.blue, icon: Icons.cloud_done_rounded, dense: true),
                              StatusPill('${d.inputs.length} in · ${d.outputs.length} out', color: Brand.blue, icon: Icons.cable_rounded, dense: true),
                              if (d.alerts > 0)
                                StatusPill('${d.alerts} alert${d.alerts == 1 ? '' : 's'}', color: Brand.danger, icon: Icons.warning_amber_rounded, dense: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded, color: Brand.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open ? _body(context, d) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Device d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d.model?.name ?? 'No model'} · ${d.serial}\nLast seen ${timeAgo(d.lastSeen)}',
                  style: const TextStyle(fontSize: 12, color: Brand.muted, height: 1.4),
                ),
              ),
              IconButton(
                tooltip: 'Configure sensors & actuators',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigureScreen(deviceId: d.id))),
                icon: const Icon(Icons.settings_input_component_rounded, color: Brand.blue),
              ),
              IconButton(
                tooltip: 'Device settings',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceSettingsScreen(deviceId: d.id))),
                icon: const Icon(Icons.more_horiz_rounded, color: Brand.blue),
              ),
            ],
          ),
          if (!d.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Panel(
                color: fade(Brand.warning, 0.08),
                border: fade(Brand.warning, 0.3),
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, color: Brand.warning),
                    SizedBox(width: 10),
                    Expanded(child: Text('This device is deactivated. Outputs cannot be controlled until you activate it.')),
                  ],
                ),
              ),
            ),
          DeviceControls(device: d),
        ],
      ),
    );
  }
}
