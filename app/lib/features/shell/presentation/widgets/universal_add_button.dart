import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../accounts/presentation/widgets/record_transaction_dialog.dart';
import '../../../contacts/presentation/widgets/create_contact_dialog.dart';
import '../../../documents/presentation/widgets/attachments_card.dart';
import '../../../goat_farm/presentation/widgets/animal_dialogs.dart';
import '../../../goat_farm/presentation/widgets/breeding_dialogs.dart';
import '../../../land/presentation/widgets/add_parcel_dialog.dart';

/// Universal "Add New" (CLAUDE.md Phase 08): one entry point that opens the
/// right form for any record type, from anywhere in the app.
class UniversalAddButton extends ConsumerWidget {
  const UniversalAddButton({super.key, this.compact = false});
  final bool compact;

  static const _items = <(String, IconData, String)>[
    ('income', Icons.south_west_rounded, 'Income'),
    ('expense', Icons.north_east_rounded, 'Expense'),
    ('animal', Icons.pets_rounded, 'Animal'),
    ('mating', Icons.favorite_border_rounded, 'Mating record'),
    ('land', Icons.landscape_rounded, 'Land record'),
    ('contact', Icons.person_add_alt_rounded, 'Customer / supplier'),
    ('document', Icons.upload_file_rounded, 'Document'),
  ];

  void _open(BuildContext context, WidgetRef ref, String item) {
    Widget? dialog = switch (item) {
      'income' => const RecordTransactionDialog(kind: TransactionKind.income),
      'expense' => const RecordTransactionDialog(kind: TransactionKind.expense),
      'animal' => const AddAnimalDialog(),
      'mating' => const CreateBreedingDialog(),
      'land' => const AddParcelDialog(),
      'contact' => const CreateContactDialog(),
      _ => null,
    };
    if (dialog != null) {
      showDialog<void>(context: context, builder: (_) => dialog);
    } else if (item == 'document') {
      pickAndUploadDocument(context, ref, module: 'GENERAL');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Add new',
      onSelected: (item) => _open(context, ref, item),
      itemBuilder: (_) => [
        for (final (value, icon, label) in _items)
          PopupMenuItem(value: value, child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(label))),
      ],
      child: compact
          ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add_circle_rounded))
          : Chip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Add new')),
    );
  }
}
