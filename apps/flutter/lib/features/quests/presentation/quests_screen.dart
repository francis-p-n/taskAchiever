import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/core/flows/integration_flows.dart';
import 'package:life_os/core/providers.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/features/quests/application/quest_actions.dart';
import 'package:life_os/features/quests/application/quests_notifier.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  static const _tabs = ['Today', 'Available Tasks', 'Completed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questsProvider);
    final tab = ref.watch(_tabProvider);
    final todoist =
        ref.watch(integrationsStatusProvider).valueOrNull?.todoist;

    final main = quests.where((q) => !q.isSideQuest).toList();
    final side = quests.where((q) => q.isSideQuest).toList();

    final visible = switch (tab) {
      2 => main.where((q) => q.completed).toList(),
      _ => main.where((q) => !q.completed).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'New Quest',
            onPressed: () => _openNewQuestDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.sync, size: 18),
            tooltip: 'Sync Quests',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );

              // Replay anything queued offline, then refetch server state.
              await ref.read(syncEngineProvider).flushQueue();
              final ok =
                  await ref.read(questsRepositoryProvider).fetchQuests() != null;
              ref.invalidate(remoteQuestsProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Sync complete!'
                        : 'Backend offline — using local data'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () =>
                          ref.read(_tabProvider.notifier).state = i,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tab == i
                              ? NotionColors.surfaceHover
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tab == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: tab == i
                                ? NotionColors.textPrimary
                                : NotionColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Nothing here yet',
                      style: TextStyle(
                          color: NotionColors.textFaint, fontSize: 13)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600 ? 1.7 : 2.2,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final quest = visible[index];
                  return QuestCard(
                    quest: quest,
                    onComplete: () => completeQuest(context, ref, quest),
                    onUndo: () => undoQuest(context, ref, quest),
                    onAction: quest.remoteId == null
                        ? null
                        : (action) =>
                            _handleQuestAction(context, ref, quest, action),
                  );
                },
              ),
            const SizedBox(height: 24),
            NotionSectionTitle(
              icon: Icons.extension_outlined,
              title: 'Side Quests',
              trailing: (todoist?.connected ?? false)
                  ? TextButton.icon(
                      onPressed: () => syncTodoistFlow(context, ref),
                      style: TextButton.styleFrom(
                          foregroundColor: NotionColors.textMuted),
                      icon: const Icon(Icons.sync, size: 14),
                      label: const Text('Sync Todoist',
                          style: TextStyle(fontSize: 12)),
                    )
                  : null,
            ),
            if (side.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600 ? 1.7 : 2.2,
                ),
                itemCount: side.length,
                itemBuilder: (context, index) {
                  final quest = side[index];
                  return QuestCard(
                    quest: quest,
                    onComplete: () => completeQuest(context, ref, quest),
                    onUndo: () => undoQuest(context, ref, quest),
                    onAction: quest.remoteId == null
                        ? null
                        : (action) =>
                            _handleQuestAction(context, ref, quest, action),
                  );
                },
              ),
              const SizedBox(height: 12),
            ] else if (todoist?.connected ?? false)
              const NotionCard(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No open side quests — add tasks to your Todoist project '
                    'and hit Sync.',
                    style: TextStyle(
                        fontSize: 12, color: NotionColors.textFaint),
                  ),
                ),
              )
            else
              IntegrationCard(
                icon: Icons.check_circle_outline,
                name: 'Todoist',
                description:
                    'Pull your Todoist tasks in as side quests — complete them to earn bonus XP.',
                onConnect: () => connectTodoistFlow(context, ref),
                preview: const [
                  IntegrationPreviewRow(
                    leading: 'Today',
                    title: 'Reply to landlord email',
                    trailingText: '+5 XP',
                    trailingColor: NotionColors.green,
                    trailingBg: NotionColors.greenBg,
                  ),
                  IntegrationPreviewRow(
                    leading: 'Today',
                    title: 'Buy groceries',
                    trailingText: '+5 XP',
                    trailingColor: NotionColors.green,
                    trailingBg: NotionColors.greenBg,
                  ),
                  IntegrationPreviewRow(
                    leading: 'Tomorrow',
                    title: 'Renew gym membership',
                    trailingText: '+10 XP',
                    trailingColor: NotionColors.green,
                    trailingBg: NotionColors.greenBg,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Server-backed card actions from the ⋯ menu.
  Future<void> _handleQuestAction(
    BuildContext context,
    WidgetRef ref,
    QuestEntry quest,
    String action,
  ) async {
    final repo = ref.read(questsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final id = quest.remoteId!;

    switch (action) {
      case 'steps':
        messenger.showSnackBar(
          const SnackBar(content: Text('Generating action steps…')),
        );
        final updated = await repo.generateSteps(id);
        ref.invalidate(remoteQuestsProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(updated == null
              ? 'Could not generate steps (offline?)'
              : '${updated.steps.length} action steps ready'),
        ));

      case 'difficulty':
        final choice = await showDialog<int>(
          context: context,
          builder: (context) => SimpleDialog(
            backgroundColor: NotionColors.surface,
            title: const Text('Difficulty', style: TextStyle(fontSize: 14)),
            children: [
              for (var d = 1; d <= 5; d++)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(d),
                  child: Text(
                    '$d  (+${d * 10} XP)${quest.xp == d * 10 ? '   • current' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        );
        if (choice == null) return;
        final ok = await repo.setDifficulty(id, choice);
        ref.invalidate(remoteQuestsProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(ok
              ? 'Difficulty set to $choice'
              : 'Could not update difficulty (offline?)'),
        ));

      case 'archive':
        final ok = await repo.archiveQuest(id);
        ref.invalidate(remoteQuestsProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(ok
              ? '"${quest.title}" archived'
              : 'Could not archive (offline?)'),
        ));

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: NotionColors.surface,
            title: const Text('Delete quest?', style: TextStyle(fontSize: 15)),
            content: Text(
              '"${quest.title}" and its steps will be permanently removed.',
              style: const TextStyle(
                  fontSize: 13, color: NotionColors.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 13, color: NotionColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete',
                    style:
                        TextStyle(fontSize: 13, color: NotionColors.red)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        final ok = await repo.deleteQuest(id);
        ref.invalidate(remoteQuestsProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(ok
              ? '"${quest.title}" deleted'
              : 'Could not delete (offline?)'),
        ));
    }
  }

  Future<void> _openNewQuestDialog(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_QuestDraft>(
      context: context,
      builder: (_) => const _NewQuestDialog(),
    );
    if (draft == null || !context.mounted) return;

    DateTime? dueDate;
    if (draft.time != null) {
      final now = DateTime.now();
      dueDate = DateTime(
          now.year, now.month, now.day, draft.time!.hour, draft.time!.minute);
    }

    final created = await ref.read(questsRepositoryProvider).createQuest(
          title: draft.title,
          category: draft.area.name,
          difficulty: draft.difficulty,
          dueDate: dueDate,
          recurrence: draft.recurrence,
        );
    if (!context.mounted) return;

    if (created != null) {
      ref.invalidate(remoteQuestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(draft.recurrence == null
                ? '"${draft.title}" added'
                : '"${draft.title}" added — repeats ${draft.recurrence}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backend offline — quest not saved.')),
      );
    }
  }
}

typedef _QuestDraft = ({
  String title,
  Area area,
  int difficulty,
  TimeOfDay? time,
  String? recurrence,
});

class _NewQuestDialog extends StatefulWidget {
  const _NewQuestDialog();

  @override
  State<_NewQuestDialog> createState() => _NewQuestDialogState();
}

class _NewQuestDialogState extends State<_NewQuestDialog> {
  final _titleController = TextEditingController();
  Area _area = Area.intel;
  int _difficulty = 1;
  TimeOfDay? _time;
  String? _recurrence;

  static const _difficulties = {
    1: 'Easy (+10 XP)',
    2: 'Medium (+20 XP)',
    3: 'Hard (+30 XP)',
  };
  static const _recurrences = {
    null: 'One-time',
    'daily': 'Daily',
    'weekly': 'Weekly',
  };

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop<_QuestDraft>((
      title: title,
      area: _area,
      difficulty: _difficulty,
      time: _time,
      recurrence: _recurrence,
    ));
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
      title: const Text('New quest', style: TextStyle(fontSize: 16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _decoration('Title'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Area>(
                    initialValue: _area,
                    style: const TextStyle(
                        fontSize: 12, color: NotionColors.textPrimary),
                    dropdownColor: NotionColors.surfaceHover,
                    decoration: _decoration('Area'),
                    items: [
                      for (final area in Area.values)
                        DropdownMenuItem(value: area, child: Text(area.label)),
                    ],
                    onChanged: (v) => setState(() => _area = v ?? _area),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _difficulty,
                    style: const TextStyle(
                        fontSize: 12, color: NotionColors.textPrimary),
                    dropdownColor: NotionColors.surfaceHover,
                    decoration: _decoration('Difficulty'),
                    items: [
                      for (final entry in _difficulties.entries)
                        DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (v) =>
                        setState(() => _difficulty = v ?? _difficulty),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: context,
                          initialTime: _time ?? TimeOfDay.now());
                      if (picked != null) setState(() => _time = picked);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NotionColors.textPrimary,
                      side: const BorderSide(color: NotionColors.border),
                    ),
                    icon: const Icon(Icons.schedule_outlined, size: 14),
                    label: Text(
                      _time == null ? 'Anytime' : _time!.format(context),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _recurrence,
                    style: const TextStyle(
                        fontSize: 12, color: NotionColors.textPrimary),
                    dropdownColor: NotionColors.surfaceHover,
                    decoration: _decoration('Repeats'),
                    items: [
                      for (final entry in _recurrences.entries)
                        DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v),
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
          child: const Text('Add', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

class QuestCard extends StatelessWidget {
  final QuestEntry quest;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  /// Server-backed actions ('steps' | 'difficulty' | 'archive' | 'delete');
  /// the ⋯ menu only shows when this is set (i.e. the quest has a remote id).
  final void Function(String action)? onAction;

  const QuestCard({
    super.key,
    required this.quest,
    required this.onComplete,
    required this.onUndo,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      color: quest.completed
          ? NotionColors.surface
          : NotionColors.purpleBg.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: quest.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: quest.completed
                            ? NotionColors.textFaint
                            : NotionColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onAction != null)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        icon: const Icon(Icons.more_horiz,
                            color: NotionColors.textMuted),
                        color: NotionColors.surfaceHover,
                        onSelected: onAction,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'steps',
                            height: 36,
                            child: Text('AI action steps',
                                style: TextStyle(fontSize: 12)),
                          ),
                          PopupMenuItem(
                            value: 'difficulty',
                            height: 36,
                            child: Text('Set difficulty',
                                style: TextStyle(fontSize: 12)),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            height: 36,
                            child: Text('Archive',
                                style: TextStyle(fontSize: 12)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            height: 36,
                            child: Text('Delete',
                                style: TextStyle(
                                    fontSize: 12, color: NotionColors.red)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                quest.time,
                style: const TextStyle(
                    fontSize: 11, color: NotionColors.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  NotionTag(
                    text: quest.area.label,
                    color: NotionColors.purple,
                    bgColor: NotionColors.purpleBg,
                  ),
                  const SizedBox(width: 6),
                  NotionTag(
                    text: '+${quest.xp} XP',
                    color: NotionColors.green,
                    bgColor: NotionColors.greenBg,
                  ),
                  if (quest.recurrence != null) ...[
                    const SizedBox(width: 6),
                    NotionTag(
                      text: quest.recurrence == 'daily' ? 'Daily' : 'Weekly',
                      color: NotionColors.blue,
                      bgColor: NotionColors.blueBg,
                    ),
                  ],
                  if (quest.steps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: quest.steps
                          .asMap()
                          .entries
                          .map((e) => '${e.key + 1}. ${e.value}')
                          .join('\n'),
                      child: NotionTag(
                        text: '${quest.steps.length} steps',
                        color: NotionColors.orange,
                        bgColor: NotionColors.orangeBg,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (!quest.completed)
            SizedBox(
              height: 26,
              child: OutlinedButton(
                onPressed: onComplete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotionColors.textMuted,
                  side: const BorderSide(color: NotionColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Complete', style: TextStyle(fontSize: 11)),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Lottie.asset(
                    'assets/lottie/success_check.json',
                    repeat: false,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Done',
                    style:
                        TextStyle(fontSize: 11, color: NotionColors.green)),
                const Spacer(),
                SizedBox(
                  height: 26,
                  child: TextButton.icon(
                    onPressed: onUndo,
                    style: TextButton.styleFrom(
                      foregroundColor: NotionColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.undo, size: 12),
                    label:
                        const Text('Undo', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
