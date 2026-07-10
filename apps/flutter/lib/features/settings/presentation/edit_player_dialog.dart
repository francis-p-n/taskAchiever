import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';

/// Edits the Player ID card (name / job / age). Applies the change itself,
/// so call sites just `showDialog(builder: (_) => const EditPlayerDialog())`.
class EditPlayerDialog extends ConsumerStatefulWidget {
  const EditPlayerDialog({super.key});

  @override
  ConsumerState<EditPlayerDialog> createState() => _EditPlayerDialogState();
}

class _EditPlayerDialogState extends ConsumerState<EditPlayerDialog> {
  late final TextEditingController _name;
  late final TextEditingController _job;
  late final TextEditingController _age;

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider);
    _name = TextEditingController(text: player.name);
    _job = TextEditingController(text: player.job);
    _age = TextEditingController(text: '${player.age}');
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _age.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    ref.read(playerProvider.notifier).updateProfile(
          name: name,
          job: _job.text.trim().isEmpty ? null : _job.text.trim(),
          age: int.tryParse(_age.text.trim()),
        );
    // Grab the messenger before popping — looking it up from this context
    // after the dialog is gone throws (deactivated widget ancestor lookup).
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Player ID updated.')),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 12, color: NotionColors.textMuted),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotionColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotionColors.textMuted),
        ),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotionColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.border),
      ),
      title: const Text('Update Player ID', style: TextStyle(fontSize: 16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration('Name'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _job,
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoration('Job / class'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoration('Age'),
                  ),
                ),
              ],
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
          onPressed: _submit,
          child: const Text('Save', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
