import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/data/relationships_repository.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

const _tiers = <String, (String, Color, Color)>{
  'close': ('Close', NotionColors.red, NotionColors.redBg),
  'friend': ('Friend', NotionColors.blue, NotionColors.blueBg),
  'acquaintance': ('Acquaintance', NotionColors.yellow, NotionColors.yellowBg),
  'professional': ('Professional', NotionColors.purple, NotionColors.purpleBg),
};

const _interactionTypes = <String, IconData>{
  'text': Icons.chat_bubble_outline,
  'call': Icons.call_outlined,
  'meet': Icons.coffee_outlined,
  'gift': Icons.card_giftcard,
  'shared-memory': Icons.photo_outlined,
};

String _sinceLabel(DateTime? last) {
  if (last == null) return 'never';
  final days = DateTime.now().difference(last).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  return '${days}d ago';
}

class PeopleTab extends ConsumerWidget {
  const PeopleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);

    return PageBody(
      children: [
        contacts.when(
          data: (list) {
            final atRisk = list.where((c) => c.atRisk).length;
            return MetricRow(
              children: [
                MetricCallout(
                  icon: Icons.people_outline,
                  label: 'People',
                  value: '${list.length}',
                  color: NotionColors.blue,
                  bgColor: NotionColors.blueBg,
                ),
                MetricCallout(
                  icon: Icons.notification_important_outlined,
                  label: 'At Risk',
                  value: '$atRisk',
                  color: atRisk > 0 ? NotionColors.red : NotionColors.green,
                  bgColor: atRisk > 0 ? NotionColors.redBg : NotionColors.greenBg,
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
          icon: Icons.favorite_outline,
          title: 'Relationships',
          trailing: TextButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _AddContactSheet(),
            ),
            style: TextButton.styleFrom(foregroundColor: NotionColors.textMuted),
            icon: const Icon(Icons.person_add_alt, size: 14),
            label: const Text('Add', style: TextStyle(fontSize: 12)),
          ),
        ),
        NotionCard(
          padding: EdgeInsets.zero,
          child: contacts.when(
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No contacts yet — add the people you want to stay intentional about.',
                        style: TextStyle(
                            fontSize: 12, color: NotionColors.textFaint),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _ContactRow(contact: list[i]),
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

class _ContactRow extends ConsumerWidget {
  final ContactDto contact;

  const _ContactRow({required this.contact});

  Future<void> _logInteraction(
      BuildContext context, WidgetRef ref, String type) async {
    final ok = await ref.read(relationshipsRepositoryProvider).logInteraction(
          contactId: contact.id,
          interactionType: type,
        );
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(contactsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logged $type with ${contact.name}'),
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not reach the backend — not logged.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = _tiers[contact.relationshipType] ?? _tiers['friend']!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (contact.atRisk)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.warning_amber_rounded,
                  size: 16, color: NotionColors.red),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    NotionTag(
                        text: tier.$1, color: tier.$2, bgColor: tier.$3),
                    const SizedBox(width: 8),
                    Text(
                      _sinceLabel(contact.lastContactedAt),
                      style: NotionType.mono(
                          size: 10, color: NotionColors.textFaint),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text('${contact.engagementScore}',
              style: NotionType.mono(
                  size: 12,
                  weight: FontWeight.w700,
                  color: contact.engagementScore >= 50
                      ? NotionColors.green
                      : contact.engagementScore > 0
                          ? NotionColors.yellow
                          : NotionColors.red)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_comment_outlined,
                size: 16, color: NotionColors.textFaint),
            tooltip: 'Log interaction',
            onSelected: (type) {
              if (type == '_delete') {
                ref
                    .read(relationshipsRepositoryProvider)
                    .deleteContact(contact.id)
                    .then((ok) {
                  if (ok) ref.invalidate(contactsProvider);
                });
              } else {
                _logInteraction(context, ref, type);
              }
            },
            itemBuilder: (_) => [
              for (final entry in _interactionTypes.entries)
                PopupMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value,
                          size: 14, color: NotionColors.textMuted),
                      const SizedBox(width: 8),
                      Text(entry.key, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '_delete',
                child: Text('Remove contact',
                    style: TextStyle(fontSize: 12, color: NotionColors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddContactSheet extends ConsumerStatefulWidget {
  const _AddContactSheet();

  @override
  ConsumerState<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<_AddContactSheet> {
  final _nameController = TextEditingController();
  String _tier = 'friend';
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
    final ok = await ref.read(relationshipsRepositoryProvider).addContact(
          name: name,
          relationshipType: _tier,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(contactsProvider);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not reach the backend — contact not saved.'),
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
          const Text('Add Person',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Name',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _tiers.entries)
                ChoiceChip(
                  label: Text(entry.value.$1,
                      style: const TextStyle(fontSize: 12)),
                  selected: _tier == entry.key,
                  selectedColor: entry.value.$3,
                  onSelected: (_) => setState(() => _tier = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving…' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }
}
