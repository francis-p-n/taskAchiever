import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';

/// Notion-styled single-field dialog used by integration connect flows
/// (paste a Todoist API token, an iCal URL, ...). Returns the trimmed
/// value, or null when cancelled.
Future<String?> showConnectDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String helpText,
  bool obscure = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: NotionColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.border),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              helpText,
              style: const TextStyle(
                fontSize: 12,
                color: NotionColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: fieldLabel,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: NotionColors.textMuted,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: NotionColors.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: NotionColors.textMuted),
                ),
                isDense: true,
              ),
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: NotionColors.textMuted, fontSize: 13),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NotionColors.surfaceHover,
            foregroundColor: NotionColors.textPrimary,
          ),
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(context).pop(value.isEmpty ? null : value);
          },
          child: const Text('Connect', style: TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}
