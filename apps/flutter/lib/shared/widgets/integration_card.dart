import 'package:flutter/material.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

/// Placeholder block for a not-yet-wired external integration
/// (Todoist, Google Calendar, ...). Shows mock preview rows and a
/// Connect button that reports the integration as coming soon.
class IntegrationCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String description;
  final List<Widget> preview;

  const IntegrationCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.description,
    this.preview = const [],
  });

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const NotionTag(
                text: 'Not connected',
                color: NotionColors.textMuted,
                bgColor: NotionColors.surfaceHover,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: NotionColors.textMuted,
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Opacity(
              opacity: 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: preview,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name integration coming soon'),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: NotionColors.textPrimary,
                side: const BorderSide(color: NotionColors.border),
              ),
              icon: const Icon(Icons.link, size: 14),
              label: Text('Connect $name',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dimmed mock row inside an integration preview.
class IntegrationPreviewRow extends StatelessWidget {
  final String leading;
  final String title;
  final String? trailingText;
  final Color? trailingColor;
  final Color? trailingBg;

  const IntegrationPreviewRow({
    super.key,
    required this.leading,
    required this.title,
    this.trailingText,
    this.trailingColor,
    this.trailingBg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              leading,
              style: const TextStyle(
                fontSize: 11,
                color: NotionColors.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (trailingText != null)
            NotionTag(
              text: trailingText!,
              color: trailingColor ?? NotionColors.textMuted,
              bgColor: trailingBg ?? NotionColors.surfaceHover,
            ),
        ],
      ),
    );
  }
}
