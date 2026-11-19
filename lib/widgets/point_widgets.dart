import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/devices_state.dart';
import '../theme.dart';
import 'common.dart';

/// Sensor reading card (input).
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.point});

  final DevicePoint point;

  @override
  Widget build(BuildContext context) {
    final noData = point.value == null;
    final color = !point.enabled
        ? Brand.muted
        : point.alert
            ? Brand.danger
            : (point.isDigital ? (point.stateOn ? Brand.warning : Brand.good) : Brand.blue);
    return Panel(
      padding: const EdgeInsets.all(14),
      border: point.alert ? fade(Brand.danger, 0.45) : null,
      color: point.alert ? fade(Brand.danger, 0.04) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(point.icon, color: color, size: 38),
              const Spacer(),
              if (!point.enabled)
                const StatusPill('Off', color: Brand.muted, dense: true)
              else if (point.alert)
                const StatusPill('Alert', color: Brand.danger, icon: Icons.warning_amber_rounded, dense: true)
              else
                Text(point.pin, style: const TextStyle(fontSize: 11, color: Brand.muted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              noData ? 'No data' : point.display,
              style: TextStyle(
                fontSize: point.isDigital || noData ? 20 : 26,
                fontWeight: FontWeight.w800,
                color: noData ? Brand.muted : (point.alert ? Brand.danger : Brand.text),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(point.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(point.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          if (point.isAnalog && !noData) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: point.percent / 100,
                minHeight: 5,
                backgroundColor: Brand.line,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('Updated ${timeAgo(point.updated)}', style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ],
      ),
    );
  }
}

/// Switch / valve / lock card (digital output).
class SwitchCard extends StatelessWidget {
  const SwitchCard({super.key, required this.device, required this.point});

  final Device device;
  final DevicePoint point;

  @override
  Widget build(BuildContext context) {
    final state = context.read<DevicesState>();
    final waiting = context.select<DevicesState, PendingCommand?>((s) => s.pendingFor(point));
    final busy = waiting != null;
    final canControl = device.enabled && point.enabled;
    final on = point.stateOn; // last state CONFIRMED by the device
    final color = point.type == 'valve' ? const Color(0xFF0EA5E9) : Brand.yellow;

    Future<void> flip() async {
      if (!canControl || busy) return;
      try {
        await state.setPoint(device, point, on ? 0 : 1);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: on && canControl ? Brand.hero : null,
        color: on && canControl ? null : Colors.white,
        border: Border.all(color: on && canControl ? Brand.navy : Brand.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: canControl ? flip : () => showToast(context, _blockedReason(device, point), error: true),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: on && canControl ? color : fade(Brand.muted, 0.12),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: on && canControl ? [BoxShadow(color: fade(color, 0.55), blurRadius: 14)] : null,
                      ),
                      child: Icon(point.icon, size: 20, color: on && canControl ? Brand.navy : Brand.muted),
                    ),
                    const Spacer(),
                    if (busy)
                      Semantics(
                        label: 'Waiting for the device to confirm',
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: on && canControl ? Colors.white : Brand.blue),
                        ),
                      )
                    else
                      Switch(
                        value: on,
                        onChanged: canControl ? (_) => flip() : null,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  waiting != null ? point.waitingLabel(waiting.value) : (point.value == null ? 'Off' : point.stateLabel),
                  style: TextStyle(
                    fontSize: busy ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: on && canControl ? Colors.white : (busy ? Brand.blue : Brand.text),
                  ),
                ),
                const SizedBox(height: 2),
                Text(point.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: on && canControl ? Colors.white : Brand.text)),
                Text(point.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: on && canControl ? fade(Colors.white, 0.75) : Brand.muted)),
                const SizedBox(height: 8),
                Text(
                  !point.enabled
                      ? 'Disabled in configuration'
                      : busy
                          ? 'Waiting for the device to confirm'
                          : '${point.typeLabel} · ${point.pin}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: on && canControl ? fade(Colors.white, 0.7) : Brand.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _blockedReason(Device device, DevicePoint point) {
  if (!device.enabled) return 'This device is deactivated. Activate it in device settings.';
  if (!point.enabled) return 'This output is deactivated in the configuration.';
  return 'Not available';
}

/// Dimmer / PWM / analog output with a slider. Sends the value when the finger is lifted.
class LevelCard extends StatefulWidget {
  const LevelCard({super.key, required this.device, required this.point});

  final Device device;
  final DevicePoint point;

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final device = widget.device;
    final waiting = context.select<DevicesState, PendingCommand?>((s) => s.pendingFor(point));
    final busy = waiting != null;
    final canControl = device.enabled && point.enabled && !busy;
    final low = point.min < point.max ? point.min : point.max;
    final high = point.min < point.max ? point.max : point.min + 1;
    final current = (_dragging ?? point.value ?? low).clamp(low, high).toDouble();
    final pct = high == low ? 0 : ((current - low) / (high - low) * 100).round();
    final valueText = '${current.toStringAsFixed(current.abs() >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '')} ${point.unit}'.trim();

    Future<void> send(double v) async {
      final state = context.read<DevicesState>();
      setState(() => _dragging = null);
      try {
        await state.setPoint(device, point, v);
      } catch (e) {
        if (!mounted) return;
        showError(this.context, e);
      }
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(point.icon, color: canControl ? Brand.blue : Brand.muted, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${point.location} · ${point.pin}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
                  ],
                ),
              ),
              if (waiting != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(point.waitingLabel(waiting.value),
                        style: const TextStyle(fontSize: 12.5, color: Brand.blue, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(valueText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('$pct%', style: const TextStyle(fontSize: 11.5, color: Brand.muted, fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Minimum',
                onPressed: canControl ? () => send(low) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Slider(
                  value: current,
                  min: low,
                  max: high,
                  label: valueText,
                  divisions: (high - low) <= 255 && (high - low) >= 1 ? (high - low).round() : null,
                  onChanged: canControl ? (v) => setState(() => _dragging = v) : null,
                  onChangeEnd: canControl ? send : null,
                ),
              ),
              IconButton(
                tooltip: 'Maximum',
                onPressed: canControl ? () => send(high) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (!canControl && !busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_blockedReason(device, point), style: const TextStyle(fontSize: 11.5, color: Brand.muted)),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Waiting for the device to confirm. The level shown is the last confirmed one.',
                  style: TextStyle(fontSize: 11.5, color: Brand.muted)),
            ),
        ],
      ),
    );
  }
}

/// Grid of cards that adapts to the screen width.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minWidth = 160});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var columns = (box.maxWidth / minWidth).floor();
        if (columns < 1) columns = 1;
        if (columns > 4) columns = 4;
        const gap = 12.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}

/// All controls and readings of one device: sensors, switches and level controls.
class DeviceControls extends StatelessWidget {
  const DeviceControls({super.key, required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final inputs = device.inputs;
    final switches = device.outputs.where((p) => p.isDigital).toList();
    final levels = device.outputs.where((p) => p.isAnalog).toList();
    if (device.points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No sensors or actuators yet. Open Configure to add what is connected to this device.',
            style: TextStyle(color: Brand.muted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inputs.isNotEmpty) ...[
          const _GroupLabel(Icons.sensors_rounded, 'Sensors'),
          CardGrid(children: [for (final p in inputs) SensorCard(point: p)]),
        ],
        if (switches.isNotEmpty) ...[
          const _GroupLabel(Icons.toggle_on_rounded, 'Switches & valves'),
          CardGrid(children: [for (final p in switches) SwitchCard(device: device, point: p)]),
        ],
        if (levels.isNotEmpty) ...[
          const _GroupLabel(Icons.tune_rounded, 'Level controls'),
          CardGrid(minWidth: 300, children: [for (final p in levels) LevelCard(device: device, point: p)]),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Brand.muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Brand.muted)),
        ],
      ),
    );
  }
}
