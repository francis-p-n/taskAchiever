import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/shared/widgets/block_bar.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// Small tinted stat callout: icon + label, large value, optional block bar.
/// Used as the summary row at the top of feature screens.
class MetricCallout extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final double? progress; // 0..1, shows a bar when set

  const MetricCallout({
    super.key,
    required this.icon,
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
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NotionType.mono(
                    size: 10,
                    weight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: NotionType.display(
              size: 22,
              weight: FontWeight.w700,
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
