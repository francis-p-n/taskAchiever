import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';

/// Segmented progress bar of discrete blocks ("▮▮▮▮▮▮▮▮▯▯  8/10"),
/// like the energy bars in the Notion template.
class BlockBar extends StatelessWidget {
  final int value;
  final int max;
  final Color color;
  final bool showLabel;

  const BlockBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(max, (i) {
              final filled = i < value;
              // Blocks light up left-to-right on first build, like the
              // template's energy bars filling in.
              return Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 200 + i * 45),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => Container(
                    height: 8,
                    margin: EdgeInsets.only(right: i == max - 1 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: filled
                          ? color.withValues(alpha: t)
                          : NotionColors.surfaceHover,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '$value/$max',
            style: NotionType.mono(size: 11, weight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
