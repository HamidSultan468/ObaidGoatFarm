import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accounting/accounting_controller.dart';
import 'widgets/create_contact_dialog.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Customers & Suppliers', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(
                onPressed: () => showDialog<void>(context: context, builder: (_) => const CreateContactDialog()),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Add contact'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Could not load contacts: $error')),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(child: Text('No customers or suppliers yet.'));
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?')),
                      title: Text(contact.name),
                      subtitle: Text([contact.type, if (contact.email != null) contact.email!, if (contact.phone != null) contact.phone!].join(' · ')),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
