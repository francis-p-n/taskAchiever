import 'package:flutter/material.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/shared/widgets/block_bar.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

/// Small tinted stat callout: emoji + label, large value, optional block bar.
/// Used as the summary row at the top of feature screens.
class MetricCallout extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final double? progress; // 0..1, shows a bar when set

  const MetricCallout({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: NotionColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            BlockBar(
              value: (progress!.clamp(0.0, 1.0) * 10).round(),
              max: 10,
              color: color,
              showLabel: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays out metric callouts in a responsive equal-width row (wraps on
/// narrow screens).
class MetricRow extends StatelessWidget {
  final List<Widget> children;

  const MetricRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 560;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

/// Centers page content at a comfortable reading width, like a Notion page.
class PageBody extends StatelessWidget {
  final List<Widget> children;

  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
