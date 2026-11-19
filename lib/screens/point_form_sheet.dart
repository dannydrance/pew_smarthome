import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the add/edit form for a sensor or actuator. Returns true when saved.
Future<bool?> showPointForm(
  BuildContext context, {
  required DeviceConfig config,
  required AppMeta meta,
  DevicePoint? point,
  String? direction,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Brand.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => PointFormSheet(config: config, meta: meta, point: point, direction: direction),
  );
}

class PointFormSheet extends StatefulWidget {
  const PointFormSheet({super.key, required this.config, required this.meta, this.point, this.direction});

  final DeviceConfig config;
  final AppMeta meta;
  final DevicePoint? point;
  final String? direction;

  @override
  State<PointFormSheet> createState() => _PointFormSheetState();
}

class _PointFormSheetState extends State<PointFormSheet> {
  final _form = GlobalKey<FormState>();
  late String _direction;
  late String _signal;
  String? _type;
  String? _pin;
  int _controls = 0;            // 0 = controls nothing
  String _mode = 'toggle';
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _pinText;
  late final TextEditingController _unit;
  late final TextEditingController _min;
  late final TextEditingController _max;
  bool _busy = false;
  ApiException? _error;

  DevicePoint? get _editing => widget.point;
  DeviceModelSpec? get _model => widget.config.model;

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _direction = p?.direction ?? widget.direction ?? _firstDirectionWithRoom();
    _signal = p?.signal ?? _firstSignalWithRoom(_direction);
    _type = p?.type;
    _pin = p?.pin;
    _controls = p?.controlsId ?? 0;
    _mode = (p != null && p.controlMode.isNotEmpty) ? p.controlMode : 'toggle';
    _name = TextEditingController(text: p?.name ?? '');
    _location = TextEditingController(text: p?.location ?? '');
    _pinText = TextEditingController(text: p?.pin ?? '');
    _unit = TextEditingController(text: p?.unit ?? '');
    _min = TextEditingController(text: p == null ? '0' : _fmt(p.min));
    _max = TextEditingController(text: p == null ? '100' : _fmt(p.max));
  }

  @override
  void dispose() {
    for (final c in [_name, _location, _pinText, _unit, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

  // ------------------------------------------------------------------ model rules (same as the server)

  /// Points of this kind already configured, not counting the one being edited.
  int _used(String direction, String signal) => widget.config.device.points
      .where((p) => p.direction == direction && p.signal == signal && p.id != _editing?.id)
      .length;

  int? _limit(String direction, String signal) {
    final model = _model;
    if (model == null) return null;
    return model.limit('${signal}_${direction == 'input' ? 'in' : 'out'}');
  }

  bool _hasRoom(String direction, String signal) {
    final limit = _limit(direction, signal);
    return limit == null || _used(direction, signal) < limit;
  }

  String _firstDirectionWithRoom() {
    for (final d in ['input', 'output']) {
      if (_hasRoom(d, 'digital') || _hasRoom(d, 'analog')) return d;
    }
    return 'input';
  }

  String _firstSignalWithRoom(String direction) => _hasRoom(direction, 'digital') || !_hasRoom(direction, 'analog') ? 'digital' : 'analog';

  bool get _canLink => _direction == 'input' && _signal == 'digital';

  List<DevicePoint> get _linkTargets =>
      widget.config.device.points.where((p) => p.isOutput && p.isDigital && p.id != _editing?.id).toList();

  List<Choice> get _types => _direction == 'input' ? widget.meta.sensorTypes : widget.meta.actuatorTypes;

  List<ModelPin> get _pins => widget.config.pins;

  String? _pinProblem(ModelPin pin) {
    if (pin.usedById != null && pin.usedById != _editing?.id) return 'Used by ${pin.usedByName}';
    if (!pin.supports(_direction, _signal)) return 'Not ${_signal == 'digital' ? 'a digital' : 'an analog'} ${_direction == 'input' ? 'input' : 'output'}';
    return null;
  }

  void _setDirection(String value) {
    setState(() {
      _direction = value;
      if (!_hasRoom(_direction, _signal)) _signal = _firstSignalWithRoom(_direction);
      if (_type != null && !_types.any((t) => t.key == _type)) _type = null;
      _checkPin();
    });
  }

  void _setSignal(String value) {
    setState(() {
      _signal = value;
      _checkPin();
    });
  }

  void _checkPin() {
    if (_model == null || _pin == null) return;
    for (final p in _pins) {
      if (p.pin == _pin && _pinProblem(p) != null) _pin = null;
    }
  }

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    setState(() => _error = null);
    final valid = _form.currentState!.validate();
    if (_type == null) {
      setState(() => _error = ApiException('Choose what is connected.', fieldErrors: {'point_type': ['Choose what is connected.']}));
      return;
    }
    if (_model != null && _pin == null) {
      setState(() => _error = ApiException('Choose a pin.', fieldErrors: {'pin': ['Choose a pin.']}));
      return;
    }
    if (!valid) return;

    final data = <String, dynamic>{
      'direction': _direction,
      'signal': _signal,
      'point_type': _type,
      'name': _name.text.trim(),
      'location': _location.text.trim(),
      'pin': _model != null ? _pin : _pinText.text.trim().toUpperCase(),
      'controls': _canLink && _controls != 0 ? _controls : '',
      'control_mode': _mode,
    };
    if (_signal == 'analog') {
      data['unit'] = _unit.text.trim();
      data['min_value'] = double.tryParse(_min.text.trim().replaceAll(',', '.')) ?? 0;
      data['max_value'] = double.tryParse(_max.text.trim().replaceAll(',', '.')) ?? 100;
    }

    setState(() => _busy = true);
    try {
      await context.read<DevicesState>().savePoint(widget.config.device.id, data, pointId: _editing?.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final roomHere = _hasRoom(_direction, _signal);
    final limit = _limit(_direction, _signal);
    final kind = '${_signal == 'digital' ? 'digital' : 'analog'} ${_direction == 'input' ? 'input' : 'output'}';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(_editing == null ? 'Add sensor or actuator' : 'Edit ${_editing!.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.config.device.displayName, style: const TextStyle(color: Brand.muted)),
            const SizedBox(height: 18),
            const _Label('Type of connection'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'input', icon: Icon(Icons.sensors_rounded), label: Text('Sensor')),
                ButtonSegment(value: 'output', icon: Icon(Icons.toggle_on_rounded), label: Text('Actuator')),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => _setDirection(s.first),
            ),
            const SizedBox(height: 14),
            const _Label('Signal'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'digital', label: Text(_segmentLabel('Digital', 'digital'))),
                ButtonSegment(value: 'analog', label: Text(_segmentLabel(_direction == 'output' ? 'Analog / PWM' : 'Analog', 'analog'))),
              ],
              selected: {_signal},
              onSelectionChanged: (s) => _setSignal(s.first),
            ),
            if (!roomHere) ...[
              const SizedBox(height: 10),
              Panel(
                color: fade(Brand.warning, 0.1),
                border: fade(Brand.warning, 0.4),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Brand.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(limit == 0
                          ? '${_model!.name} has no ${kind}s.'
                          : '${_model!.name} allows at most $limit $kind${limit == 1 ? '' : 's'} and all are used.'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            PickerField<String>(
              label: 'What is connected',
              icon: Icons.category_rounded,
              value: _type,
              error: _error?.field('point_type'),
              options: [for (final t in _types) PickerOption(t.key, t.label, icon: pointIcon(t.key))],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('Name',
                  hint: _direction == 'input' ? 'e.g. Front door sensor' : 'e.g. Living room light',
                  icon: Icons.label_rounded,
                  error: _error?.field('name')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration('Connected at (location)',
                  hint: _direction == 'input' ? 'e.g. Front door' : 'e.g. Living room',
                  icon: Icons.place_rounded,
                  error: _error?.field('location')),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter where it is connected' : null,
            ),
            const SizedBox(height: 14),
            if (_model != null)
              PickerField<String>(
                label: 'Pin',
                icon: Icons.settings_input_component_rounded,
                value: _pin,
                error: _error?.field('pin'),
                helper: 'Only pins of ${_model!.name} that support a $kind can be chosen.',
                sheetTitle: 'Pins of ${_model!.name}',
                options: [
                  for (final p in _pins)
                    PickerOption(
                      p.pin,
                      p.label.isEmpty ? p.pin : '${p.pin} · ${p.label}',
                      subtitle: _pinProblem(p) ?? p.capsText,
                      icon: _pinProblem(p) == null ? Icons.radio_button_unchecked_rounded : Icons.block_rounded,
                      enabled: _pinProblem(p) == null,
                    ),
                ],
                onChanged: (v) => setState(() => _pin = v),
              )
            else
              TextFormField(
                controller: _pinText,
                textCapitalization: TextCapitalization.characters,
                decoration: fieldDecoration('Pin', hint: 'e.g. GPIO4, D5, A0', icon: Icons.settings_input_component_rounded, error: _error?.field('pin')),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the pin' : null,
              ),
            if (_canLink) ...[
              const SizedBox(height: 14),
              Panel(
                color: fade(Brand.blue, 0.04),
                border: fade(Brand.blue, 0.2),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18, color: Brand.blue),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Switch control (works on the device, even without internet)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PickerField<int>(
                      label: 'Controls output',
                      icon: Icons.lightbulb_outline_rounded,
                      value: _controls,
                      error: _error?.field('controls'),
                      helper: 'Several switches can control the same lamp.',
                      options: [
                        const PickerOption(0, 'Nothing (only report its state)', icon: Icons.block_rounded),
                        for (final o in _linkTargets)
                          PickerOption(o.id, o.name, subtitle: '${o.location} · ${o.pin}', icon: o.icon),
                      ],
                      onChanged: (v) => setState(() {
                        _controls = v;
                        if (_type == 'push_button') _mode = 'button';
                        if (_type == 'motion' || _type == 'door') _mode = 'follow';
                      }),
                    ),
                    if (_controls != 0) ...[
                      const SizedBox(height: 10),
                      PickerField<String>(
                        label: 'How it controls',
                        icon: Icons.swap_horiz_rounded,
                        value: _mode,
                        options: const [
                          PickerOption('toggle', 'Every flip changes the output', subtitle: 'Normal wall switches, 2-way / staircase'),
                          PickerOption('button', 'Each press changes the output', subtitle: 'Push buttons'),
                          PickerOption('follow', 'Output follows the input', subtitle: 'e.g. motion sensor turns a light on'),
                        ],
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                    ],
                    if (_linkTargets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Add a digital output (switch, valve...) first to link it.',
                            style: TextStyle(color: Brand.muted, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
            if (_signal == 'analog') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: fieldDecoration('Minimum', error: _error?.field('min_value')),
                      validator: _number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: fieldDecoration('Maximum', error: _error?.field('max_value')),
                      validator: (v) {
                        final base = _number(v);
                        if (base != null) return base;
                        final low = double.tryParse(_min.text.replaceAll(',', '.'));
                        final high = double.tryParse(v!.replaceAll(',', '.'));
                        if (low != null && high != null && high <= low) return 'Must be above minimum';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _unit,
                      decoration: fieldDecoration('Unit', hint: '°C, %', error: _error?.field('unit')),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null && (_error!.general != null || _error!.fieldErrors.isEmpty)) ...[
              const SizedBox(height: 14),
              ErrorBanner(_error!.general ?? _error!.message),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy || (!roomHere && _model != null) ? null : _save,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_editing == null ? 'Save' : 'Save changes'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  String _segmentLabel(String label, String signal) {
    final limit = _limit(_direction, signal);
    if (limit == null) return label;
    final left = limit - _used(_direction, signal);
    return '$label (${left < 0 ? 0 : left} left)';
  }

  String? _number(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return double.tryParse(v.trim().replaceAll(',', '.')) == null ? 'Not a number' : null;
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Brand.muted)),
    );
  }
}
