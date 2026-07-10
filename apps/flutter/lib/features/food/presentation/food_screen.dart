import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/food/data/food_repository.dart';
import 'package:life_os/shared/widgets/block_bar.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

const _calorieTarget = 2200;

typedef _MealDraft = ({
  String mealType,
  int calories,
  int? protein,
  int? carbs,
  int? fats,
});

String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodData = ref.watch(todayFoodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      body: foodData.when(
        data: (logs) => _buildContent(context, ref, logs),
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repository already absorbs network errors; anything else
        // still degrades to the empty local-first layout.
        error: (err, stack) => _buildContent(context, ref, const []),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<FoodLogDto> logs) {
    var calories = 0;
    var protein = 0;
    var carbs = 0;
    var fats = 0;
    for (final log in logs) {
      calories += log.calories;
      protein += log.protein;
      carbs += log.carbs;
      fats += log.fats;
    }

    final macros = <(IconData, String, int, int, Color, Color)>[
      (Icons.set_meal_outlined, 'Protein', protein, 120, NotionColors.blue,
          NotionColors.blueBg),
      (Icons.bakery_dining_outlined, 'Carbs', carbs, 220, NotionColors.orange,
          NotionColors.orangeBg),
      (Icons.egg_alt_outlined, 'Fats', fats, 70, NotionColors.yellow,
          NotionColors.yellowBg),
    ];

    return PageBody(
      children: [
        MetricRow(
          children: [
            MetricCallout(
              icon: Icons.local_fire_department_outlined,
              label: 'Calories',
              value: '${_thousands(calories)} / ${_thousands(_calorieTarget)}',
              color: NotionColors.green,
              bgColor: NotionColors.greenBg,
              progress: calories / _calorieTarget,
            ),
            const MetricCallout(
              icon: Icons.water_drop_outlined,
              label: 'Water',
              value: '5 / 8 cups',
              color: NotionColors.blue,
              bgColor: NotionColors.blueBg,
              progress: 5 / 8,
            ),
            MetricCallout(
              icon: Icons.restaurant_outlined,
              label: 'Meals Logged',
              value: '${logs.length}',
              color: NotionColors.purple,
              bgColor: NotionColors.purpleBg,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(
            icon: Icons.pie_chart_outline, title: 'Daily Macros'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final (icon, label, current, target, color, bg) in macros)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: Text(label,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: BlockBar(
                          value:
                              ((current / target) * 10).round().clamp(0, 10),
                          max: 10,
                          color: color,
                          showLabel: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      NotionTag(
                        text: '$current / ${target}g',
                        color: color,
                        bgColor: bg,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          icon: Icons.lunch_dining_outlined,
          title: 'Meals Today',
          trailing: TextButton.icon(
            onPressed: () => _openLogMealSheet(context, ref),
            style: TextButton.styleFrom(
                foregroundColor: NotionColors.textMuted),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Log meal', style: TextStyle(fontSize: 12)),
          ),
        ),
        NotionCard(
          padding: EdgeInsets.zero,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No meals logged today — log one to earn VIT.',
                      style: TextStyle(
                          fontSize: 12, color: NotionColors.textFaint),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < logs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant_outlined,
                                size: 13, color: NotionColors.textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                logs[i].mealType,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            NotionTag(
                              text: '${logs[i].calories} kcal',
                              color: NotionColors.green,
                              bgColor: NotionColors.greenBg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _openLogMealSheet(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<_MealDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NotionColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: NotionColors.border),
      ),
      builder: (_) => const _LogMealSheet(),
    );
    if (draft == null) return;

    final ok = await ref.read(foodRepositoryProvider).logMeal(
          mealType: draft.mealType,
          calories: draft.calories,
          protein: draft.protein,
          carbs: draft.carbs,
          fats: draft.fats,
        );
    if (ok) ref.invalidate(todayFoodProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '${draft.mealType} logged (${draft.calories} kcal).'
              : 'Could not log meal — backend offline.'),
        ),
      );
    }
  }
}

class _LogMealSheet extends StatefulWidget {
  const _LogMealSheet();

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  final _formKey = GlobalKey<FormState>();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  String _mealType = 'Breakfast';

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop<_MealDraft>((
      mealType: _mealType,
      calories: int.parse(_caloriesController.text.trim()),
      protein: int.tryParse(_proteinController.text.trim()),
      carbs: int.tryParse(_carbsController.text.trim()),
      fats: int.tryParse(_fatsController.text.trim()),
    ));
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: NotionColors.textMuted,
          ),
        ),
      );

  Widget _numberField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(hintText: hint),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.restaurant_outlined,
                          size: 15, color: NotionColors.textMuted),
                      SizedBox(width: 8),
                      Text(
                        'Log meal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NotionColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Meal type'),
                  DropdownButtonFormField<String>(
                    initialValue: _mealType,
                    dropdownColor: NotionColors.surfaceHover,
                    style: const TextStyle(
                        fontSize: 13, color: NotionColors.textPrimary),
                    icon: const Icon(Icons.expand_more,
                        size: 16, color: NotionColors.textMuted),
                    items: [
                      for (final type in _mealTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) =>
                        setState(() => _mealType = value ?? _mealType),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Calories'),
                  _numberField(
                    controller: _caloriesController,
                    hint: 'e.g. 550',
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n <= 0) {
                        return 'Enter calories';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Protein (g)'),
                            _numberField(
                                controller: _proteinController, hint: '—'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Carbs (g)'),
                            _numberField(
                                controller: _carbsController, hint: '—'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Fats (g)'),
                            _numberField(
                                controller: _fatsController, hint: '—'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Log meal',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
