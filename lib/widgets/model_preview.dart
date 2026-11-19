import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';

/// Summary of a hardware model: limits and pins.
class ModelPreview extends StatelessWidget {
  const ModelPreview({super.key, required this.model, this.showPins = true});

  final DeviceModelSpec model;
  final bool showPins;

  @override
  Widget build(BuildContext context) {
    final subtitle = [model.manufacturer, model.controller, model.code].where((s) => s.isNotEmpty).join(' · ');
    return Panel(
      color: fade(Brand.blue, 0.04),
      border: fade(Brand.blue, 0.25),
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
                    if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          if (model.specification.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(model.specification, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Limit('Digital in', model.limit('digital_in')),
              _Limit('Analog in', model.limit('analog_in')),
              _Limit('Digital out', model.limit('digital_out')),
              _Limit('PWM out', model.limit('analog_out')),
            ],
          ),
          if (showPins && model.pins.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('${model.pins.length} pins', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in model.pins)
                  Tooltip(
                    message: p.label.isEmpty ? p.capsText : '${p.label}\n${p.capsText}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Brand.line),
                      ),
                      child: Text(
                        '${p.pin} · ${p.capsText}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Limit extends StatelessWidget {
  const _Limit(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: value == 0 ? Brand.muted : Brand.navy)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Brand.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
