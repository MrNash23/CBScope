import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.card,
        border: Border.all(color: c.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const SectionHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('>_', style: t.headlineMedium?.copyWith(color: c.subtle)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: t.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: t.bodySmall),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 6),
          _AsciiRule(char: '=', color: c.border),
        ],
      ),
    );
  }
}

/// A row of repeated characters — terminal-style horizontal rule.
class _AsciiRule extends StatelessWidget {
  final String char;
  final Color color;
  const _AsciiRule({required this.char, required this.color});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Estimate char width for Menlo 11-12px
      final n = (box.maxWidth / 6).floor().clamp(10, 400);
      return Text(
        char * n,
        style: TextStyle(color: color, fontSize: 11, height: 1, fontFamily: 'Menlo'),
        maxLines: 1, overflow: TextOverflow.clip,
      );
    });
  }
}

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const KpiTile({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: c.subtle),
                const SizedBox(width: 6),
              ],
              Text(label.toUpperCase(), style: t.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: t.headlineLarge),
        ],
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final bool connected;
  final String label;
  const StatusDot({super.key, required this.connected, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = connected ? c.success : c.subtle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Blinking-cursor-style square
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color),
        ),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
