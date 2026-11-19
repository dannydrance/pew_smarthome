import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet that shows the device serial and token with copy buttons.
Future<void> showTokenSheet(BuildContext context, Device device, {String? syncUrl, bool isNew = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(isNew ? Icons.check_rounded : Icons.key_rounded, color: isNew ? Brand.good : Brand.blue, size: 46, filled: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isNew ? 'Device added' : 'Device credentials',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(device.displayName, style: const TextStyle(color: Brand.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Put the serial number and token in the device firmware. Keep the token private: '
              'anyone with it can send readings as this device.',
              style: TextStyle(color: Brand.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            _CopyRow(label: 'Serial number', value: device.serial),
            const SizedBox(height: 10),
            _CopyRow(label: 'Device token', value: device.token ?? device.tokenMasked, secret: true, canCopy: device.token != null),
            if (syncUrl != null && syncUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CopyRow(label: 'Device API address', value: syncUrl),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(isNew ? 'Continue to configuration' : 'Done')),
          ],
        ),
      ),
    ),
  );
}

class _CopyRow extends StatefulWidget {
  const _CopyRow({required this.label, required this.value, this.secret = false, this.canCopy = true});

  final String label;
  final String value;
  final bool secret;
  final bool canCopy;

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final n = widget.value.length < 8 ? 8 : (widget.value.length > 24 ? 24 : widget.value.length);
    final shown = _hidden ? '•' * n : widget.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Brand.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.line)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: const TextStyle(fontSize: 12, color: Brand.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SelectableText(shown, style: const TextStyle(fontFamily: 'monospace', fontSize: 14.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (widget.secret)
            IconButton(
              tooltip: _hidden ? 'Show' : 'Hide',
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Brand.muted),
            ),
          if (widget.canCopy)
            IconButton(
              tooltip: 'Copy',
              onPressed: () => copyText(context, widget.value, widget.label),
              icon: const Icon(Icons.copy_rounded, color: Brand.blue),
            ),
        ],
      ),
    );
  }
}
