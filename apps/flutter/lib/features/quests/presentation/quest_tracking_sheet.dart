import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/data/relationships_repository.dart';
import 'package:life_os/features/life/data/time_repository.dart' show timeSummaryProvider, recentTimeEntriesProvider;
import 'package:life_os/features/quests/data/quests_repository.dart';

/// Post-completion opt-in tracking sheet (lifeOS v2 quest-centric model).
/// Every field is optional; each tagged domain earns +5 bonus XP on the
/// server. Dismissing without saving records nothing.
void showQuestTrackingSheet(
  BuildContext context,
  WidgetRef ref, {
  required String remoteId,
  required String title,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _QuestTrackingSheet(remoteId: remoteId, title: title),
  );
}

class _QuestTrackingSheet extends ConsumerStatefulWidget {
  final String remoteId;
  final String title;

  const _QuestTrackingSheet({required this.remoteId, required this.title});

  @override
  ConsumerState<_QuestTrackingSheet> createState() =>
      _QuestTrackingSheetState();
}

class _QuestTrackingSheetState extends ConsumerState<_QuestTrackingSheet> {
  int? _durationMinutes;
  int? _moodAfter;
  int? _energyAfter;
  final _spendController = TextEditingController();
  String _spendCategory = 'Food';
  int? _contactId;
  String _interactionType = 'meet';
  bool _saving = false;

  @override
  void dispose() {
    _spendController.dispose();
    super.dispose();
  }

  bool get _hasAnything =>
      _durationMinutes != null ||
      _moodAfter != null ||
      _energyAfter != null ||
      _spendCents != null ||
      _contactId != null;

  int? get _spendCents {
    final value = double.tryParse(_spendController.text.trim());
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final bonusXp = await ref.read(questsRepositoryProvider).tagQuest(
          widget.remoteId,
          durationMinutes: _durationMinutes,
          moodAfter: _moodAfter,
          energyAfter: _energyAfter,
          spendingCents: _spendCents,
          spendingCategory: _spendCents != null ? _spendCategory : null,
          contactId: _contactId,
          interactionType: _contactId != null ? _interactionType : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    // Tagged data feeds the Life hub views — refresh them.
    ref.invalidate(timeSummaryProvider);
    ref.invalidate(recentTimeEntriesProvider);
    ref.invalidate(contactsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(bonusXp != null && bonusXp > 0
          ? 'Tags saved  +$bonusXp bonus XP'
          : 'Could not save tags (offline or already tagged).'),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _section(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: NotionColors.textMuted),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NotionColors.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tag "${widget.title}"?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text(
              'All optional — each tagged domain earns +5 bonus XP.',
              style: TextStyle(fontSize: 11, color: NotionColors.textFaint),
            ),
            const SizedBox(height: 16),
            _section(
              'How long did it take?',
              Icons.timer_outlined,
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [15, 30, 60, 90, 120])
                    ChoiceChip(
                      label: Text(m < 60 ? '${m}m' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' 30m'}',
                          style: const TextStyle(fontSize: 12)),
                      selected: _durationMinutes == m,
                      onSelected: (sel) => setState(
                          () => _durationMinutes = sel ? m : null),
                    ),
                ],
              ),
            ),
            _section(
              'How do you feel now?',
              Icons.sentiment_satisfied_outlined,
              Column(
                children: [
                  _scaleRow('Mood', _moodAfter,
                      (v) => setState(() => _moodAfter = v)),
                  _scaleRow('Energy', _energyAfter,
                      (v) => setState(() => _energyAfter = v)),
                ],
              ),
            ),
            _section(
              'Did you spend money?',
              Icons.payments_outlined,
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _spendController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final c in const ['Food', 'Transport', 'Fun', 'Other'])
                          ChoiceChip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            selected: _spendCategory == c,
                            onSelected: (_) =>
                                setState(() => _spendCategory = c),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (contacts.isNotEmpty)
              _section(
                'Who was this with?',
                Icons.people_outline,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in contacts)
                          ChoiceChip(
                            label: Text(c.name,
                                style: const TextStyle(fontSize: 12)),
                            selected: _contactId == c.id,
                            onSelected: (sel) => setState(
                                () => _contactId = sel ? c.id : null),
                          ),
                      ],
                    ),
                    if (_contactId != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final t in const ['text', 'call', 'meet'])
                            ChoiceChip(
                              label: Text(t,
                                  style: const TextStyle(fontSize: 11)),
                              selected: _interactionType == t,
                              onSelected: (_) =>
                                  setState(() => _interactionType = t),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('No thanks',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || !_hasAnything ? null : _submit,
                    child: Text(_saving ? 'Saving…' : 'Save tags',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scaleRow(String label, int? value, ValueChanged<int?> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 50, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: (value ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: value == null ? 'skip' : '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 40,
          child: value == null
              ? const Text('skip',
                  textAlign: TextAlign.right,
                  style:
                      TextStyle(fontSize: 10, color: NotionColors.textFaint))
              : InkWell(
                  onTap: () => onChanged(null),
                  child: Text('$value ✕',
                      textAlign: TextAlign.right,
                      style: NotionType.mono(
                          size: 11, weight: FontWeight.w700)),
                ),
        ),
      ],
    );
  }
}
