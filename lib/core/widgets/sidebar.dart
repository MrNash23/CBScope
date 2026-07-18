import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SidebarItem {
  final String label;
  final IconData icon;
  /// Optional badge count shown to the right of the label (0 hides it).
  final int badge;
  const SidebarItem(this.label, this.icon, {this.badge = 0});
}

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<SidebarItem> items;
  final Widget? footer;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.items,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Traffic-light spacer on macOS
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('//', style: t.labelSmall?.copyWith(color: c.subtle)),
                Text('CBScope', style: t.headlineMedium?.copyWith(letterSpacing: 2)),
                Text('11m · CB · FT8', style: t.labelSmall?.copyWith(color: c.subtle)),
                const SizedBox(height: 4),
                Container(height: 1, color: c.border),
              ],
            ),
          ),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final selected = i == selectedIndex;
            return _SidebarButton(
              item: item,
              selected: selected,
              onTap: () => onSelect(i),
            );
          }),
          const Spacer(),
          if (footer != null) ...[
            Container(height: 1, color: c.border),
            Padding(padding: const EdgeInsets.all(12), child: footer),
          ],
        ],
      ),
    );
  }
}

class _SidebarButton extends StatefulWidget {
  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarButton({required this.item, required this.selected, required this.onTap});

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = widget.selected
        ? c.accent.withOpacity(0.10)
        : (_hover ? c.accent.withOpacity(0.05) : Colors.transparent);
    final fg = widget.selected ? c.accent : c.text;
    final prefix = widget.selected ? '>' : ' ';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: widget.selected
                ? Border(left: BorderSide(color: c.accent, width: 2))
                : null,
          ),
          child: Row(
            children: [
              Text(prefix,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(width: 6),
              Icon(widget.item.icon, size: 14, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text('[${widget.item.label.toUpperCase()}]',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.8,
                        )),
              ),
              if (widget.item.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.warning.withOpacity(0.18),
                    border: Border.all(color: c.warning.withOpacity(0.6)),
                  ),
                  child: Text('${widget.item.badge}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.warning, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
