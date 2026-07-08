import 'package:flutter/material.dart';
import 'package:life_achiever/core/theme.dart';

/// Flat Notion-style block: subtle border, slight radius, no glow.
class NotionCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const NotionCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? NotionColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NotionColors.border),
      ),
      child: child,
    );
  }
}

/// Small "▸ Section name" toggle-style heading used all over the template.
class NotionSectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget? trailing;

  const NotionSectionTitle({
    super.key,
    required this.emoji,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NotionColors.textPrimary,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
