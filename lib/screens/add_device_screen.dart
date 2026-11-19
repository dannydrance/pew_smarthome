import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/model_preview.dart';
import '../widgets/token_sheet.dart';
import 'configure_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _serial = TextEditingController();

  List<DeviceModelSpec>? _models;
  String? _loadError;
  DeviceModelSpec? _model;
  bool _busy = false;
  ApiException? _error;

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
    try {
      final models = await context.read<DevicesState>().loadModels(force: true);
      if (!mounted) return;
      setState(() {
        _models = models;
        if (models.length == 1) _model = models.first;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final valid = _form.currentState!.validate();
    if (_model == null) {
      setState(() => _error = ApiException('Choose the device model.', fieldErrors: {'model': ['Choose the device model.']}));
      return;
    }
    if (!valid) return;
    setState(() => _busy = true);
    final state = context.read<DevicesState>();
    try {
      final device = await state.addDevice(
        modelId: _model!.id,
        name: _name.text.trim(),
        location: _location.text.trim(),
        serial: _serial.text.trim(),
      );
      if (!mounted) return;
      await showTokenSheet(context, device, isNew: true);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ConfigureScreen(deviceId: device.id, isNew: true)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = _models;
    return Scaffold(
      appBar: AppBar(title: const Text('Add device')),
      body: SafeArea(
        child: models == null
            ? Center(
                child: _loadError == null
                    ? const CircularProgressIndicator()
                    : Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(_loadError!, onRetry: _load)),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    const _StepHeader(number: 1, title: 'Device model', text: 'The model decides how many sensors and actuators you can connect and on which pins.'),
                    if (models.isEmpty)
                      const Panel(
                        child: Text('No device models are available yet. Please contact us so we can add your hardware model.'),
                      )
                    else
                      PickerField<int>(
                        label: 'Device model',
                        icon: Icons.memory_rounded,
                        value: _model?.id,
                        error: _error?.field('model'),
                        options: [
                          for (final m in models)
                            PickerOption(
                              m.id,
                              m.name,
                              subtitle: 'DI ${m.limit('digital_in')} · AI ${m.limit('analog_in')} · '
                                  'DO ${m.limit('digital_out')} · PWM ${m.limit('analog_out')}',
                              icon: Icons.memory_rounded,
                            ),
                        ],
                        onChanged: (id) => setState(() => _model = models.firstWhere((m) => m.id == id)),
                      ),
                    if (_model != null) ...[
                      const SizedBox(height: 12),
                      ModelPreview(model: _model!),
                    ],
                    const _StepHeader(number: 2, title: 'About the device', text: 'Give it a name and say where it is installed.'),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDecoration('Device name', hint: 'e.g. Main controller', icon: Icons.label_rounded, error: _error?.field('name')),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _location,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDecoration('Installed location', hint: 'e.g. Home, Kicukiro', icon: Icons.place_rounded, error: _error?.field('location')),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter where the device is installed' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _serial,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: fieldDecoration(
                        'Serial number',
                        hint: 'e.g. PEW-ESP32-0012',
                        icon: Icons.qr_code_rounded,
                        helper: 'Printed on the device label.',
                        error: _error?.field('serialnumber'),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the serial number' : null,
                    ),
                    const SizedBox(height: 14),
                    Panel(
                      color: fade(Brand.yellow, 0.12),
                      border: fade(Brand.yellow, 0.5),
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        children: [
                          Icon(Icons.key_rounded, color: Brand.navy),
                          SizedBox(width: 10),
                          Expanded(child: Text('A secure token is created automatically. You can copy it on the next screen.')),
                        ],
                      ),
                    ),
                    if (_error != null && _error!.fieldErrors.isEmpty) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(_error!.message),
                    ] else if (_error?.general != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(_error!.general!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _busy || models.isEmpty ? null : _submit,
                      icon: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Icon(Icons.add_rounded),
                      label: const Text('Add device'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title, required this.text});

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Brand.navy,
            child: Text('$number', style: const TextStyle(color: Brand.yellow, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: Brand.muted, fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
