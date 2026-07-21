import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/data/checkin_repository.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

class CheckinTab extends ConsumerWidget {
  const CheckinTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(checkinHistoryProvider);
    final today = history.valueOrNull?.checkins
        .where((c) =>
            c.date.year == DateTime.now().year &&
            c.date.month == DateTime.now().month &&
            c.date.day == DateTime.now().day)
        .firstOrNull;

    return PageBody(
      children: [
        history.when(
          data: (h) => MetricRow(
            children: [
              MetricCallout(
                icon: Icons.sentiment_satisfied_outlined,
                label: 'Mood (14d)',
                value: h?.moodAvg != null ? '${h!.moodAvg}' : '—',
                color: NotionColors.yellow,
                bgColor: NotionColors.yellowBg,
              ),
              MetricCallout(
                icon: Icons.bolt_outlined,
                label: 'Energy (14d)',
                value: h?.energyAvg != null ? '${h!.energyAvg}' : '—',
                color: NotionColors.green,
                bgColor: NotionColors.greenBg,
              ),
              MetricCallout(
                icon: Icons.bedtime_outlined,
                label: 'Sleep (14d)',
                value: h?.sleepMinutesAvg != null
                    ? '${(h!.sleepMinutesAvg! / 60).toStringAsFixed(1)}h'
                    : '—',
                color: NotionColors.purple,
                bgColor: NotionColors.purpleBg,
              ),
            ],
          ),
          loading: () => const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.wb_sunny_outlined, title: 'Morning Check-in'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: _CheckinForm(
            isMorning: true,
            done: today?.morningMood != null,
            onSaved: () => ref.invalidate(checkinHistoryProvider),
          ),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.nights_stay_outlined, title: 'Evening Check-in'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: _CheckinForm(
            isMorning: false,
            done: today?.eveningMood != null,
            onSaved: () => ref.invalidate(checkinHistoryProvider),
          ),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.show_chart, title: 'Last 14 Days'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: history.when(
            data: (h) => _HistoryList(history: h),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => const _HistoryList(history: null),
          ),
        ),
      ],
    );
  }
}

class _CheckinForm extends ConsumerStatefulWidget {
  final bool isMorning;
  final bool done;
  final VoidCallback onSaved;

  const _CheckinForm({
    required this.isMorning,
    required this.done,
    required this.onSaved,
  });

  @override
  ConsumerState<_CheckinForm> createState() => _CheckinFormState();
}

class _CheckinFormState extends ConsumerState<_CheckinForm> {
  int _mood = 7;
  int _energy = 7;
  int _stress = 3;
  double _sleepHours = 7.5;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final repo = ref.read(checkinRepositoryProvider);
    final ok = widget.isMorning
        ? await repo.submit(
            morningMood: _mood,
            morningEnergy: _energy,
            morningStress: _stress,
            sleepMinutes: (_sleepHours * 60).round(),
          )
        : await repo.submit(
            eveningMood: _mood,
            eveningEnergy: _energy,
            eveningStress: _stress,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${widget.isMorning ? 'Morning' : 'Evening'} check-in saved.'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not reach the backend — check-in not saved.'),
      ));
    }
  }

  Widget _scale(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: NotionType.mono(size: 12, weight: FontWeight.w700)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.done)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: const [
                Icon(Icons.check_circle, size: 14, color: NotionColors.green),
                SizedBox(width: 6),
                Text('Already logged today — saving again overwrites it.',
                    style: TextStyle(
                        fontSize: 11, color: NotionColors.textFaint)),
              ],
            ),
          ),
        _scale('Mood', _mood, (v) => setState(() => _mood = v)),
        _scale('Energy', _energy, (v) => setState(() => _energy = v)),
        _scale('Stress', _stress, (v) => setState(() => _stress = v)),
        if (widget.isMorning)
          Row(
            children: [
              const SizedBox(
                  width: 60,
                  child: Text('Sleep', style: TextStyle(fontSize: 12))),
              Expanded(
                child: Slider(
                  value: _sleepHours,
                  min: 0,
                  max: 12,
                  divisions: 24,
                  label: '${_sleepHours}h',
                  onChanged: (v) => setState(() => _sleepHours = v),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${_sleepHours}h',
                    textAlign: TextAlign.right,
                    style:
                        NotionType.mono(size: 11, weight: FontWeight.w700)),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.check, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final CheckinHistoryDto? history;

  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    final checkins = history?.checkins ?? const <CheckinDto>[];
    if (checkins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'No check-ins yet — your mood and energy trends will appear here.',
          style: TextStyle(fontSize: 12, color: NotionColors.textFaint),
        ),
      );
    }

    return Column(
      children: [
        for (final c in checkins)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '${c.date.day}/${c.date.month}',
                    style: NotionType.mono(
                        size: 11, color: NotionColors.textMuted),
                  ),
                ),
                _pill('M', c.morningMood, NotionColors.yellow,
                    NotionColors.yellowBg),
                const SizedBox(width: 6),
                _pill('E', c.eveningMood, NotionColors.purple,
                    NotionColors.purpleBg),
                const Spacer(),
                if (c.sleepMinutes != null)
                  Text('${(c.sleepMinutes! / 60).toStringAsFixed(1)}h sleep',
                      style: NotionType.mono(
                          size: 10, color: NotionColors.textFaint)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pill(String label, int? value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: value != null ? bg : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label ${value ?? '—'}',
        style: NotionType.mono(
          size: 10,
          color: value != null ? color : NotionColors.textFaint,
        ),
      ),
    );
  }
}
