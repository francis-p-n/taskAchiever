import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/data/habits_repository.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

const _habitCategories = <String, (String, IconData, Color, Color)>{
  'fitness': ('Fitness', Icons.fitness_center, NotionColors.green, NotionColors.greenBg),
  'learning': ('Learning', Icons.menu_book_outlined, NotionColors.blue, NotionColors.blueBg),
  'spirituality': ('Spirit', Icons.self_improvement, NotionColors.purple, NotionColors.purpleBg),
  'social': ('Social', Icons.people_outline, NotionColors.yellow, NotionColors.yellowBg),
  'other': ('Other', Icons.category_outlined, NotionColors.orange, NotionColors.orangeBg),
};

class HabitsTab extends ConsumerWidget {
  const HabitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return PageBody(
      children: [
        habits.when(
          data: (list) {
            final done = list.where((h) => h.completedToday).length;
            final best = list.isEmpty
                ? 0
                : list
                    .map((h) => h.currentStreakDays)
                    .reduce((a, b) => a > b ? a : b);
            return MetricRow(
              children: [
                MetricCallout(
                  icon: Icons.check_circle_outline,
                  label: 'Done Today',
                  value: '$done / ${list.length}',
                  color: NotionColors.green,
                  bgColor: NotionColors.greenBg,
                ),
                MetricCallout(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Best Streak',
                  value: '$best d',
                  color: NotionColors.orange,
                  bgColor: NotionColors.orangeBg,
                ),
              ],
            );
          },
          loading: () => const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          icon: Icons.repeat,
          title: 'Habits',
          trailing: TextButton.icon(
            onPressed: () => _showAddHabit(context, ref),
            style: TextButton.styleFrom(foregroundColor: NotionColors.textMuted),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New', style: TextStyle(fontSize: 12)),
          ),
        ),
        NotionCard(
          padding: EdgeInsets.zero,
          child: habits.when(
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No habits yet — create one atomic habit to start a streak.',
                        style: TextStyle(
                            fontSize: 12, color: NotionColors.textFaint),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _HabitRow(habit: list[i]),
                      ],
                    ],
                  ),
            loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  void _showAddHabit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddHabitSheet(),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  final HabitDto habit;

  const _HabitRow({required this.habit});

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(habitsRepositoryProvider).completeHabit(habit.id);
    if (!context.mounted) return;
    if (result.ok) {
      ref.invalidate(habitsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${habit.name}: day ${result.streak} of the streak, +${result.xp} XP'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.alreadyDone
            ? 'Already checked in today.'
            : 'Could not reach the backend — try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = _habitCategories[habit.category] ?? _habitCategories['other']!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed:
                habit.completedToday ? null : () => _complete(context, ref),
            icon: Icon(
              habit.completedToday
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: habit.completedToday
                  ? NotionColors.green
                  : NotionColors.textFaint,
              size: 22,
            ),
            tooltip: habit.completedToday ? 'Done today' : 'Mark done',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    NotionTag(text: meta.$1, color: meta.$3, bgColor: meta.$4),
                    const SizedBox(width: 8),
                    Text(
                      habit.targetFrequency,
                      style: NotionType.mono(
                          size: 10, color: NotionColors.textFaint),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (habit.freezesRemaining > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: '${habit.freezesRemaining} streak freezes left',
                child: Icon(Icons.ac_unit,
                    size: 14, color: NotionColors.blue.withValues(alpha: 0.7)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 14, color: NotionColors.orange),
                  const SizedBox(width: 2),
                  Text('${habit.currentStreakDays}',
                      style: NotionType.mono(
                          size: 13,
                          weight: FontWeight.w700,
                          color: NotionColors.orange)),
                ],
              ),
              Text('best ${habit.longestStreakDays}',
                  style: NotionType.mono(
                      size: 10, color: NotionColors.textFaint)),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 16, color: NotionColors.textFaint),
            onSelected: (value) async {
              if (value != 'archive') return;
              final ok = await ref
                  .read(habitsRepositoryProvider)
                  .archiveHabit(habit.id);
              if (ok) ref.invalidate(habitsProvider);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'archive',
                child: Text('Archive', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddHabitSheet extends ConsumerStatefulWidget {
  const _AddHabitSheet();

  @override
  ConsumerState<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<_AddHabitSheet> {
  final _nameController = TextEditingController();
  String _category = 'fitness';
  int _difficulty = 3;
  String _frequency = 'daily';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final ok = await ref.read(habitsRepositoryProvider).createHabit(
          name: name,
          category: _category,
          difficulty: _difficulty,
          targetFrequency: _frequency,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(habitsProvider);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not reach the backend — habit not saved.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Habit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'e.g. Fasted run 4.8 km',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _habitCategories.entries)
                ChoiceChip(
                  label: Text(entry.value.$1,
                      style: const TextStyle(fontSize: 12)),
                  selected: _category == entry.key,
                  selectedColor: entry.value.$4,
                  onSelected: (_) => setState(() => _category = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Difficulty', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _difficulty.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_difficulty',
                  onChanged: (v) =>
                      setState(() => _difficulty = v.round()),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final f in const ['daily', '3x-weekly', 'weekly'])
                ChoiceChip(
                  label: Text(f, style: const TextStyle(fontSize: 12)),
                  selected: _frequency == f,
                  onSelected: (_) => setState(() => _frequency = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Create Habit'),
            ),
          ),
        ],
      ),
    );
  }
}
