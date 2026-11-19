import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/token_sheet.dart';
import 'point_form_sheet.dart';

/// Sensors and actuators connected to a device, within the limits of its model.
class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({super.key, required this.deviceId, this.isNew = false});

  final int deviceId;
  final bool isNew;

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  DeviceConfig? _config;
  AppMeta? _meta;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final state = context.read<DevicesState>();
    try {
      final results = await Future.wait<Object>([state.loadConfig(widget.deviceId), state.loadMeta()]);
      if (!mounted) return;
      setState(() {
        _config = results[0] as DeviceConfig;
        _meta = results[1] as AppMeta;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openForm({DevicePoint? point, String? direction}) async {
    final config = _config;
    final meta = _meta;
    if (config == null || meta == null) return;
    final saved = await showPointForm(context, config: config, meta: meta, point: point, direction: direction);
    if (saved == true && mounted) {
      showToast(context, point == null ? 'Saved' : 'Changes saved');
      _load();
    }
  }

  Future<void> _togglePoint(DevicePoint p) async {
    setState(() => _working = true);
    try {
      await context.read<DevicesState>().togglePoint(p.id, !p.enabled);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deletePoint(DevicePoint p) async {
    final ok = await confirm(
      context,
      title: 'Remove ${p.name}?',
      message: 'Pin ${p.pin} becomes free. The device stops reporting or controlling it.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await context.read<DevicesState>().deletePoint(p.id);
      await _load();
      if (mounted) showToast(context, '${p.name} removed');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(
        title: Text(config == null ? 'Configure' : 'Configure ${config.device.displayName}'),
        actions: [
          if (config != null)
            IconButton(
              tooltip: 'Device token',
              onPressed: () => showTokenSheet(context, config.device, syncUrl: config.syncUrl),
              icon: const Icon(Icons.key_rounded),
            ),
        ],
      ),
      floatingActionButton: config == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Brand.yellow,
              foregroundColor: Brand.navy,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add sensor / actuator', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: config == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(_error!, onRetry: _load)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                children: [
                  if (_working) const LinearProgressIndicator(minHeight: 2),
                  if (widget.isNew)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        color: fade(Brand.good, 0.07),
                        border: fade(Brand.good, 0.3),
                        child: const Row(
                          children: [
                            Icon(Icons.celebration_rounded, color: Brand.good),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Device added. Now add each sensor and actuator connected to it, '
                                  'with the pin and the place it is connected.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _capacityCard(config),
                  SectionTitle(
                    'Sensors (inputs)',
                    icon: Icons.sensors_rounded,
                    trailing: TextButton.icon(
                      onPressed: () => _openForm(direction: 'input'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ),
                  ..._pointList(config.device.inputs, 'No sensors yet.'),
                  SectionTitle(
                    'Actuators (outputs)',
                    icon: Icons.toggle_on_rounded,
                    trailing: TextButton.icon(
                      onPressed: () => _openForm(direction: 'output'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ),
                  ..._pointList(config.device.outputs, 'No actuators yet.'),
                ],
              ),
            ),
    );
  }

  Widget _capacityCard(DeviceConfig config) {
    final model = config.model;
    if (model == null) {
      return Panel(
        color: fade(Brand.warning, 0.07),
        border: fade(Brand.warning, 0.3),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Brand.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text('This device has no model. Choose its model in device settings so pins and limits are checked.'),
            ),
          ],
        ),
      );
    }
    final free = config.pins.where((p) => p.usedById == null).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.memory_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text('$free of ${config.pins.length} pins free', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final width = box.maxWidth >= 520 ? (box.maxWidth - 16 * 3) / 4 : (box.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                for (final c in config.capacity)
                  SizedBox(width: width, child: UsageBar(label: c.label, used: c.used, limit: c.limit)),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _pointList(List<DevicePoint> points, String empty) {
    if (points.isEmpty) {
      return [
        Panel(
          child: Text(empty, style: const TextStyle(color: Brand.muted)),
        ),
      ];
    }
    return [
      for (final p in points)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PointRow(
            point: p,
            onEdit: () => _openForm(point: p),
            onToggle: () => _togglePoint(p),
            onDelete: () => _deletePoint(p),
          ),
        ),
    ];
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point, required this.onEdit, required this.onToggle, required this.onDelete});

  final DevicePoint point;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final detail = [
      p.typeLabel,
      p.isDigital ? 'Digital' : 'Analog',
      if (p.isAnalog) '${_num(p.min)}–${_num(p.max)} ${p.unit}'.trim(),
    ].join(' · ');
    return Panel(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          IconBadge(p.icon, color: p.enabled ? (p.isInput ? Brand.blue : Brand.navy) : Brand.muted, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, color: p.enabled ? Brand.text : Brand.muted)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Brand.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: Brand.line)),
                      child: Text(p.pin, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 13, color: Brand.muted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(p.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                    ),
                  ],
                ),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                if (p.controlsId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: StatusPill('Controls ${p.controlsName.isEmpty ? p.controlsPin : p.controlsName}',
                        color: Brand.blue, icon: Icons.link_rounded, dense: true),
                  ),
                if (!p.enabled) const Padding(padding: EdgeInsets.only(top: 4), child: StatusPill('Deactivated', color: Brand.muted, dense: true)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Brand.muted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'toggle') onToggle();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(p.enabled ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
                  title: Text(p.enabled ? 'Deactivate' : 'Activate'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Brand.danger),
                  title: Text('Remove', style: TextStyle(color: Brand.danger)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
