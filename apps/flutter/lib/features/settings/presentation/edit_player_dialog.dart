import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/player/domain/player.dart';

/// Edits the Player ID card (name / class / age). Applies the change itself,
/// so call sites just `showDialog(builder: (_) => const EditPlayerDialog())`.
class EditPlayerDialog extends ConsumerStatefulWidget {
  const EditPlayerDialog({super.key});

  @override
  ConsumerState<EditPlayerDialog> createState() => _EditPlayerDialogState();
}

class _EditPlayerDialogState extends ConsumerState<EditPlayerDialog> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late PlayerClass _playerClass;

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider);
    _name = TextEditingController(text: player.name);
    _age = TextEditingController(text: '${player.age}');
    _playerClass = player.playerClass;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    ref.read(playerProvider.notifier).updateProfile(
          name: name,
          job: _playerClass.label,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoration('Name'),
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Class',
                  style: NotionType.mono(size: 10.5, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final playerClass in PlayerClass.values)
                  ChoiceChip(
                    selected: _playerClass == playerClass,
                    onSelected: (_) =>
                        setState(() => _playerClass = playerClass),
                    avatar: Icon(
                      playerClass.icon,
                      size: 14,
                      color: _playerClass == playerClass
                          ? NotionColors.textPrimary
                          : NotionColors.textMuted,
                    ),
                    label: Text(playerClass.label,
                        style: const TextStyle(fontSize: 12)),
                    selectedColor: NotionColors.surfaceHover,
                    backgroundColor: NotionColors.surface,
                    side: BorderSide(
                      color: _playerClass == playerClass
                          ? const Color(0xFF5A5A5A)
                          : NotionColors.border,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // The class is a real choice, so say what it does.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NotionColors.surfaceHover.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NotionColors.border),
              ),
              child: Text(
                '${_playerClass.tagline}\n'
                '+50% XP on ${_playerClass.favoredArea.label} quests.',
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: NotionColors.textMuted),
              ),
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
