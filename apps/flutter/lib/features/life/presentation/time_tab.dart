import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/data/time_repository.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// Display metadata per time category, in Notion's muted palette.
const timeCategories = <String, (String label, IconData icon, Color, Color)>{
  'quest': ('Quests', Icons.list_alt_outlined, NotionColors.purple, NotionColors.purpleBg),
  'work': ('Work', Icons.work_outline, NotionColors.blue, NotionColors.blueBg),
  'health': ('Health', Icons.favorite_outline, NotionColors.green, NotionColors.greenBg),
  'social': ('Social', Icons.people_outline, NotionColors.yellow, NotionColors.yellowBg),
  'rest': ('Rest', Icons.bedtime_outlined, NotionColors.orange, NotionColors.orangeBg),
  'waste': ('Waste', Icons.hourglass_empty, NotionColors.red, NotionColors.redBg),
};

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class TimeTab extends ConsumerWidget {
  const TimeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(timeSummaryProvider);
    final recent = ref.watch(recentTimeEntriesProvider);

    return PageBody(
      children: [
        summary.when(
          data: (s) => _SummaryHeader(summary: s),
          loading: () => const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => const _SummaryHeader(summary: null),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.add_circle_outline, title: 'Log Time'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: _QuickLog(onLogged: () {
            ref.invalidate(timeSummaryProvider);
            ref.invalidate(recentTimeEntriesProvider);
          }),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.donut_small_outlined, title: 'Last 7 Days'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: summary.when(
            data: (s) => _CategoryBreakdown(summary: s),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => const _CategoryBreakdown(summary: null),
          ),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.history_outlined, title: 'Recent Entries'),
        NotionCard(
          padding: EdgeInsets.zero,
          child: recent.when(
            data: (entries) => entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No time logged yet — tap a category above to start.',
                        style: TextStyle(
                            fontSize: 12, color: NotionColors.textFaint),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _EntryRow(entry: entries[i]),
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
}

class _SummaryHeader extends StatelessWidget {
  final TimeSummaryDto? summary;

  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary?.totalMinutes ?? 0;
    final top = (summary?.roiRanking.isNotEmpty ?? false)
        ? summary!.roiRanking.first
        : null;
    final topMeta = top == null ? null : timeCategories[top.category];

    return MetricRow(
      children: [
        MetricCallout(
          icon: Icons.timer_outlined,
          label: 'Tracked (7d)',
          value: total > 0 ? formatMinutes(total) : '—',
          color: NotionColors.blue,
          bgColor: NotionColors.blueBg,
        ),
        MetricCallout(
          icon: Icons.trending_up,
          label: 'Top ROI',
          value: topMeta?.$1 ?? '—',
          color: NotionColors.green,
          bgColor: NotionColors.greenBg,
        ),
        MetricCallout(
          icon: Icons.speed_outlined,
          label: 'ROI Score',
          value: top != null ? '${top.avgRoi}' : '—',
          color: NotionColors.purple,
          bgColor: NotionColors.purpleBg,
        ),
      ],
    );
  }
}

class _QuickLog extends ConsumerStatefulWidget {
  final VoidCallback onLogged;

  const _QuickLog({required this.onLogged});

  @override
  ConsumerState<_QuickLog> createState() => _QuickLogState();
}

class _QuickLogState extends ConsumerState<_QuickLog> {
  String _category = 'work';
  int _minutes = 60;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ok = await ref.read(timeRepositoryProvider).logEntry(
          category: _category,
          durationMinutes: _minutes,
          notes: _notesController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _notesController.clear();
      widget.onLogged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Logged ${formatMinutes(_minutes)} of ${timeCategories[_category]?.$1 ?? _category}'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not reach the backend — entry not saved.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in timeCategories.entries)
              ChoiceChip(
                avatar: Icon(entry.value.$2,
                    size: 14,
                    color: _category == entry.key
                        ? entry.value.$3
                        : NotionColors.textFaint),
                label: Text(entry.value.$1,
                    style: const TextStyle(fontSize: 12)),
                selected: _category == entry.key,
                selectedColor: entry.value.$4,
                onSelected: (_) => setState(() => _category = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final m in const [15, 30, 60, 90, 120])
              ChoiceChip(
                label: Text(formatMinutes(m),
                    style: const TextStyle(fontSize: 12)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'What were you doing? (optional)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Log'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final TimeSummaryDto? summary;

  const _CategoryBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    final categories = summary?.byCategory ?? const <TimeCategorySummary>[];
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Nothing tracked this week yet.',
          style: TextStyle(fontSize: 12, color: NotionColors.textFaint),
        ),
      );
    }
    final maxMinutes = categories
        .map((c) => c.minutes)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 31);

    return Column(
      children: [
        for (final cat in categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    timeCategories[cat.category]?.$1 ?? cat.category,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: cat.minutes / maxMinutes,
                      minHeight: 8,
                      backgroundColor: NotionColors.surfaceHover,
                      color: timeCategories[cat.category]?.$3 ??
                          NotionColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: Text(
                    formatMinutes(cat.minutes),
                    textAlign: TextAlign.right,
                    style: NotionType.mono(
                        size: 11, color: NotionColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final TimeEntryDto entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final meta = timeCategories[entry.category];
    final time = TimeOfDay.fromDateTime(entry.startTime.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          NotionTag(
            text: meta?.$1 ?? entry.category,
            color: meta?.$3 ?? NotionColors.blue,
            bgColor: meta?.$4 ?? NotionColors.blueBg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.notes?.isNotEmpty == true
                  ? entry.notes!
                  : formatMinutes(entry.durationMinutes),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${time.format(context)} · ${formatMinutes(entry.durationMinutes)}',
            style:
                NotionType.mono(size: 11, color: NotionColors.textFaint),
          ),
        ],
      ),
    );
  }
}
