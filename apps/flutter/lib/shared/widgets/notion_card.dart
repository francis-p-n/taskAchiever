import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';

/// Flat Notion-style block: subtle border, slight radius, no glow.
/// On hover the border brightens and the surface lifts slightly
/// (shadcn-style state change — no ripple, no shadow).
class NotionCard extends StatefulWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const NotionCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  State<NotionCard> createState() => _NotionCardState();
}

class _NotionCardState extends State<NotionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? NotionColors.surface;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _hovered
            ? Color.lerp(baseColor, NotionColors.surfaceHover, 0.35)
            : baseColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hovered ? const Color(0xFF454545) : NotionColors.border,
        ),
      ),
      child: widget.child,
    );

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: card)
          : card,
    );
  }
}

/// Small "▸ Section name" toggle-style heading used all over the template.
class NotionSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color iconColor;

  const NotionSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.iconColor = NotionColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: NotionType.display(size: 15),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Notion-style tag chip, e.g. "+1 HP" or "Mage".
class NotionTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;

  const NotionTag({
    super.key,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        // Hairline tinted edge keeps chips crisp against colored cards.
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.5),
      ),
      child: Text(
        text,
        style: NotionType.mono(size: 11, color: color),
      ),
    );
  }
}
