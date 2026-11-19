import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../theme.dart';

/// White rounded card used everywhere.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.border});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: color ?? Brand.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: border ?? Brand.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.icon});

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: Brand.muted), const SizedBox(width: 8)],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: Brand.muted),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small coloured label with a dot, e.g. "Online".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: fade(color, 0.12), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: dense ? 12 : 14, color: color)
          else
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: dense ? 11.5 : 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Round icon on a tinted background.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = Brand.blue, this.size = 44, this.filled = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : fade(color, 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: filled ? Colors.white : color, size: size * 0.5),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          IconBadge(icon, size: 72),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: fade(Brand.danger, 0.06),
      border: fade(Brand.danger, 0.25),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Brand.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(
      children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: error ? Brand.danger : Brand.navy,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

void showError(BuildContext context, Object error) {
  showToast(context, error is ApiException ? error.message : 'Something went wrong: $error', error: true);
}

Future<void> copyText(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, '$what copied');
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Brand.danger, minimumSize: const Size(80, 44)) : FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String timeAgo(DateTime? time) {
  if (time == null) return 'never';
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 10) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return formatDate(time);
}

String formatDate(DateTime? time) {
  if (time == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${time.day} ${months[time.month - 1]} ${time.year}';
}

/// One option in a [PickerField].
class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle, this.icon, this.enabled = true, this.trailing});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
  final String? trailing;
}

/// A tappable field that opens a bottom sheet with options (nicer than a dropdown on phones).
class PickerField<T> extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
    this.hint = 'Choose',
    this.error,
    this.helper,
    this.sheetTitle,
  });

  final String label;
  final List<PickerOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final String hint;
  final String? error;
  final String? helper;
  final String? sheetTitle;

  @override
  Widget build(BuildContext context) {
    PickerOption<T>? selected;
    for (final o in options) {
      if (o.value == value) selected = o;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: fieldDecoration(label, icon: icon, error: error, helper: helper, hint: hint,
            suffix: const Icon(Icons.expand_more_rounded)),
        child: selected == null
            ? null
            : Text(selected.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(sheetTitle ?? label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final o in options)
                    ListTile(
                      enabled: o.enabled,
                      leading: o.icon == null ? null : Icon(o.icon, color: o.enabled ? Brand.blue : Brand.muted),
                      title: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                      trailing: o.value == value
                          ? const Icon(Icons.check_circle_rounded, color: Brand.blue)
                          : (o.trailing == null
                              ? null
                              : Text(o.trailing!, style: const TextStyle(color: Brand.muted, fontSize: 12))),
                      onTap: o.enabled ? () => Navigator.pop(ctx, o.value) : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

/// Horizontal bar showing how much of a limit is used.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.label, required this.used, required this.limit});

  final String label;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final full = used >= limit;
    final ratio = limit == 0 ? 1.0 : (used / limit).clamp(0.0, 1.0).toDouble();
    final color = limit == 0 ? Brand.muted : (full ? Brand.warning : Brand.blue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            Text(limit == 0 ? 'none' : '$used / $limit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: full && limit > 0 ? Brand.warning : Brand.text)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: Brand.line,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
