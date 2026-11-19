import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/token_sheet.dart';
import 'configure_screen.dart';

/// Edit, activate/deactivate, token and deletion of one device.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key, required this.deviceId});

  final int deviceId;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  Device? _device;
  List<DeviceModelSpec> _models = [];
  String? _loadError;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _serial = TextEditingController();
  int? _modelId;
  ApiException? _error;
  bool _saving = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final state = context.read<DevicesState>();
    try {
      final device = await state.getDevice(widget.deviceId);
      List<DeviceModelSpec> models = [];
      try {
        models = await state.loadModels();
      } catch (_) {}
      if (!mounted) return;
      _fill(device);
      setState(() => _models = models);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  void _fill(Device device) {
    _device = device;
    _name.text = device.name;
    _location.text = device.location;
    _serial.text = device.serial;
    _modelId = device.model?.id;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final device = await context.read<DevicesState>().updateDevice(widget.deviceId, {
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'serialnumber': _serial.text.trim(),
        if (_modelId != null) 'model': _modelId,
      });
      if (!mounted) return;
      setState(() => _fill(device));
      showToast(context, 'Device saved');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggle(bool enabled) => _run(() async {
        final device = await context.read<DevicesState>().toggleDevice(widget.deviceId, enabled);
        if (!mounted) return;
        setState(() => _device = device);
        showToast(context, enabled ? 'Device activated' : 'Device deactivated');
      });

  Future<void> _regenerate() async {
    final ok = await confirm(
      context,
      title: 'Create a new token?',
      message: 'The current token stops working at once. The device stays offline until you put the new token in its firmware.',
      confirmLabel: 'Create new token',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final device = await context.read<DevicesState>().regenerateToken(widget.deviceId);
      if (!mounted) return;
      setState(() => _device = device);
      await showTokenSheet(context, device);
    });
  }

  Future<void> _delete() async {
    final d = _device!;
    final ok = await confirm(
      context,
      title: 'Delete ${d.displayName}?',
      message: 'The device stops working now and is removed after 15 days, or earlier when an administrator confirms. '
          'You can restore it from Devices until then.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final message = await context.read<DevicesState>().requestDelete(widget.deviceId);
      if (!mounted) return;
      showToast(context, message);
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _device;
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.displayName ?? 'Device'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Configure sensors & actuators',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigureScreen(deviceId: d.id))),
              icon: const Icon(Icons.settings_input_component_rounded),
            ),
        ],
      ),
      body: d == null
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(_loadError!, onRetry: _load)),
            )
          : AbsorbPointer(
              absorbing: _working,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (_working) const LinearProgressIndicator(minHeight: 2),
                  _statusCard(d),
                  const SectionTitle('Device details', icon: Icons.edit_rounded),
                  _editCard(d),
                  const SectionTitle('Connection', icon: Icons.key_rounded),
                  _tokenCard(d),
                  const SectionTitle('Danger zone', icon: Icons.warning_amber_rounded),
                  Panel(
                    border: fade(Brand.danger, 0.3),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Delete this device. It is kept for 15 days so you can restore it.',
                              style: TextStyle(height: 1.35)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Brand.danger, side: BorderSide(color: fade(Brand.danger, 0.5))),
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statusCard(Device d) {
    final color = !d.enabled ? Brand.muted : (d.online ? Brand.good : Brand.danger);
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(Icons.developer_board_rounded, color: d.enabled ? Brand.navy : Brand.muted, size: 48, filled: d.enabled),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.enabled ? 'Active' : 'Deactivated', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    StatusPill(!d.enabled ? 'Not accepted by the server' : (d.online ? 'Online' : 'Offline'), color: color, dense: true),
                  ],
                ),
              ),
              Switch(value: d.enabled, onChanged: _toggle),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _InfoRow('Last seen', timeAgo(d.lastSeen)),
          _InfoRow('Last IP address', d.lastIp.isEmpty ? '—' : d.lastIp),
          _InfoRow('Firmware', d.firmware.isEmpty ? '—' : d.firmware),
          _InfoRow('Sensors / actuators', '${d.inputs.length} / ${d.outputs.length}'),
          _InfoRow('Added', formatDate(d.createdAt)),
        ],
      ),
    );
  }

  Widget _editCard(Device d) {
    final options = <PickerOption<int>>[
      for (final m in _models) PickerOption(m.id, m.name, icon: Icons.memory_rounded),
    ];
    if (d.model != null && !_models.any((m) => m.id == d.model!.id)) {
      options.insert(0, PickerOption(d.model!.id, d.model!.name, icon: Icons.memory_rounded));
    }
    return Panel(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerField<int>(
              label: 'Device model',
              icon: Icons.memory_rounded,
              value: _modelId,
              hint: d.model == null ? 'No model (older device)' : 'Choose',
              options: options,
              error: _error?.field('model'),
              helper: 'Changing the model checks that the current sensors and actuators still fit.',
              onChanged: (v) => setState(() => _modelId = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: fieldDecoration('Device name', icon: Icons.label_rounded, error: _error?.field('name')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _location,
              decoration: fieldDecoration('Installed location', icon: Icons.place_rounded, error: _error?.field('location')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the location' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              decoration: fieldDecoration('Serial number', icon: Icons.qr_code_rounded, error: _error?.field('serialnumber')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the serial number' : null,
            ),
            if (_error != null && _error!.fieldErrors.isEmpty) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!.message),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tokenCard(Device d) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(Icons.key_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device token', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(d.tokenMasked, style: const TextStyle(fontFamily: 'monospace', color: Brand.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy token',
                onPressed: d.token == null ? null : () => copyText(context, d.token!, 'Token'),
                icon: const Icon(Icons.copy_rounded, color: Brand.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showTokenSheet(context, d),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Show'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: const Text('New token'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Brand.muted))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
