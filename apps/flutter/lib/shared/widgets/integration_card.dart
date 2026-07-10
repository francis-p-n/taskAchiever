import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// Card for an external integration (Todoist, Google Calendar, ...).
/// Disconnected: dimmed preview rows + a Connect button (via [onConnect]).
/// Connected: green tag, last-sync line, Sync now + Disconnect actions.
class IntegrationCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final List<Widget> preview;
  final bool connected;
  final DateTime? lastSyncAt;
  final VoidCallback? onConnect;
  final VoidCallback? onSync;
  final VoidCallback? onDisconnect;

  const IntegrationCard({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    this.preview = const [],
    this.connected = false,
    this.lastSyncAt,
    this.onConnect,
    this.onSync,
    this.onDisconnect,
  });

  String get _syncLabel {
    if (lastSyncAt == null) return 'Synced';
    final delta = DateTime.now().difference(lastSyncAt!.toLocal());
    if (delta.inMinutes < 1) return 'Synced just now';
    if (delta.inHours < 1) return 'Synced ${delta.inMinutes}m ago';
    if (delta.inDays < 1) return 'Synced ${delta.inHours}h ago';
    return 'Synced ${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: NotionColors.textMuted),
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
              if (connected)
                const NotionTag(
                  text: 'Connected',
                  color: NotionColors.green,
                  bgColor: NotionColors.greenBg,
                )
              else
                const NotionTag(
                  text: 'Not connected',
                  color: NotionColors.textMuted,
                  bgColor: NotionColors.surfaceHover,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            connected ? _syncLabel : description,
            style: const TextStyle(
              fontSize: 12,
              color: NotionColors.textMuted,
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Opacity(
              opacity: connected ? 1.0 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: preview,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (connected)
            Row(
              children: [
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: onSync,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NotionColors.textPrimary,
                      side: const BorderSide(color: NotionColors.border),
                    ),
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text('Sync now', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onDisconnect,
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(fontSize: 12, color: NotionColors.textMuted),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 30,
              child: OutlinedButton.icon(
                onPressed: onConnect ??
                    () {
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
                icon: const Icon(Icons.link_outlined, size: 14),
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
