import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/features/quests/application/quests_notifier.dart';

/// Completes [quest]: updates the quest list, awards XP, celebrates a
/// level-up, and offers an Undo action on the confirmation snackbar.
/// Shared by the Quests screen and the dashboard.
void completeQuest(BuildContext context, WidgetRef ref, QuestEntry quest) {
  if (!ref.read(questsProvider.notifier).complete(quest)) return;

  final result =
      ref.read(playerProvider.notifier).gainXp(quest.xp, area: quest.area);

  if (result.leveledUp) {
    showDialog(
      context: context,
      builder: (_) => LevelUpDialog(newLevel: result.newLevel),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${quest.title} complete  +${result.xpGained} XP  •  ${quest.area.label}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => undoQuest(context, ref, quest),
        ),
      ),
    );
  }
}

/// Reverts a completion: restores the quest and takes back the XP.
void undoQuest(BuildContext context, WidgetRef ref, QuestEntry quest) {
  if (!ref.read(questsProvider.notifier).uncomplete(quest)) return;

  ref.read(playerProvider.notifier).revertXp(quest.xp, area: quest.area);
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${quest.title} restored  −${quest.xp} XP')),
  );
}

class LevelUpDialog extends StatefulWidget {
  final int newLevel;

  const LevelUpDialog({super.key, required this.newLevel});

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack)
          .drive(Tween(begin: 0.92, end: 1.0)),
      child: FadeTransition(
        opacity: _entrance,
        child: Dialog(
          backgroundColor: NotionColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: NotionColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/confetti_burst.json',
                        repeat: false,
                        width: 110,
                        height: 110,
                      ),
                      const Icon(Icons.celebration_outlined,
                          size: 40, color: NotionColors.yellow),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level Up!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You reached Level ${widget.newLevel}',
                  style: const TextStyle(
                      fontSize: 13, color: NotionColors.textMuted),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NotionColors.textPrimary,
                    side: const BorderSide(color: NotionColors.border),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
