import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A row of preset color swatches. Tap to pick. Retro-style square swatches.
class ColorSwatchPicker extends StatelessWidget {
  final List<Color> palette;
  final Color selected;
  final ValueChanged<Color> onChanged;

  const ColorSwatchPicker({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final color in palette)
          _Swatch(
            color: color,
            selected: color.value == selected.value,
            borderIdle: c.border,
            borderSel: c.text,
            onTap: () => onChanged(color),
          ),
      ],
    );
  }
}

class _Swatch extends StatefulWidget {
  final Color color;
  final bool selected;
  final Color borderIdle;
  final Color borderSel;
  final VoidCallback onTap;
  const _Swatch({
    required this.color,
    required this.selected,
    required this.borderIdle,
    required this.borderSel,
    required this.onTap,
  });

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final side = widget.selected
        ? widget.borderSel
        : (_hover ? widget.color : widget.borderIdle);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: widget.color,
            border: Border.all(
              color: side,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
          child: widget.selected
              ? Center(
                  child: Container(
                    width: 6, height: 6,
                    color: widget.borderSel,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
